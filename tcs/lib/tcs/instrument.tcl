########################################################################

# This file is part of the RATTEL instrument control system.

# $Id: instrument.tcl 3613 2020-06-20 20:21:43Z Alan $

########################################################################

# Copyright © 2014, 2015, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
# DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
# PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

########################################################################

package require "client"
package require "safetyswitch"
package require "server"

package provide "instrument" 0.0

namespace eval "instrument" {

  variable svnid {$Id}

  ######################################################################

  variable detectors                [config::getvalue "instrument" "detectors"]
  variable activedetectors          [config::getvalue "instrument" "activedetectors"]
  variable pointingdetectors        [config::getvalue "instrument" "pointingdetectors"]
  variable outletgroups             [config::getvalue "instrument" "outletgroups"]
  
  ######################################################################
  
  proc isactivedetector {detector} {
    variable activedetectors
    if {[lsearch $activedetectors $detector] != -1} {
      return true
    } else {
      return false
    }
  }
  
  proc linklatest {detector} {
    set fitsfilename [client::getdata $detector "fitsfilename"]
    if {![string equal $fitsfilename ""]} {
      set latest "/images/test/latest${detector}.fits"
      file delete -force $latest
      file link -symbolic $latest $fitsfilename
    }
  }

  ######################################################################

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    variable activedetectors
    foreach detector $activedetectors {
      client::waituntilstarted $detector 
      client::resetifnecessary $detector
      client::request $detector "initialize"
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    variable outletgroups
    foreach outletgroup $outletgroups {
      client::resetifnecessary "power"
      client::request "power" "switchon $outletgroup"
      client::wait "power"
    }
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
      client::request $detector "setcooler open"
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
  }

  proc opentocoolactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening to cool."
    variable outletgroups
    foreach outletgroup $outletgroups {
      client::resetifnecessary "power"
      client::request "power" "switchon $outletgroup"
      client::wait "power"
    }
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
      client::request $detector "setcooler open"
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished opening to cool after %.1f seconds." [utcclock::diff now $start]]
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
      client::request $detector "stop"
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff now $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    variable activedetectors
    foreach detector $activedetectors {
      client::waituntilstarted $detector
      client::request $detector "reset"
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    server::setactivity [server::getstoppedactivity]
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff now $start]]
  }    

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
      client::request $detector "setcooler closed"
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    variable outletgroups
    foreach outletgroup $outletgroups {
      client::resetifnecessary "power"
      client::request "power" "switchoff $outletgroup"
      client::wait "power"
    }
    log::info [format "finished closing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc emergencycloseactivitycommand {} {
    set start [utcclock::seconds]
    log::info "emergency closing."
    closeactivitycommand
    log::info [format "finished emergency closing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc idleactivitycommand {} {
    set start [utcclock::seconds]
    log::info "idling."
    variable activedetectors
    foreach detector $activedetectors {
      if {[isactivedetector $detector]} {
        client::resetifnecessary $detector
        client::request $detector "movefilterwheel idle"
      }
    }
    foreach detector $activedetectors {
      if {[isactivedetector $detector]} {
        client::wait $detector
      }
    }
    log::info [format "finished idling after %.1f seconds." [utcclock::diff now $start]]
  }  

  proc ratirmovefilterwheelactivitycommand {position} {
    set start [utcclock::seconds]
    log::info "moving C0 filter wheel to $position."
    if {[isactivedetector C0]} {
      client::resetifnecessary "C0"
      client::request "C0" "movefilterwheel $position"
      client::wait "C0"
    }
    log::info [format "finished moving C0 filter wheel after %.1f seconds." [utcclock::diff now $start]]
  }

  proc ratirexposeactivitycommand {C0exposuretime C1exposuretime C2exposuretime C3exposuretime C2nreads C3nreads type fitsfileprefix} {
    set start [utcclock::seconds]
    log::info "exposing."
    variable detectors
    foreach detector $detectors {
      client::resetifnecessary $detector
    }
    if {$C2nreads == 0} {
      set C2exposuretime "none"
    }
    if {$C3nreads == 0} {
      set C3exposuretime "none"
    }
    if {[string equal $type "astrometry"]} {
      set C4exposuretime "none"
    } else {
      set C4exposuretime $C1exposuretime
    }
    set nreadslist {}
    set exposingdetectorlist {}
    set exposuretimelist {}
    foreach detector $detectors {
      if {![string equal [set ${detector}exposuretime] "none"]} {
        lappend exposingdetectorlist $detector
        lappend exposuretimelist [set ${detector}exposuretime]
        if {[string equal $detector "C0"] || [string equal $detector "C1"] || [string equal $detector "C4"]} {
          lappend nreadslist 1
        } else {
          lappend nreadslist [set ${detector}nreads]
        }
      }
    }
    log::info "exposing $type images with [join $exposingdetectorlist /] for [join $exposuretimelist /] seconds using [join $nreadslist /] reads."
    log::info "FITS file prefix is $fitsfileprefix."
    file mkdir [file dirname $fitsfileprefix]
    foreach detector $exposingdetectorlist nreads $nreadslist { 
      if {[string equal $detector "C2"] || [string equal $detector "C3"]} {
        client::request $detector "setreadmode $nreads"
      }
    }
    foreach detector $exposingdetectorlist exposuretime $exposuretimelist {
      client::request $detector "expose $exposuretime $type $fitsfileprefix"
    }
    foreach detector $exposingdetectorlist {
      client::wait $detector
    }
    foreach detector $exposingdetectorlist {
      linklatest $detector
    }
    log::info [format "finished exposing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc setreadmodeactivitycommand {args} {
    set start [utcclock::seconds]
    log::info "setting read mode."
    set modes $args
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors mode $modes {
      if {![string equal $mode "none"] && [isactivedetector $detector]} {
        log::info "setting $detector read mode to $mode."
        client::request $detector "setreadmode $mode"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished setting read mode after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setwindowactivitycommand {args} {
    set start [utcclock::seconds]
    log::info "setting window."
    set windows $args
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors window $windows {
      if {![string equal $window "none"] && [isactivedetector $detector]} {
        log::info "setting $detector window to $window."
        client::request $detector "setwindow $window"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished setting window after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setbinningactivitycommand {args} {
    set start [utcclock::seconds]
    log::info "setting binning."
    set binnings $args
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors binning $binnings {
      if {![string equal $binning "none"] && [isactivedetector $detector]} {
        log::info "setting $detector binning to $binning."
        client::request $detector "setbinning $binning"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished setting binning after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setfocuseractivitycommand {args} {
    set start [utcclock::seconds]
    log::info "setting focuser."
    set positions $args
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors position $positions {
      if {![string equal $position "none"] && [isactivedetector $detector]} {
        log::info "setting $detector focuser to $position."
        client::request $detector "setfocuser $position"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished setting focuser after %.1f seconds." [utcclock::diff now $start]]
  }

  proc movefilterwheelactivitycommand {args} {
    set start [utcclock::seconds]
    log::info "moving filter wheel."
    set positions $args
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors position $positions {
      if {![string equal $position "none"] && [isactivedetector $detector]} {
        log::info "moving $detector filter wheel to $position."
        client::request $detector "movefilterwheel $position"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished moving filter wheel after %.1f seconds." [utcclock::diff now $start]]
  }

  proc exposeactivitycommand {type fitsfileprefix args} {
    set start [utcclock::seconds]
    log::info "exposing $type image."
    set exposuretimes $args
    log::info "FITS file prefix is $fitsfileprefix."
    file mkdir [file dirname $fitsfileprefix]
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors exposuretime $exposuretimes {
      if {![string equal $exposuretime "none"] && [isactivedetector $detector]} {
        log::info "exposing $detector for $exposuretime seconds."
        client::request $detector "expose $exposuretime $type $fitsfileprefix"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished exposing $type image after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc analyzeactivitycommand {args} {
    set start [utcclock::seconds]
    log::info "analyzing last image."
    set types $args
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors type $types {
      if {![string equal $type "none"] && [isactivedetector $detector]} {
        log::info "analyzing last $detector image for $type."
        client::request $detector "analyze $type"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished analyzing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc focusactivitycommand {fitsfileprefix range step witness args} {
    set start [utcclock::seconds]
    log::info "focusing."
    set exposuretimes $args
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors exposuretime $exposuretimes {
      if {![string equal $exposuretime "none"] && [isactivedetector $detector]} {
        log::info "focusing $detector."
        client::request $detector "focus $exposuretime $fitsfileprefix $range $step $witness"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished focusing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc mapfocusactivitycommand {fitsfileprefix range step args} {
    set start [utcclock::seconds]
    log::info "mapping focus."
    set exposuretimes $args
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors exposuretime $exposuretimes {
      if {![string equal $exposuretime "none"] && [isactivedetector $detector]} {
        log::info "mapping focus with $detector."
        client::request $detector "mapfocus $exposuretime $fitsfileprefix $range $step"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished mapping focus after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc ratirexposeloopactivitycommand {n C0exposuretime C1exposuretime C2exposuretime C3exposuretime C2nreads C3nreads type fitsfiledirectory} {
    set start [utcclock::seconds]
    log::info "exposing."
    variable detectors
    foreach detector $detectors {
      client::resetifnecessary $detector
    }
    if {$C2nreads == 0} {
      set C2exposuretime "none"
    }
    if {$C3nreads == 0} {
      set C3exposuretime "none"
    }
    if {[string equal $type "astrometry"]} {
      set C4exposuretime "none"
    } else {
      set C4exposuretime $C1exposuretime
    }
    set nreadslist {}
    set exposingdetectorlist {}
    set exposuretimelist {}
    foreach detector $detectors {
      if {![string equal [set ${detector}exposuretime] "none"]} {
        lappend exposingdetectorlist $detector
        lappend exposuretimelist [set ${detector}exposuretime]
        if {[string equal $detector "C0"] || [string equal $detector "C1"] || [string equal $detector "C4"]} {
          lappend nreadslist 1
        } else {
          lappend nreadslist ${detector}nreads
        }
      }
    }
    log::info "exposing $type images with [join $exposingdetectorlist /] for [join $exposuretimelist /] seconds using [join $nreadslist /] reads."
    log::info "exposing $n images in [lindex $exposingdetectorlist 0]."
    log::info "FITS file directory is $fitsfiledirectory."
    file mkdir [file dirname $fitsfileprefix]
    foreach detector $exposingdetectorlist nreads $nreadslist { 
      if {[string equal $detector "C2"] || [string equal $detector "C3"]} {
        client::request $detector "setreadmode $nreads"
      }
    }
    set i 0
    set firstdetector [lindex $exposingdetectorlist 0]
    while {$i <= $n} {
      foreach detector $exposingdetectorlist exposuretime $exposuretimelist {
        client::update $detector
        set activity [client::getdata $detector "activity"]
        if {[string equal $activity "error"]} {
          error "$detector activity is \"error\"."
        } elseif {[string equal $activity "idle"]} {
          if {![string equal $detector $firstdetector] || $i < $n} {
            linklatest $detector
            set fitsfileprefix "$fitsfiledirectory/[utcclock::combinedformat [utcclock::seconds] 0 false]"
            client::request $detector "expose $exposuretime $type $fitsfileprefix"
          }
          if {[string equal $detector $firstdetector]} {
            incr i
          }
        }
      }
      coroutine::after 100
    }      
    foreach detector $exposingdetectorlist {
      client::wait $detector
    }
    foreach detector $exposingdetectorlist {
      linklatest $detector
    }
    log::info [format "finished exposing after %.1f seconds." [utcclock::diff now $start]]
  }


  ######################################################################

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    safetyswitch::checksafetyswitch
    server::newactivitycommand "initializing" "idle" \
      "instrument::initializeactivitycommand"
  }
  
  proc open {} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "opening" "idle" \
      "instrument::openactivitycommand"
  }
  
  proc opentocool {} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "opening" "idle" \
      "instrument::opentocoolactivitycommand"
  }
  
  proc close {} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "closing" "idle" \
      "instrument::closeactivitycommand"
  }
  
  proc emergencyclose {} {
    # Do not check status or activity.
    safetyswitch::checksafetyswitch
    server::newactivitycommand "closing" "idle" \
      "instrument::emergencycloseactivitycommand"
  }
  
  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] \
      "instrument::stopactivitycommand"
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    safetyswitch::checksafetyswitch
    server::newactivitycommand "resetting" [server::getstoppedactivity] \
      "instrument::resetactivitycommand"
  }
  
  proc idle {} {
    server::checkstatus
    server::checkactivityforreset
    safetyswitch::checksafetyswitch
    server::newactivitycommand "idling" "idle" \
      "instrument::idleactivitycommand"
  }
  
  proc ratirmovefilterwheel {position} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    server::newactivitycommand "moving" "idle" \
      "instrument::ratirmovefilterwheelactivitycommand $position"
  }
  
  proc ratirexpose {C0exposuretime C1exposuretime C2exposuretime C3exposuretime C2nreads C3nreads type fitsfileprefix} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    if {
      ![string equal $C0exposuretime "none"] &&
      !([string is double -strict $C0exposuretime] && $C0exposuretime >= 0)
    } {
      error "invalid exposure time for C0 \"$C0exposuretime\"."
    }
    if {
      ![string equal $C1exposuretime "none"] &&
      !([string is double -strict $C1exposuretime] && $C1exposuretime >= 0)
    } {
      error "invalid exposure time for C1 \"$C1exposuretime\"."
    }
    if {
      ![string equal $C2exposuretime "none"] &&
      !([string is double -strict $C2exposuretime] && $C2exposuretime >= 0)
    } {
      error "invalid exposure time for C2 \"$C2exposuretime\"."
    }
    if {
      ![string equal $C3exposuretime "none"] &&
      !([string is double -strict $C3exposuretime] && $C3exposuretime >= 0)
    } {
      error "invalid exposure time for C3 \"$C3exposuretime\"."
    }
    if {
      !([string is integer -strict $C2nreads] && $C2nreads >= 0)
    } {
      error "invalid number of reads for C2 \"$C2nreads\"."
    }
    if {
      !([string is integer -strict $C3nreads] && $C3nreads >= 0)
    } {
      error "invalid number of reads for C3 \"$C3nreads\"."
    }
    if {
      ![string equal $type "object"] &&
      ![string equal $type "firstalertobject"] &&
      ![string equal $type "astrometry"] &&
      ![string equal $type "focus"] &&
      ![string equal $type "flat"] &&
      ![string equal $type "dark"] &&
      ![string equal $type "bias"]
    } {
      error "invalid exposure type \"$type\"."
    }
    set maxexposuretime 0.0
    if {![string equal $C0exposuretime "none"]} {
      set maxexposuretime [expr {max($maxexposuretime,$C0exposuretime)}]
    }
    if {![string equal $C1exposuretime "none"]} {
      set maxexposuretime [expr {max($maxexposuretime,$C1exposuretime)}]
    }
    if {![string equal $C2exposuretime "none"]} {
      set maxexposuretime [expr {max($maxexposuretime,$C2exposuretime)}]
    }
    if {![string equal $C3exposuretime "none"]} {
      set maxexposuretime [expr {max($maxexposuretime,$C3exposuretime)}]
    }
    if {[string equal $type "astrometry"]} {
      set timeoutmilliseconds [expr {1000 * ($maxexposuretime + 600)}]
    } else {
      set timeoutmilliseconds [expr {1000 * ($maxexposuretime + 300)}]
    }
    server::newactivitycommand "exposing" "idle" \
      "instrument::ratirexposeactivitycommand $C0exposuretime $C1exposuretime $C2exposuretime $C3exposuretime $C2nreads $C3nreads $type $fitsfileprefix" \
      $timeoutmilliseconds
  }
  
  proc ratirexposeloop {n C0exposuretime C1exposuretime C2exposuretime C3exposuretime C2nreads C3nreads type fitsfiledirectory} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    if {!([string is integer -strict $n] && $n > 0)
    } {
      error "invalid value for n \"$C0exposuretime\"."
    }
    if {
      ![string equal $C0exposuretime "none"] &&
      !([string is double -strict $C0exposuretime] && $C0exposuretime >= 0)
    } {
      error "invalid exposure time for C0 \"$C0exposuretime\"."
    }
    if {
      ![string equal $C1exposuretime "none"] &&
      !([string is double -strict $C1exposuretime] && $C1exposuretime >= 0)
    } {
      error "invalid exposure time for C1 \"$C1exposuretime\"."
    }
    if {
      ![string equal $C2exposuretime "none"] &&
      !([string is double -strict $C2exposuretime] && $C2exposuretime >= 0)
    } {
      error "invalid exposure time for C2 \"$C2exposuretime\"."
    }
    if {
      ![string equal $C3exposuretime "none"] &&
      !([string is double -strict $C3exposuretime] && $C3exposuretime >= 0)
    } {
      error "invalid exposure time for C3 \"$C3exposuretime\"."
    }
    if {
      !([string is integer -strict $C2nreads] && $C2nreads >= 0)
    } {
      error "invalid number of reads for C2 \"$C2nreads\"."
    }
    if {
      !([string is integer -strict $C3nreads] && $C3nreads >= 0)
    } {
      error "invalid number of reads for C3 \"$C3nreads\"."
    }
    if {
      ![string equal $type "object"] &&
      ![string equal $type "firstalertobject"] &&
      ![string equal $type "astrometry"] &&
      ![string equal $type "focus"] &&
      ![string equal $type "flat"] &&
      ![string equal $type "dark"] &&
      ![string equal $type "bias"]
    } {
      error "invalid exposure type \"$type\"."
    }
    set maxexposuretime 0.0
    if {![string equal $C0exposuretime "none"]} {
      set maxexposuretime [expr {max($maxexposuretime,$C0exposuretime)}]
    }
    if {![string equal $C1exposuretime "none"]} {
      set maxexposuretime [expr {max($maxexposuretime,$C1exposuretime)}]
    }
    if {![string equal $C2exposuretime "none"]} {
      set maxexposuretime [expr {max($maxexposuretime,$C2exposuretime)}]
    }
    if {![string equal $C3exposuretime "none"]} {
      set maxexposuretime [expr {max($maxexposuretime,$C3exposuretime)}]
    }
    if {[string equal $type "astrometry"]} {
      set timeoutmilliseconds [expr {$n * 1000 * ($maxexposuretime + 600)}]
    } else {
      set timeoutmilliseconds [expr {$n * 1000 * ($maxexposuretime + 300)}]
    }
    server::newactivitycommand "exposing" "idle" \
      "instrument::ratirexposeloopactivitycommand $n $C0exposuretime $C1exposuretime $C2exposuretime $C3exposuretime $C2nreads $C3nreads $type $fitsfiledirectory" \
      $timeoutmilliseconds
  }
  
  proc setreadmode {args} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set modes $args
    if {[llength $modes] != [llength $detectors]} {
      error "incorrect number of modes."
    }
    server::newactivitycommand "setting" "idle" \
      "instrument::setreadmodeactivitycommand $modes"
  }
  
  proc setwindow {args} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set windows $args
    if {[llength $windows] != [llength $detectors]} {
      error "incorrect number of windows."
    }
    server::newactivitycommand "setting" "idle" \
      "instrument::setwindowactivitycommand $windows"
  }
  
  proc setbinning {args} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set binnings $args
    if {[llength $binnings] != [llength $detectors]} {
      error "incorrect number of binnings."
    }
    server::newactivitycommand "setting" "idle" \
      "instrument::setbinningactivitycommand $binnings"
  }
  
  proc setfocuser {args} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set positions $args
    if {[llength $positions] != [llength $detectors]} {
      error "incorrect number of positions."
    }
    server::newactivitycommand "setting" "idle" \
      "instrument::setfocuseractivitycommand $positions"
  }
  
  proc movefilterwheel {args} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set positions $args
    if {[llength $positions] != [llength $detectors]} {
      error "incorrect number of positions."
    }
    server::newactivitycommand "moving" "idle" \
      "instrument::movefilterwheelactivitycommand $positions"
  }
  
  proc expose {type fitsfileprefix args} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set exposuretimes $args
    if {[llength $exposuretimes] != [llength $detectors]} {
      error "incorrect number of exposuretimes."
    }
    foreach exposuretime $exposuretimes {
      if {
        ![string equal $exposuretime "none"] &&
        !([string is double -strict $exposuretime] && $exposuretime >= 0)
      } {
        error "invalid exposure time \"$exposuretime\"."
      }
    }
    if {
      ![string equal $type "object"] &&
      ![string equal $type "firstalertobject"] &&
      ![string equal $type "astrometry"] &&
      ![string equal $type "focus"] &&
      ![string equal $type "flat"] &&
      ![string equal $type "dark"] &&
      ![string equal $type "bias"]
    } {
      error "invalid exposure type \"$type\"."
    }
    set maxexposuretime 0.0
    foreach exposuretime $exposuretimes {
      if {![string equal $exposuretime "none"]} {
        set maxexposuretime [expr {max($maxexposuretime,$exposuretime)}]
      }
    }
    if {[string equal $type "astrometry"]} {
      set timeoutmilliseconds [expr {1000 * ($maxexposuretime + 600)}]
    } else {
      set timeoutmilliseconds [expr {1000 * ($maxexposuretime + 300)}]
    }
    server::newactivitycommand "exposing" "idle" \
      "instrument::exposeactivitycommand $type $fitsfileprefix $exposuretimes" \
      $timeoutmilliseconds
  }
  
  proc analyze {args} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set types $args
    if {[llength $types] != [llength $detectors]} {
      error "incorrect number of types."
    }
    foreach type $types {
      if {
        ![string equal $type "none"] &&
        ![string equal $type "levels"] &&
        ![string equal $type "fwhm"] &&
        ![string equal $type "astrometry"]
      } {
        error "invalid  type \"$type\"."
      }
    }
    server::newactivitycommand "analyzing" "idle" \
      "instrument::analyzeactivitycommand $types" \
  }
  
  proc focus {fitsfileprefix range step witness args} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set exposuretimes $args
    if {[llength $exposuretimes] != [llength $detectors]} {
      error "incorrect number of exposure times."
    }
    server::newactivitycommand "focusing" "idle" \
      "instrument::focusactivitycommand $fitsfileprefix $range $step $witness $exposuretimes" false
  }
  
  proc mapfocus {fitsfileprefix range step args} {
    server::checkstatus
    server::checkactivity "idle"
    safetyswitch::checksafetyswitch
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set exposuretimes $args
    if {[llength $exposuretimes] != [llength $detectors]} {
      error "incorrect number of exposure times."
    }
    server::newactivitycommand "mappingfocus" "idle" \
      "instrument::mapfocusactivitycommand $fitsfileprefix $range $step $exposuretimes" false
  }
  
  ######################################################################

  set server::datalifeseconds 0

  proc start {} {
    set start [utcclock::seconds]
    log::info "starting."
    server::setrequestedactivity "started"
    variable detectors
    server::setdata "detectors" [join $detectors]
    variable activedetectors
    server::setdata "activedetectors" [join $activedetectors]
    server::setdata "timestamp" [utcclock::combinedformat]
    server::setactivity [server::getrequestedactivity]
    server::setstatus "ok"
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }

}
