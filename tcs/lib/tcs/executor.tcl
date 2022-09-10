########################################################################

# This file is part of the UNAM telescope control system.

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

  ######################################################################
  
  variable detectors         [config::getvalue "instrument" "detectors"]
  variable pointingdetectors [config::getvalue "instrument" "pointingdetectors"]
  
  ######################################################################
  
  variable filetype ""
  variable filename ""
  variable project  ""
  variable block    ""
  variable alert    ""
  variable visit    ""
  
  proc setfiles {newfiletype newfilename} {
    variable filetype
    variable filename
    set filetype $newfiletype
    set filename $newfilename
    updatefiledata
  }
  
  proc filetype {} {
    variable filetype
    return $filetype
  }
  
  proc filename {} {
    variable filename
    return $filename
  }
  
  proc setproject {newproject} {
    variable project
    set project $newproject
    updateprojectdata
  }
  
  proc project {} {
    variable project
    return $project
  }
  
  proc setblock {newblock} {
    variable block
    set block $newblock
    updateblockdata
  }
  
  proc block {} {
    variable block
    return $block
  }
  
  proc setalert {newalert} {
    variable alert
    set alert $newalert
    updatealertdata
  }
  
  proc alert {} {
    variable alert
    return $alert
  }
  
  proc setvisit {newvisit} {
    variable visit
    set visit $newvisit
    updatevisitdata
  }
  
  proc visit {} {
    variable visit
    return $visit
  }
  
  ######################################################################

  variable trackstart
  
  proc track {{alphaoffset 0} {deltaoffset 0} {aperture "default"}} {
    variable trackstart
    set trackstart [utcclock::seconds]
    log::info "moving to track."
    set alpha     [visit::alpha [visit]]
    set delta     [visit::delta [visit]]
    set equinox   [visit::equinox [visit]]
    set alpharate [visit::alpharate [visit]]
    set deltarate [visit::deltarate [visit]]
    set epoch     [visit::epoch [visit]]
    astrometry::parseoffset $alphaoffset
    astrometry::parseoffset $deltaoffset
    log::info [format \
      "moving to track %s %s %s %s %s %s %s %s at aperture %s." \
      [astrometry::formatalpha $alpha] \
      [astrometry::formatdelta $delta] \
      $equinox \
      [astrometry::formatoffset $alphaoffset] \
      [astrometry::formatoffset $deltaoffset] \
      $epoch \
      [astrometry::formatrate $alpharate] \
      [astrometry::formatrate $deltarate] \
      $aperture \
    ]
    client::request "telescope" \
      "track $alpha $delta $equinox $alphaoffset $deltaoffset $epoch $alpharate $deltarate $aperture"
  }
  
  proc tracktopocentric {} {
    variable trackstart
    set trackstart [utcclock::seconds]
    log::info "moving to track topocentric coordinates."
    set ha    [visit::observedha [visit]]
    set delta [visit::observeddelta [visit]]
    log::info [format \
      "moving to track topocentric coordinates %s %s." \
      [astrometry::formatha $ha] \
      [astrometry::formatdelta $delta] \
    ]
    client::request "telescope" "tracktopocentric $ha $delta"
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

  proc focussecondary {detector exposuretime {z0range 300} {z0step 20} {witness true} {initial false}} {
    set start [utcclock::seconds]
    log::info "focusing secondary on $detector with range $z0range and step $z0step."
    if {$initial} {
      client::request "telescope" "movesecondary initialz0"
      client::wait "telescope"
    }
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
          log::info [format "$fitsfilename: FWHM is unknown with binning $binning in filter $filter at secondary position $z0 in %.0f seconds." $exposuretime]
        } else {
          log::info [format "$fitsfilename: FWHM is %.2f pixels with binning $binning in filter $filter at secondary position $z0 in %.0f seconds." $fwhm $exposuretime]
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
    client::request "telescope" "movesecondary $z0"
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
            log::summary [format "$fitsfilename: witness FWHM is unknown with binning $binning in filter $filter at secondary position $z0 in $exposuretime seconds."]
          } else {
            log::summary [format "$fitsfilename: witness FWHM is %.2f pixels with binning $binning in filter $filter at secondary position $z0 in $exposuretime seconds." $fwhm]
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
  
  proc focuswitness {} {
    variable detectors
    eval analyze [lrepeat [llength $detectors] "fwhm"]
    foreach detector $detectors {
      client::update $detector
      set fitsfilename [file tail [client::getdata $detector "fitsfilename"]]
      set fwhm         [client::getdata $detector "fwhm"]
      set binning      [client::getdata $detector "detectorbinning"]
      set filter       [client::getdata $detector "filter"]
      set exposuretime [client::getdata $detector "exposuretime"]
      if {[string equal "$fwhm" ""]} {
        log::summary [format "$fitsfilename: witness FWHM is unknown with binning $binning in filter $filter in %.0f seconds." $exposuretime]
      } else {
        log::summary [format "$fitsfilename: witness FWHM is %.2f pixels with binning $binning in filter $filter in %.0f seconds." $fwhm $exposuretime]
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
  
  ######################################################################

  proc expose {type args} {
    set start [utcclock::seconds]
    variable exposure
    set exposuretimes $args
    log::info "exposing $type image for [join $exposuretimes /] seconds (exposure $exposure)."
    set projectfullidentifier [server::getdata "projectfullidentifier"]
    set fitsfiledir "[directories::vartoday]/executor/images/[project::fullidentifier [project]]/[block::identifier [block]]/[visit::identifier [visit]]"
    file mkdir $fitsfiledir
    client::request "instrument" "expose $type $fitsfiledir $exposuretimes"
    client::wait "instrument"
    log::info [format "finished exposing $type image (exposure $exposure) after %.1f seconds." [utcclock::diff now $start]]
    set exposure [expr {$exposure + 1}]
  }
  
  proc analyze {args} {
    set start [utcclock::seconds]
    set types $args
    log::info "analyzing [join $types /]."
    client::request "instrument" "analyze $types"
    client::wait "instrument"
    log::info [format "finished analyzing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setreadmode {args} {
    set start [utcclock::seconds]
    set modes $args
    log::info "setting read mode to [join $modes /]."
    client::request "instrument" "setreadmode $args"
    client::wait "instrument"
    log::info [format "finished setting read modes after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setwindow {args} {
    set start [utcclock::seconds]
    set windows $args
    log::info "setting window to [join $windows /]."
    client::request "instrument" "setwindow $windows"
    client::wait "instrument"
    log::info [format "finished setting window after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setbinning {args} {
    set start [utcclock::seconds]
    set binnings $args
    log::info "setting binning to [join $binnings /]."
    client::request "instrument" "setbinning $binnings"
    client::wait "instrument"
    log::info [format "finished setting binning after %.1f seconds." [utcclock::diff now $start]]
  }

  proc movefilterwheel {args} {
    set start [utcclock::seconds]
    set positions $args
    log::info "moving filter wheel to [join $positions /]."
    client::request "instrument" "movefilterwheel $positions"
    client::request "secondary"  "moveforfilter [lindex $positions 0]"
    client::wait "instrument"
    client::wait "secondary"
    log::info [format "finished moving filter wheel after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setfocuser {args} {
    set start [utcclock::seconds]
    set positions $args
    log::info "setting focuser to [join $positions /]."
    client::request "instrument" "setfocuser $positions"
    client::wait "instrument"
    log::info [format "finished setting focuser after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc focus {range step witness args} {
    set start [utcclock::seconds]
    log::info "focusing with range $range and step $step."
    set projectfullidentifier [server::getdata "projectfullidentifier"]
    set fitsfileprefix "[directories::vartoday]/executor/images/[project::fullidentifier [project]]/[block::identifier [block]]/[visit::identifier [visit]]/"
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
    set fitsfileprefix "[directories::vartoday]/executor/images/[project::fullidentifier [project]]/[block::identifier [block]]/[visit::identifier [visit]]/"
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
      log::info "solved $detector position is [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox."
      lappend alphalist $alpha
      lappend deltalist $delta
    }
    set alpha [astrometry::meanalpha $alphalist $deltalist]
    set delta [astrometry::meandelta $alphalist $deltalist]
    log::info "solved mean position is [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox."
    client::request "telescope" "correct $alpha $delta $equinox"
    client::wait "telescope"
    log::info [format "finished attempting to correct the pointing model after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  variable exposure

  ######################################################################
  
  proc updatefiledata {} {
    server::setdata "filetype" [filetype]
    server::setdata "filename" [file tail [filename]]
    server::setdata "timestamp" [utcclock::combinedformat]
  }
  
  proc updateprojectdata {} {
    if {[string equal [project] ""]} {
      server::setdata "projectfullidentifier" ""
      server::setdata "projectidentifier"     ""
      server::setdata "projectname"           ""
    } else {
      server::setdata "projectfullidentifier" [project::fullidentifier [project]]
      server::setdata "projectidentifier"     [project::identifier [project]]
      server::setdata "projectname"           [project::name [project]]
    }
  }

  proc updateblockdata {} {
    if {[string equal [block] ""]} {
      server::setdata "blockidentifier"   ""
      server::setdata "blockname"         ""
    } else {
      server::setdata "blockidentifier"   [block::identifier [block]]
      server::setdata "blockname"         [block::name [block]]
    }
    server::setdata "timestamp" [utcclock::combinedformat]
  }

  proc updatevisitdata {} {
    if {[string equal [visit] ""]} {
      server::setdata "visitidentifier"   ""
      server::setdata "visitname"         ""
      server::setdata "visitcommand"      ""
    } else {
      server::setdata "visitidentifier"   [visit::identifier [visit]]
      server::setdata "visitname"         [visit::name [visit]]
      server::setdata "visitcommand"      [visit::command [visit]]
    }
    server::setdata "timestamp" [utcclock::combinedformat]
  }
  
  proc updatealertdata {} {
    if {[string equal "" [executor::alert]]} {
      server::setdata "alertname"           ""
      server::setdata "alertorigin"         ""
      server::setdata "alertidentifier"     ""
      server::setdata "alerttype"           ""
      server::setdata "alerteventtimestamp" ""
      server::setdata "alertalerttimestamp" ""
      server::setdata "alertalpha"          ""
      server::setdata "alertdelta"          ""
      server::setdata "alertequinox"        ""
      server::setdata "alertuncertainty"    ""
    } else {    
      server::setdata "alertname"           [alert::name [executor::alert]]
      server::setdata "alertorigin"         [alert::origin [executor::alert]]
      server::setdata "alertidentifier"     [alert::identifier [executor::alert]]
      server::setdata "alerttype"           [alert::type [executor::alert]]
      server::setdata "alerteventtimestamp" [alert::eventtimestamp [executor::alert]]
      server::setdata "alertalerttimestamp" [alert::alerttimestamp [executor::alert]]
      server::setdata "alertalpha"          [astrometry::parsealpha   [alert::alpha [executor::alert]]]
      server::setdata "alertdelta"          [astrometry::parsedelta   [alert::delta [executor::alert]]]
      server::setdata "alertequinox"        [astrometry::parseequinox [alert::equinox [executor::alert]]]
      server::setdata "alertuncertainty"    [astrometry::parseoffset  [alert::uncertainty [executor::alert]]]
    }
    server::setdata "timestamp" [utcclock::combinedformat]
  }

  proc updatecompleteddata {completed} {
    server::setdata "completed" $completed
  }
  
  proc cleardata {} {
    set project ""
    set block ""
    set alert ""
    set visit ""
    updateprojectdata
    updateblockdata
    updatealertdata
    updatevisitdata    
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
    set ha    [visit::observedha [visit]]
    set delta [visit::observeddelta [visit]]
    log::info [format \
      "moving to %s %s." \
      [astrometry::formatha $ha] \
      [astrometry::formatdelta $delta] \
    ]
    client::request "telescope" "move $ha $delta"
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
    client::request "selector" "setfocused"
    log::info [format "finished finished setting focused timestamp after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setunfocused {} {
    set start [utcclock::seconds]
    log::info "unsetting focused timestamp."
    client::request "selector" "setunfocused"
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

  proc isevening {} {
    client::update "sun"
    set sunha [client::getdata "sun" "observedha"]    
    if {$sunha > 0} {
      return true
    } else {
      return false
    }
  }

  proc isunparked {} {
    client::update "mount"
    set unparked [client::getdata "mount" "unparked"]
    return $unparked
  }

  ######################################################################

  proc executeactivitycommand {filetype filename} {
  
    setfiles $filetype $filename

    log::info "executing [filetype] file \"[file tail [filename]]\"."

    set blockstart [utcclock::seconds]

    updatecompleteddata false
    updatefiledata

    set visitcommandsfile [file join [directories::etc] "visitcommands.tcl"]
    if {[catch {
      source $visitcommandsfile
    } result]} {
      error "while loading visit commands file: $result"
    }

    variable exposure
    set exposure 0
    
    if {[string equal "alert" [filetype]]} {
      if {[catch {
        set block [alert::alerttoblock [alert::readalertfile [filename]]]
      } message]} {
        updatecompleteddata false
        log::error "while reading alert file \"[file tail [filename]]\": $message"
        log::info "deleting alert file \"[file tail [filename]]\"."
        file delete -force [filename]
        return
      }
    } else {
      if {[catch {
        set block [block::readfile [filename]]
      } message]} {
        updatecompleteddata false
        log::error "while reading block file \"[file tail [filename]]\": $message"
        log::info "deleting block file \"[file tail [filename]]\"."
        file delete -force [filename]
        return
      }
    }
    
    setblock $block
    setproject [block::project [block]]
    setalert   [block::alert [block]]

    log::summary "executing block [block::identifier [block]] \"[block::name [block]]\" of project [project::identifier [project]] \"[project::name [block::project [block]]]\"."

    foreach visit [block::visits [block]] {

      setvisit $visit

      log::summary "executing visit [visit::identifier [visit]] \"[visit::name [visit]]\"."
      log::info "visit command is \"[visit::command [visit]]\"."
      
      set visitstart [utcclock::seconds]
      if {[catch {
        eval [visit::command [visit]]
      } result]} {
        log::error "while executing visit: $result"
        log::info "aborting block."
        break
      }
      log::summary [format "finished executing visit after %.1f seconds." [utcclock::diff now $visitstart]]

    }
    
    if {![block::persistent [block]]} {
      log::info "deleting [filetype] file \"[file tail [filename]]\"."
      file delete -force [filename]
    }

    updatecompleteddata true

    log::summary [format "finished executing block after %.1f seconds." [utcclock::diff now $blockstart]]
    log::summary [format "finished executing [filetype] file \"[file tail [filename]]\" after %.1f seconds." [utcclock::diff now $blockstart]]
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

  proc recoveractivitycommand {} {
    set start [utcclock::seconds]
    log::summary "recovering."
    foreach server {telescope instrument} {
      catch {client::waituntilstarted $server}
    }
    foreach server {telescope instrument} {
      client::request $server "recover"
    }
    foreach server {telescope instrument} {
      client::wait $server
    }
    log::summary [format "finished recovering after %.1f seconds." [utcclock::diff now $start]]
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
    updatecompleteddata false
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
    updatecompleteddata false
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
    if {[isunparked]} {
      client::request "telescope" "movetoidle"
    }
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
  
  proc recover {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "recovering" "idle" \
      "executor::recoveractivitycommand" 1800e3
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
  
  proc execute {filetype filename} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "executing" "idle" \
      "executor::executeactivitycommand $filetype $filename" 7200e3
  }
  
  proc idle {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "executing" "idle" \
      "executor::idleactivitycommand"
  }
  
  ######################################################################

  set server::datalifeseconds 0

  proc start {} {
    server::setrequestedactivity "started"
    server::setdata "timestamp" [utcclock::combinedformat]
    updateprojectdata
    updateblockdata
    updatealertdata
    updatevisitdata
    updatefiledata
    updatecompleteddata false
    server::setactivity [server::getrequestedactivity]
    server::setstatus "ok"
  }

}
