########################################################################

# This file is part of the UNAM telescope control system.

# $Id: executor.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "alert"
package require "block"
package require "constraints"
package require "directories"
package require "fitfocus"
package require "client"
package require "project"
package require "server"
package require "visit"

if  {![string equal [config::getvalue "executor" "type"] ""]} {
  package require executor[config::getvalue "executor" "type"] 
}

package provide "executor" 0.0

namespace eval "executor" {

  variable svnid {$Id}

  ######################################################################
  
  variable detectors         [config::getvalue "instrument" "detectors"]
  variable pointingdetectors [config::getvalue "instrument" "pointingdetectors"]
  
  ######################################################################
  
  proc switchlightsonactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "switching lights on."
    catch {client::waituntilstarted "lights"}
    client::request "lights" "switchon"
    client::wait "lights"
    log::summary [format "finished switching lights on after %.1f seconds." [utcclock::diff now $start]]
  }

  proc switchlightsoffactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "switching lights off."
    catch {client::waituntilstarted "lights"}
    client::request "lights" "switchoff"
    client::wait "lights"
    log::summary [format "finished switching lights off after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  variable trackstart
  
  proc track {{alphaoffset 0} {deltaoffset 0} {aperture "default"}} {
    variable trackstart
    set trackstart [utcclock::seconds]
    log::info "moving to track."
#    set alpha     [visit::alpha]
#    set delta     [visit::delta]
#    set equinox   [visit::equinox]
#    set alpharate [visit::alpharate]
#    set deltarate [visit::deltarate]
#    set epoch     [visit::epoch]
#    astrometry::parseoffset $alphaoffset
#    astrometry::parseoffset $deltaoffset
#    log::info [format \
#      "moving to track %s %s %s %s %s %s %s %s at aperture %s." \
#      [astrometry::formatalpha $alpha] \
#      [astrometry::formatdelta $delta] \
#      $equinox \
#      [astrometry::formatoffset $alphaoffset] \
#      [astrometry::formatoffset $deltaoffset] \
#      $epoch \
#      [astrometry::formatrate $alpharate] \
#      [astrometry::formatrate $deltarate] \
#      $aperture \
#    ]
#    client::request "telescope" \
#      "track $alpha $delta $equinox $alphaoffset $deltaoffset $epoch $alpharate $deltarate $aperture"
  }
  
  proc tracktopocentric {} {
    variable trackstart
    set trackstart [utcclock::seconds]
    log::info "moving to track topocentric coordinates."
#    set ha    [visit::observedha]
#    set delta [visit::observeddelta]
#    log::info [format \
#      "moving to track topocentric coordinates %s %s." \
#      [astrometry::formatha $ha] \
#      [astrometry::formatdelta $delta] \
#    ]
#    client::request "telescope" "tracktopocentric $ha $delta"
  }
  
  proc offset {{alphaoffset 0} {deltaoffset 0} {aperture "default"}} {
    variable trackstart
    set trackstart [utcclock::seconds]
    astrometry::parseoffset $alphaoffset
    astrometry::parseoffset $deltaoffset
    log::info [format \
      "offsetting to %s %s at aperture %s." \
      [astrometry::formatoffset $alphaoffset] \
      [astrometry::formatoffset $deltaoffset] \
      $aperture \
    ]
    client::request "telescope" "offset $alphaoffset $deltaoffset $aperture"
  } 
  
  proc waituntiltracking {} {
    variable trackstart
    client::wait "telescope" 
    log::info [format "tracking after %.1f seconds." [utcclock::diff now $trackstart]]
  }
  
  ######################################################################

  proc focusfinders {exposuretime} {
    log::summary "focusing finders."
    client::request "telescope" "focusfinders $exposuretime"
    client::wait "telescope"     
    log::summary "finished focusing finders."
  }
  
  ######################################################################

  proc focussecondary {detector exposuretime {z0range 300} {z0step 20} {witness true}} {
    set start [utcclock::seconds]
    log::info "focusing secondary on $detector with range $z0range and step $z0step."
    client::update "secondary"
    set z0 [client::getdata "secondary" "requestedz0"]
    set originalz0 $z0
    variable detectors
    set exposuretimes [lrepeat [llength $detectors] "none"]
    lset exposuretimes [lsearch -exact $detectors $detector] $exposuretime
    set analyzetypes [lrepeat [llength $detectors] "none"]
    lset analyzetypes [lsearch -exact $detectors $detector] "fwhm"
    while {true} {
      set z0min [expr {int($z0 - 0.5 * $z0range)}]
      set z0max [expr {int($z0 + 0.5 * $z0range)}]
      log::info "focusing secondary on $detector from $z0min to $z0max in steps of $z0step."
      set z0 $z0min
      set z0list   {}
      set fwhmlist {}
      while {$z0 <= $z0max} {
        client::request "telescope" "movesecondary $z0"
        client::wait "telescope"
        eval expose "object" $exposuretimes
        eval analyze $analyzetypes
        client::update $detector
        set fitsfilename [file tail [client::getdata $detector "fitsfilename"]]
        set fwhm         [client::getdata $detector "fwhm"]
        set binning      [client::getdata $detector "detectorbinning"]
        set filter       [client::getdata $detector "filter"]
        if {[string equal "$fwhm" ""]} {
          log::info "$fitsfilename: FWHM is unknown with binning $binning in filter $filter at secondary position $z0 in ${exposuretime}s."
        } else {
          log::info "$fitsfilename: FWHM is $fwhm pixels with binning $binning in filter $filter at secondary position $z0 in ${exposuretime}s."
          lappend z0list   $z0
          lappend fwhmlist $fwhm
        }
        set z0 [expr {$z0 + $z0step}]
      }
      if {[catch {
        set z0 [fitfocus::findmin $z0list $fwhmlist]
      } message]} {
        log::warning "fitting failed: $message"
        set z0 $originalz0
        break
      } elseif {$z0 < $z0min} {
        set z0 $z0min
      } elseif {$z0 > $z0max} {
        set z0 $z0max
      } else {
        break
      }
      log::info "focusing secondary again around $z0."
    }
    client::request "telescope" "movesecondary $z0 true"
    client::wait "telescope"
    if {$witness} {
      set i 0
      while {$i < 3} {
        incr i
        eval expose "focus" [lrepeat [llength $detectors] $exposuretime]
        eval analyze [lrepeat [llength $detectors] "fwhm"]
        foreach detector $detectors {
          client::update $detector
          set fitsfilename [file tail [client::getdata $detector "fitsfilename"]]
          set fwhm         [client::getdata $detector "fwhm"]
          set binning      [client::getdata $detector "detectorbinning"]
          set filter       [client::getdata $detector "filter"]
          if {[string equal "$fwhm" ""]} {
            log::summary "$fitsfilename: witness FWHM is unknown with binning $binning in filter $filter at secondary position $z0 in ${exposuretime}s."
          } else {
            log::summary "$fitsfilename: witness FWHM is $fwhm pixels with binning $binning in filter $filter at secondary position $z0 in ${exposuretime}s."
            if {[catch {
              client::update "secondary"
              set T [client::getdata "secondary" "T"]
              set z [client::getdata "secondary" "z"]
              set dzT [client::getdata "secondary" "dzT"]
              set dzP [client::getdata "secondary" "dzP"]
              set channel [::open [file join [directories::vartoday] "focus.csv"] "a"]
              puts $channel [format \
                "\"%s\",%.2f,%d,%.1f,\"%s\",%.2f,%.0f,%.0f,%.0f" \
                $fitsfilename $fwhm $binning $exposuretime $filter $T $z $dzT $dzP \
              ]
              ::close $channel
            } message]} {
              log::warning "unable to write focus.csv file: $message"
            }
          }
        }
      }
    }
    log::info [format "finished focusing secondary after %.1f seconds." [utcclock::diff now $start]]
  }
  
  ######################################################################

  proc expose {type args} {
    set start [utcclock::seconds]
    variable exposure
    log::info "exposing $type image for $args (exposure $exposure)."
    set date [utcclock::formatdate $start false]
    set dateandtime [utcclock::combinedformat $start 0 false]
    set projectfullidentifier [server::getdata "projectfullidentifier"]
    set blockidentifier [server::getdata "blockidentifier"]
    set visitidentifier [server::getdata "visitidentifier"]
    set fitsfileprefix "[directories::vartoday]/executor/images/$projectfullidentifier/$blockidentifier/$visitidentifier/$dateandtime"
    log::info "FITS file prefix is $fitsfileprefix."
    file mkdir [file dirname $fitsfileprefix]
    client::request "instrument" "expose $type $fitsfileprefix $args"
    client::wait "instrument"
    log::info [format "finished exposing $type image (exposure $exposure) after %.1f seconds." [utcclock::diff now $start]]
    set exposure [expr {$exposure + 1}]
  }
  
  proc analyze {args} {
    set start [utcclock::seconds]
    log::info "analyzing $args."
    client::request "instrument" "analyze $args"
    client::wait "instrument"
    log::info [format "finished analyzing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setreadmode {args} {
    set start [utcclock::seconds]
    set modes $args
    log::info "setting read mode to $modes."
    client::request "instrument" "setreadmode $args"
    client::wait "instrument"
    log::info [format "finished setting read modes after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setwindow {args} {
    set start [utcclock::seconds]
    set windows $args
    log::info "setting window to $windows."
    client::request "instrument" "setwindow $windows"
    client::wait "instrument"
    log::info [format "finished setting window after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setbinning {args} {
    set start [utcclock::seconds]
    set binnings $args
    log::info "setting binning to $binnings."
    client::request "instrument" "setbinning $binnings"
    client::wait "instrument"
    log::info [format "finished setting binning after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setfocuser {args} {
    set start [utcclock::seconds]
    set positions $args
    log::info "setting focuser to $positions."
    client::request "instrument" "setfocuser $positions"
    client::wait "instrument"
    log::info [format "finished setting focuser after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc focus {range step witness args} {
    set start [utcclock::seconds]
    log::info "focusing with range $range and step $step."
    set projectfullidentifier [server::getdata "projectfullidentifier"]
    set blockidentifier [server::getdata "blockidentifier"]
    set visitidentifier [server::getdata "visitidentifier"]
    set fitsfileprefix "[directories::vartoday]/executor/images/$projectfullidentifier/$blockidentifier/$visitidentifier/"
    log::info "FITS file prefix is $fitsfileprefix."
    file mkdir [file dirname $fitsfileprefix]
    client::request "instrument" "focus $fitsfileprefix $range $step $witness $args"
    client::wait "instrument"
    log::info [format "finished focusing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc mapfocus {range step args} {
    set start [utcclock::seconds]
    log::info "mapping focus with range $range and step $step."
    set projectfullidentifier [server::getdata "projectfullidentifier"]
    set blockidentifier [server::getdata "blockidentifier"]
    set visitidentifier [server::getdata "visitidentifier"]
    set fitsfileprefix "[directories::vartoday]/executor/images/$projectfullidentifier/$blockidentifier/$visitidentifier/"
    log::info "FITS file prefix is $fitsfileprefix."
    file mkdir [file dirname $fitsfileprefix]
    client::request "instrument" "mapfocus $fitsfileprefix $range $step $args"
    client::wait "instrument"
    log::info [format "finished mapping focus after %.1f seconds." [utcclock::diff now $start]]
  }
  
  ######################################################################

  proc correctpointing {exposuretime} {
    set start [utcclock::seconds]
    variable pointingdetectors
    log::info "attempting to correct the pointing model using $pointingdetectors."
    variable detectors
    set exposuretimes [lrepeat [llength $detectors] "none"]
    set analyzetypes  [lrepeat [llength $detectors] "none"]
    foreach detector $pointingdetectors {
      lset exposuretimes [lsearch -exact $detectors $detector] $exposuretime
      lset analyzetypes  [lsearch -exact $detectors $detector] "astrometry"
    } 
    if {$exposuretime != 0} {
      eval expose "object" $exposuretimes
    }
    eval analyze $analyzetypes
    set alphalist {}
    set deltalist {}
    foreach detector $pointingdetectors {
      client::update $detector
      set alpha   [client::getdata $detector "solvedalpha"]
      set delta   [client::getdata $detector "solveddelta"]
      set equinox [client::getdata $detector "solvedequinox"]
      if {[string equal $alpha ""]} {
        log::warning "$detector pointing did not solve: unable to correct pointing."
        client::resetifnecessary "telescope"
        client::resetifnecessary "instrument"
        client::wait "telescope"
        client::wait "instrument"
        log::info [format "finished attempting to correct the pointing model after %.1f seconds." [utcclock::diff now $start]]
        return
      }
      log::info "$detector pointing solved as [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox."
      lappend alphalist $alpha
      lappend deltalist $delta
    }
    set alpha [astrometry::meanalpha $alphalist $deltalist]
    set delta [astrometry::meandelta $alphalist $deltalist]
    log::info "mean pointing is [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox."
    client::request "telescope" "correct [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox"
    client::wait "telescope"
    log::info [format "finished attempting to correct the pointing model after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  variable exposure

  ######################################################################
  
  proc updatedata {completed blockfile project block visit} {
  
    server::setdata "completed" $completed

    server::setdata "blockfile" [file tail $blockfile]

    if {[string equal $project ""]} {
      server::setdata "projectfullidentifier" ""
      server::setdata "projectidentifier"     ""
      server::setdata "projectname"           ""
    } else {
      server::setdata "projectfullidentifier" [project::fullidentifier $project]
      server::setdata "projectidentifier"     [project::identifier $project]
      server::setdata "projectname"           [project::name $project]
    }
    
    if {[string equal $block ""]} {
      server::setdata "blockidentifier"   ""
      server::setdata "blockname"         ""
    } else {
      server::setdata "blockidentifier"   [block::identifier $block]
      server::setdata "blockname"         [block::name $block]
    }

    if {[string equal $visit ""]} {
      server::setdata "visitidentifier"   ""
      server::setdata "visitname"         ""
      server::setdata "visitcommand"      ""
    } else {
      server::setdata "visitidentifier"   [visit::identifier $visit]
      server::setdata "visitname"         [visit::name $visit]
      server::setdata "visitcommand"      [visit::command $visit]
    }
    
    server::setdata "alerttype"             [alert::type]
    if {[string equal "" [alert::type]]} {
      server::setdata "alerteventidentifier"   ""
      server::setdata "alertalerttimestamp"    ""
      server::setdata "alerteventtimestamp"    ""
      server::setdata "alertalpha"             ""
      server::setdata "alertdelta"             ""
      server::setdata "alertequinox"           ""
      server::setdata "alertuncertainty"       ""
    } else {
      server::setdata "alerteventidentifier"   [alert::eventidentifier]
      server::setdata "alertalerttimestamp"    [alert::alerttimestamp]
      server::setdata "alerteventtimestamp"    [alert::eventtimestamp]
      server::setdata "alertalpha"             [astrometry::parsealpha   [visit::alpha]]
      server::setdata "alertdelta"             [astrometry::parsedelta   [visit::delta]]
      server::setdata "alertequinox"           [astrometry::parseequinox [visit::equinox]]
      server::setdata "alertuncertainty"       [astrometry::parseoffset [alert::uncertainty]]
    }

    server::setdata "timestamp" [utcclock::combinedformat]

  }

  ######################################################################

  proc setpointingaperture {pointingaperture} {
    client::request "telescope" "setpointingaperture $pointingaperture"
    client::wait "telescope" 
  }
  
  proc setpointingmode {pointingmode} {
  
    client::request "telescope" "setpointingmode $pointingmode"
    client::wait "telescope" 
  }
  
  proc setguidingmode {guidingmode} {
    client::request "telescope" "setguidingmode $guidingmode"
    client::wait "telescope" 
  }
  
  proc getguidingmode {} {
    client::update "telescope"
    client::getdata "telescope" "guidingmode"
  }
  
  proc move {} {
    set start [utcclock::seconds]
#    set ha    [visit::observedha]
#    set delta [visit::observeddelta]
#    log::info [format \
#      "moving to %s %s." \
#      [astrometry::formatha $ha] \
#      [astrometry::formatdelta $delta] \
#    ]
#    client::request "telescope" "move $ha $delta"
    client::wait "telescope" 
    log::info [format "finished moving after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  proc setsecondaryoffset {dz} {
    set start [utcclock::seconds]
    log::info "setting secondary offset to $dz."
    client::request "telescope" "setsecondaryoffset $dz"
    client::wait "telescope"     
    log::info [format "finished setting secondary offset after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setfocused {} {
    set start [utcclock::seconds]
    log::info "setting focused timestamp."
    client::request "scheduler" "setfocused"
    log::info [format "finished finished setting focused timestamp after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setunfocused {} {
    set start [utcclock::seconds]
    log::info "unsetting focused timestamp."
    client::request "scheduler" "setunfocused"
    log::info [format "finished unsetting focused timestamp after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  proc exposureaverage {detector} {
    client::update $detector
    set average [client::getdata $detector "average"]    
    log::info [format "average signal in %s is %.1f DN." $detector $average]
    return $average
  }

  ######################################################################

  proc files {blockfile alertfile} {
    if {[string equal $alertfile ""]} {
      return "block file \"[file tail $blockfile]\""
    } else {
      return "block file \"[file tail $blockfile]\" with alert file \"[file tail $alertfile]\""
    }
  }
  
  proc executeactivitycommand {blockfile {alertfile ""}} {

    log::info "executing [files $blockfile $alertfile]."

    set start [utcclock::seconds]

    updatedata false $blockfile "" "" ""

#    alert::start $alertfile

    set visitcommandsfile [file join [directories::etc] "visitcommands.tcl"]
    if {[catch {
      source $visitcommandsfile
    } result]} {
      error "while loading visit commands file: $result"
    }

    variable exposure
    set exposure 0
    
    if {[catch {
      set block [block::readfile $blockfile]
    }]} {
      updatedata true $blockfile "" "" ""
      log::error "while reading block file \"[file tail $blockfile]\": $result"
      log::info "deleting block file \"[file tail $blockfile]\"."
      file delete -force $blockfile
      return
    }
    
    set project [block::project $block]
    updatedata false $blockfile $project $block ""

    log::summary "executing block [block::identifier $block] of project [project::identifier $project]."
    if {![string equal "" [project::name $block]]} {
      log::info "project name is \"[project::name $project]\"."
    }
    if {![string equal "" [block::name $block]]} {
      log::info "block name is \"[block::name $block]\"."
    }
    
#    if {![string equal $alertfile ""]} {
#      if {[catch {
#        source $alertfile
#      } result]} {
#        log::warning "while loading alert file $alertfile: $result"
#        file delete -force $alertfile
#        return
#      }
#    }
    
    variable visit
    foreach visit [block::visits $block] {

      updatedata false $blockfile $project $block $visit

      log::summary "executing visit [visit::identifier $visit] of block [block::identifier $block] of project [project::identifier $project]."
      if {![string equal [visit::name $visit] ""]} {
        log::summary "visit name is \"[visit::name $visit]\"."
      }
      log::info "visit command is \"[visit::command $visit]\"."

      if {[catch {
        eval [visit::command $visit]
      } result]} {
        log::error "while executing visit: $result"
        set result true
        break
      }

    }
    
    if {![string is boolean -strict "$result"]} {
      log::warning "while executing visit: visit command returned \"$result\" instead of a boolean; assuming true."
      set result true
    }
    if {$result && [string equal $alertfile ""]} {
      log::info "deleting block file \"[file tail $blockfile]\"."
      file delete -force $blockfile
    }

    server::setdata "completed" true
    server::setdata "timestamp" [utcclock::combinedformat]
    updatedata true $blockfile "" "" ""

    log::summary [format "finished executing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "stopping."
    foreach server {telescope instrument} {
      client::request $server "stop"
    }
    foreach server {telescope instrument} {
      client::wait $server
    }
    log::summary [format "finished stopping after %.1f seconds." [utcclock::diff now $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "resetting."
    foreach server {telescope instrument} {
      catch {client::waituntilstarted $server}
    }
    foreach server {telescope instrument} {
      client::request $server "reset"
    }
    foreach server {telescope instrument} {
      client::wait $server
    }
    log::summary [format "finished resetting after %.1f seconds." [utcclock::diff now $start]]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "initializing."
    foreach server {instrument telescope} {
      catch {client::waituntilstarted $server}
      client::request $server "initialize"
      client::wait $server
    }
    log::summary [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "opening."
    foreach server {instrument telescope} {
      catch {client::waituntilstarted $server}
      client::request $server "open"
      client::wait $server
    }
    log::summary [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
  }

  proc opentocoolactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "opening to cool."
    foreach server {instrument telescope} {
      catch {client::waituntilstarted $server}
      client::request $server "opentocool"
      client::wait $server
    }
    log::summary [format "finished opening to cool after %.1f seconds." [utcclock::diff now $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "closing."
    set error false
    foreach server {telescope instrument} {
      if {[catch {
        client::waituntilstarted $server
        client::request $server "close"
        client::wait $server
      }]} {
        log::error "unable to close $server."
        set error true
      }
    }
    if {$error} {
      error "unable to close."
    }
    log::summary [format "finished closing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc emergencycloseactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "emergency closing."
    foreach server {telescope instrument} {
      catch {client::waituntilstarted $server}
      catch {client::request $server "emergencyclose"}
      catch {client::wait $server}
    }
    log::summary [format "finished emergency closing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc idleactivitycommand {} {
    set start [utcclock::seconds]
    log::info "idling."
    foreach server {telescope instrument} {
      catch {client::waituntilstarted $server}
    }
    foreach server {telescope instrument} {
      client::request $server "reset"
    }
    foreach server {telescope instrument} {
      client::wait $server
    }
    client::request "telescope" "movetoidle"
    client::request "instrument" "idle"
    foreach server {telescope instrument} {
      client::wait $server
    }
    log::info [format "finished idling after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] \
      "executor::stopactivitycommand"
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] \
      "executor::resetactivitycommand"
  }
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" \
      "executor::initializeactivitycommand" 1800e3
  }
  
  proc open {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "opening" "idle" \
      "executor::openactivitycommand" 900e3
  }
  
  proc opentocool {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "opening" "idle" \
      "executor::opentocoolactivitycommand" 900e3
  }
  
  proc close {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "closing" "idle" \
      "executor::closeactivitycommand" 900e3
  }
  
  proc emergencyclose {} {
    # Do not check status or activity.
    server::newactivitycommand "closing" "idle" \
      "executor::emergencycloseactivitycommand" 900e3
  }
  
  proc execute {blockfile alertfile} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "executing" "idle" \
      "executor::executeactivitycommand $blockfile $alertfile" 7200e3
  }
  
  proc idle {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "executing" "idle" \
      "executor::idleactivitycommand"
  }
  
  proc switchlightson {} {
    server::checkstatus
    server::checkactivityforswitch
    server::newactivitycommand "switchingon" [server::getactivity] \
      "executor::switchlightsonactivitycommand"
  }
  
  proc switchlightsoff {} {
    server::checkstatus
    server::checkactivityforswitch
    server::newactivitycommand "switchingoff" [server::getactivity] \
      "executor::switchlightsoffactivitycommand"
  }
  
  ######################################################################

  set server::datalifeseconds 0

  proc start {} {
    server::setrequestedactivity "started"
    server::setdata "blockfile" ""
    server::setdata "alertfile" ""
    server::setdata "completed" false
    server::setdata "timestamp" [utcclock::combinedformat]
    alert::start ""
    updatedata false "" "" "" ""
    
    server::setactivity [server::getrequestedactivity]
    server::setstatus "ok"
  }

}
