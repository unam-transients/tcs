########################################################################

# This file is part of the RATTEL instrument control system.

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

package require "astrometry"
package require "client"
package require "fitfocus"
package require "server"

package provide "instrument" 0.0

config::setdefaultvalue "instrument" "restartdetectorstorecover" "false"

namespace eval "instrument" {

  ######################################################################

  variable detectors                 [config::getvalue "instrument" "detectors"]
  variable monitoreddetectors        [config::getvalue "instrument" "monitoreddetectors"]
  variable activefocusers            [config::getvalue "instrument" "activefocusers"]
  variable activedetectors           [config::getvalue "instrument" "activedetectors"]
  variable pointingdetectors         [config::getvalue "instrument" "pointingdetectors"]
  variable outletgroups              [config::getvalue "instrument" "outletgroups"]
  variable restartdetectorstorecover [config::getvalue "instrument" "restartdetectorstorecover"]
  
  ######################################################################
  
  proc isactivedetector {detector} {
    variable activedetectors
    if {[lsearch $activedetectors $detector] == -1} {
      return false
    } else {
      return true
    }
  }
  
  proc isactivefocuser {detector} {
    variable activefocusers
    if {[lsearch $activefocusers $detector] == -1 } {
      return false
    } else {
      return [isactivedetector $detector]
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

  proc opentoventilateactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening to ventilate."
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
    log::info [format "finished opening to ventilate after %.1f seconds." [utcclock::diff now $start]]
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
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff now $start]]
  }    

  proc recoveractivitycommand {} {
    set start [utcclock::seconds]
    log::info "recovering."
    variable activedetectors
    variable restartdetectorstorecover
    if {$restartdetectorstorecover} {
      foreach detector $activedetectors {
        if {
          [catch {client::update $detector}] ||
          [client::getdata $detector "timedout"]
        } {
          log::warning "restarting $detector."
          exec tcs stopserver $detector
          coroutine::after 1000
          exec tcs startserver $detector
          coroutine::after 1000
          client::waituntilstarted $detector
        }
      }
    }      
    foreach detector $activedetectors {
      client::waituntilstarted $detector
      client::request $detector "reset"
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    set mustinitialize false
    foreach detector $activedetectors {
      if {[string equal [client::getdata $detector "activity"] "started"]} {
        set mustinitialize true
      }
    }
    if {$mustinitialize} {
      initializeactivitycommand
    }
    log::info [format "finished recovering after %.1f seconds." [utcclock::diff now $start]]
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
    foreach detector $activedetectors {
      client::resetifnecessary $detector
      client::request $detector "setreadmode closed"
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    foreach detector $activedetectors {
      client::resetifnecessary $detector
      client::request $detector "movefilterwheel closed"
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
    catch {recoveractivitycommand}
    catch {closeactivitycommand}
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

  proc movefocuseractivitycommand {args} {
    set start [utcclock::seconds]
    log::info "moving focuser."
    set positions $args
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    variable detectors
    foreach detector $detectors position $positions {
      if {![string equal $position "none"] && [isactivedetector $detector]} {
        log::info "moving $detector focuser to $position."
        client::request $detector "movefocuser $position"
      }
    }
    foreach detector $activedetectors {
      client::wait $detector
    }
    log::info [format "finished moving focuser after %.1f seconds." [utcclock::diff now $start]]
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

  proc exposeactivitycommand {type fitsfileprefix starttime args} {
    set start [utcclock::seconds]
    if {[string equal $starttime "now"]} {
      log::info "exposing $type image."
    } else {
      log::info "exposing $type image after waiting until [utcclock::format $starttime]."
    }
    set exposuretimes $args
    log::info "FITS file prefix is $fitsfileprefix."
    file mkdir [file dirname $fitsfileprefix]
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    log::info [format "finished checking detectors after %.1f seconds." [utcclock::diff now $start]]
    variable detectors
    foreach detector $detectors exposuretime $exposuretimes {
      if {![string equal $exposuretime "none"] && [isactivedetector $detector]} {
        log::info "exposing $detector for $exposuretime seconds."
        client::request $detector "expose $exposuretime $type $fitsfileprefix $starttime"
      }
    }
    log::info [format "finished requesting exposures after %.1f seconds." [utcclock::diff now $start]]
    foreach detector $activedetectors {
      client::waituntilnot $detector "exposing" 500
    }
    log::info [format "reading after %.1f seconds." [utcclock::diff now $start]]
    server::setactivity "reading"
    foreach detector $activedetectors {
      client::wait $detector 500
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
    set worstfwhm ""
    foreach detector $detectors type $types {
      if {![string equal $type "none"] && [isactivedetector $detector]} {
        client::wait $detector
        if {[string equal $type "fwhmwitness"]} {
          set fitsfilename    [file tail [client::getdata $detector "fitsfilename"]]
          set fwhm            [client::getdata $detector "fwhm"]
          set fwhmpixels      [client::getdata $detector "fwhmpixels"]
          set binning         [client::getdata $detector "detectorbinning"]
          set filter          [client::getdata $detector "filter"]
          set focuserposition [client::getdata $detector "focuserposition"]
          set exposuretime    [client::getdata $detector "exposuretime"]
          if {[string equal "$fwhm" ""]} {
            set fwhmarcsec "unknown"
            set fwhmpixels "unknown"
            set worstfwhm "unknown"
          } else {
            set fwhmarcsec [format "%.2fas" [astrometry::radtoarcsec $fwhm]]
            set fwhmpixels [format "%.2f" $fwhmpixels]
            if {
              [string equal $worstfwhm ""] ||
              (![string equal $worstfwhm "unknown"] && $fwhm > $worstfwhm)
            } {
              set worstfwhm $fwhm
            }
            if {![catch {client::update "secondary"}]} {
              set T [client::getdata "secondary" "T"]
              set z [client::getdata "secondary" "z"]
              set dztemperature [client::getdata "secondary" "dztemperature"]
              set dzposition [client::getdata "secondary" "dzposition"]
            } else {
              set T 0
              set z 0
              set dztemperature 0
              set dzposition 0
            }
            set channel [::open [file join [directories::vartoday] "fwhmwitness.csv"] "a"]
            puts $channel [format \
              "\"%s\",\"%s\",%.2f,%d,%.1f,\"%s\",%d,%.2f,%.0f,%.0f,%.0f" \
              $detector $fitsfilename $fwhm $binning $exposuretime $filter $focuserposition $T $z $dztemperature $dzposition \
            ]
            ::close $channel
          }
          log::summary [format \
            "%s witness FWHM is %s (%s pixels with binning %s) in filter %s in %s seconds." \
            $detector $fwhmarcsec $fwhmpixels $binning $filter $exposuretime \
          ]
        }
      }
    }
    if {![string equal $worstfwhm ""]} {
      if {[string equal "$worstfwhm" "unknown"]} {
        set worstfwhmarcsec "unknown"
      } else {
        set worstfwhmarcsec [format "%.2fas" [astrometry::radtoarcsec $worstfwhm]]
      }
      log::summary "worst witness FWHM is $worstfwhmarcsec."
      server::setdata "worstfwhmarcsec" $worstfwhmarcsec
    }
    log::info [format "finished analyzing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc focusactivitycommand {fitsfiledir range step witness initial args} {
    set start [utcclock::seconds]
    log::info "focusing."
    set exposuretimes $args
    variable detectors
    variable activedetectors
    foreach detector $activedetectors {
      client::resetifnecessary $detector
    }
    if {$initial} {
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::request $detector "movefocuser initial"
        }
      }
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::wait $detector
        }
      }
    }
    set zminlist {}
    foreach detector $detectors {
      client::update $detector
      set z [client::getdata $detector "focuserposition"]
      set zmin [expr {$z - $range / 2}]
      lappend zminlist $zmin
    }
    set filenamelist {}
    file mkdir [file join [directories::var] "instrument"]
    foreach detector $detectors {
        set filename [file join [directories::var] "instrument" "focus-$detector"]
        file delete -force $filename
        lappend filenamelist $filename
    }
    set dz 0
    while {$dz <= $range} {
      foreach detector $detectors exposuretime $exposuretimes zmin $zminlist {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          set z [expr {$zmin + $dz}]
          client::request $detector "movefocuser $z"
        }
      }
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::wait $detector
        }
      }
      set dateandtime [utcclock::combinedformat now 0 false]
      set fitsfileprefix "$fitsfiledir/$dateandtime"
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::request $detector "expose $exposuretime focus $fitsfileprefix now"
        }
      }
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::wait $detector
        }
      }
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::request $detector "analyze fwhm"
        }
      }
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::wait $detector
        }
      }
      foreach detector $detectors exposuretime $exposuretimes filename $filenamelist {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          set w [client::getdata $detector "fwhm"]
          set z [client::getdata $detector "focuserposition"]
          if {![string equal $w ""]} {
            set channel [::open $filename "a"]
            puts $channel [format "%.0f %.2e" $z $w]
            ::close $channel
          }
        }
      }
      set dz [expr {$dz + $step}]
    }
    foreach detector $detectors filename $filenamelist zmin $zminlist {
      if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
        if {[catch {
          set channel [::open $filename "r"]
        }]} {
          log::warning "no focus data for $detector."
            set z [expr {$zmin + $range / 2}]
        } else {
          set zlist {}
          set wlist {}
          while {[gets $channel line] > 0} {
            scan $line "%d %f" z w
            lappend zlist $z
            lappend wlist $w
          }
          ::close $channel
          set zmax [expr {$zmin + $range}]
          if {[catch {
            set z [fitfocus::findmin $zlist $wlist $detector]
          } message]} {
            log::warning "fitting failed for $detector: $message"
            set z [expr {$zmin + $range / 2}]
          } elseif {$z < $zmin} {
            set z $zmin
          } elseif {$z > $zmax} {
            set z $zmax
          }
        }
        client::request $detector "movefocuser $z"
      }
    }
    foreach detector $detectors exposuretime $exposuretimes {
      if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
        client::wait $detector
      }
    }
    if {$witness} {
      log::info "taking witness images."
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::wait $detector
        }
      }
      set dateandtime [utcclock::combinedformat now 0 false]
      set fitsfileprefix "$fitsfiledir/$dateandtime"
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::request $detector "expose $exposuretime focus $fitsfileprefix now"
        }
      }
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::wait $detector
        }
      }
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::request $detector "analyze fwhm"
        }
      }
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          client::wait $detector
        }
      }
      foreach detector $detectors exposuretime $exposuretimes {
        if {![string equal $exposuretime "none"] && [isactivefocuser $detector]} {
          set fitsfilename [file tail [client::getdata $detector "fitsfilename"]]
          set fwhm         [client::getdata $detector "fwhm"]
          set fwhmpixels   [client::getdata $detector "fwhmpixels"]
          set binning      [client::getdata $detector "detectorbinning"]
          set filter       [client::getdata $detector "filter"]
          set exposuretime [client::getdata $detector "exposuretime"]
          set z            [client::getdata $detector "focuserposition"]
          if {[string equal "$fwhm" ""]} {
            log::summary [format "$fitsfilename: $detector witness FWHM is unknown (with binning $binning) in filter $filter at focuser position $z in $exposuretime seconds."]
          } else {
            log::summary [format \
              "$fitsfilename: $detector witness FWHM is %.2fas (%.2f pixels with binning $binning) in filter $filter at focuser position $z in $exposuretime seconds." \
              [astrometry::radtoarcsec $fwhm] $fwhmpixels \
            ]
          }
        }
      }
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
  
  ######################################################################

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" \
      "instrument::initializeactivitycommand"
  }
  
  proc open {} {
    server::checkstatus
    server::checkactivity "idle"
    server::newactivitycommand "opening" "idle" \
      "instrument::openactivitycommand"
  }
  
  proc opentoventilate {} {
    server::checkstatus
    server::checkactivity "idle"
    server::newactivitycommand "opening" "idle" \
      "instrument::opentoventilateactivitycommand"
  }
  
  proc close {} {
    server::checkstatus
    server::checkactivity "idle"
    server::newactivitycommand "closing" "idle" \
      "instrument::closeactivitycommand"
  }
  
  proc emergencyclose {} {
    # Do not check status or activity.
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
    server::newactivitycommand "resetting" [server::getstoppedactivity] \
      "instrument::resetactivitycommand"
  }
  
  proc recover {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "recovering" "idle" \
      "instrument::recoveractivitycommand"
  }

  proc idle {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "idling" "idle" \
      "instrument::idleactivitycommand"
  }
  
  proc setreadmode {args} {
    server::checkstatus
    server::checkactivity "idle"
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
  
  proc movefocuser {args} {
    server::checkstatus
    server::checkactivity "idle"
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set positions $args
    if {[llength $positions] != [llength $detectors]} {
      error "incorrect number of positions."
    }
    server::newactivitycommand "moving" "idle" \
      "instrument::movefocuseractivitycommand $positions"
  }
  
  proc setfocuser {args} {
    server::checkstatus
    server::checkactivity "idle"
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
  
  proc expose {type args} {
    set fitsfileprefix [file join [directories::vartoday] "instrument" "images"]
    eval exposefull $type $fitsfileprefix "now" $args
  }
  
  proc exposefull {type fitsfiledir starttime args} {
    server::checkstatus
    server::checkactivity "idle"
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
    set dateandtime [utcclock::combinedformat now 0 false]
    set fitsfileprefix "$fitsfiledir/$dateandtime"
    server::newactivitycommand "exposing" "idle" \
      "instrument::exposeactivitycommand $type $fitsfileprefix $starttime $exposuretimes" \
      $timeoutmilliseconds
  }
  
  proc analyze {args} {
    server::checkstatus
    server::checkactivity "idle"
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
        ![string equal $type "fwhmwitness"] &&
        ![string equal $type "center"] &&
        ![string equal $type "astrometry"]
      } {
        error "invalid  type \"$type\"."
      }
    }
    server::newactivitycommand "analyzing" "idle" \
      "instrument::analyzeactivitycommand $types" \
  }
  
  proc focus {fitsfiledir range step witness initial args} {
    server::checkstatus
    server::checkactivity "idle"
    variable detectors
    if {[llength $args] == 1} {
      set args [lrepeat [llength $detectors] $args]
    }
    set exposuretimes $args
    if {[llength $exposuretimes] != [llength $detectors]} {
      error "incorrect number of exposure times."
    }
    server::newactivitycommand "focusing" "idle" \
      "instrument::focusactivitycommand $fitsfiledir $range $step $witness $initial $exposuretimes" false
  }
  
  proc mapfocus {fitsfileprefix range step args} {
    server::checkstatus
    server::checkactivity "idle"
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
    variable monitoreddetectors
    server::setdata "monitoreddetectors" [join $monitoreddetectors]
    variable activedetectors
    server::setdata "activedetectors" [join $activedetectors]
    variable activefocusers
    server::setdata "activefocusers" [join $activefocusers]
    server::setdata "timestamp" [utcclock::combinedformat]
    server::setactivity [server::getrequestedactivity]
    server::setstatus "ok"
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }

}
