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

set executortype [config::getvalue "executor" "type"]
switch -exact $executortype {
  "coatli" {
    package require "executorcoatli"
  }
  "colibri" {
    package require "executorcolibri"
  }
  "ddoti" {
    package require "executorddoti"
  }
  default {
    error "invalid executor type \"$executortype\"."
  }
}

config::setdefaultvalue "executor" "instruments"       {"instrument"}
config::setdefaultvalue "executor" "initialinstrument" "instrument"

package provide "executor" 0.0

namespace eval "executor" {

  ######################################################################
  
  variable instruments [config::getvalue "executor" "instruments"]
  server::setdata "instruments" $instruments

  variable initialinstrument [config::getvalue "executor" "initialinstrument"]

  variable instrument $initialinstrument
  server::setdata "instrument" $instrument
  variable detectors [config::getvalue $instrument "detectors"]
  variable pointingdetectors [config::getvalue $instrument "pointingdetectors"]

  variable maxcorrection [astrometry::parseangle [config::getvalue "mount" "maxcorrection"]]

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

  proc sendchat {category message} {
    log::info "sending $category message \"$message\"."
    if {[catch {
      exec "[directories::prefix]/bin/tcs" "sendchat" "$category" "$message" &
    }]} {
      log::warning "unable to send $category message \"$message\"."
    }
  }
  
  ######################################################################

  variable trackstart ""
  
  proc track {{alphaoffset 0} {deltaoffset 0} {aperture "default"}} {
    waitfortelescope
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
    waitfortelescope
    variable trackstart
    set trackstart [utcclock::seconds]
    astrometry::parseoffset $alphaoffset
    astrometry::parseoffset $deltaoffset
    log::info [format \
      "offsetting %s E and %s N at aperture %s." \
      [astrometry::formatoffset $alphaoffset] \
      [astrometry::formatoffset $deltaoffset] \
      $aperture \
    ]
    client::request "telescope" "offset $alphaoffset $deltaoffset $aperture"
  } 
  
  proc waitfortelescope {} {
    set start [utcclock::seconds]
    log::info "waiting for telescope."
    client::wait "telescope"
    log::info [format "finished waiting for telescope after %.1f seconds." [utcclock::diff now $start]]
    variable trackstart
    if {![string equal "" $trackstart]} {
      log::info [format "tracking after %.1f seconds." [utcclock::diff now $trackstart]]
      set trackstart ""
    }
  }

  ######################################################################
  
  proc movesecondarytoinitial {} {
    waitfortelescope
    log::info "moving secondary to the initial position."
    client::request "telescope" "movesecondary initialz0"
  }

  proc movesecondary {z} {
    waitfortelescope
    log::info "moving secondary to $z."
    client::request "telescope" "movesecondary $z"
  }

  proc focussecondary {detector exposuretime {z0range 300} {z0step 20} {witness true} {initial false}} {
    set start [utcclock::seconds]
    log::info "focusing secondary on $detector with range $z0range and step $z0step."
    if {$initial} {
      movesecondarytoinitial
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
        movesecondary $z0
        eval expose "focus" $exposuretimes
        eval analyze $analyzetypes
        client::update $detector
        set fitsfilename [file tail [client::getdata $detector "fitsfilename"]]
        set fwhm         [client::getdata $detector "fwhm"]
        set fwhmpixels   [client::getdata $detector "fwhmpixels"]
        set binning      [client::getdata $detector "detectorbinning"]
        set filter       [client::getdata $detector "filter"]
        if {[string equal "$fwhm" ""]} {
          log::info [format "$fitsfilename: FWHM is unknown with binning $binning in filter $filter at secondary position $z0 in %.0f seconds." $exposuretime]
        } else {
          log::info [format \
            "$fitsfilename: FWHM is %.2fas (%.2f pixels with binning $binning) in filter $filter at secondary position $z0 in $exposuretime seconds." \
              [astrometry::radtoarcsec $fwhm] $fwhmpixels \
          ]
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
    movesecondary $z0
    waitfortelescope
    if {$witness} {
      set i 0
      set success true
      while {$i < 3} {
        incr i
        set timestamp [utcclock::combinedformat now]
        eval expose "focus" [lrepeat [llength $detectors] $exposuretime]
        eval analyze [lrepeat [llength $detectors] "fwhmwitness"]
        client::update $detector
        set fitsfilename [file tail [client::getdata $detector "fitsfilename"]]
        set fwhm         [client::getdata $detector "fwhm"]
        set fwhmpixels   [client::getdata $detector "fwhmpixels"]
        set binning      [client::getdata $detector "detectorbinning"]
        set filter       [client::getdata $detector "filter"]
        if {[string equal "$fwhm" ""]} {
          log::summary [format "$fitsfilename: $detector witness FWHM is unknown (with binning $binning) in filter $filter at secondary position $z0 in $exposuretime seconds."]
          set success false
        } else {
          log::summary [format \
            "$fitsfilename: $detector witness FWHM is %.2fas (%.2f pixels with binning $binning) in filter $filter at secondary position $z0 in $exposuretime seconds." \
            [astrometry::radtoarcsec $fwhm] $fwhmpixels \
          ]
          log::putmessage $timestamp "focus-$detector" "keys" "timestamp\tfwhm\tfilter\tbinning"
          log::putmessage $timestamp "focus-$detector" "data" "$timestamp\t[astrometry::radtoarcsec $fwhm]\t$filter\t$binning"
          if {[catch {
            client::update "secondary"
            set temperature [client::getdata "secondary" "temperature"]
            set z [client::getdata "secondary" "z"]
            set dztemperature [client::getdata "secondary" "dztemperature"]
            set dzposition [client::getdata "secondary" "dzposition"]
            set channel [::open [file join [directories::vartoday] "focus.csv"] "a"]
            puts $channel [format \
              "\"%s\",%.2f,%d,%.1f,\"%s\",%.2f,%.0f,%.0f,%.0f" \
              $fitsfilename $fwhm $binning $exposuretime $filter $temperature $z $dztemperature $dzposition \
            ]
            ::close $channel
          } message]} {
            log::warning "unable to write focus.csv file: $message"
          }
        }
      }
      if {$success} {
        log::summary "focusing succeeded."
        setfocused
      } else {
        log::warning "focusing failed."
        setunfocused
      }
    }
    log::info [format "finished focusing secondary after %.1f seconds." [utcclock::diff now $start]]
  }
  
  ######################################################################

  variable lastreadmodes ""
  variable lastwindows ""
  variable lastbinnings ""
  variable lastfilterpositions ""

  proc waitforinstrument {} {
    variable instrument
    set start [utcclock::seconds]
    log::info "waiting for instrument."
    client::wait $instrument
    log::info [format "finished waiting for instrument after %.1f seconds." [utcclock::diff now $start]]
  }

  proc expose {type args} {
    variable instrument
    waitfortelescope
    waitforinstrument
    set start [utcclock::seconds]
    variable exposure
    set exposuretimes $args
    log::info "exposing $type image for [join $exposuretimes /] seconds (exposure $exposure)."
    set projectfullidentifier [server::getdata "projectfullidentifier"]
    set fitsfiledir "[directories::vartoday]/executor/images/[project::fullidentifier [project]]/[block::identifier [block]]/[visit::identifier [visit]]"
    file mkdir $fitsfiledir
    client::request $instrument "exposefull $type $fitsfiledir now $exposuretimes"
    client::waituntilnot $instrument "exposing"
    log::info [format "finished exposing $type image (exposure $exposure) after %.1f seconds." [utcclock::diff now $start]]
    set exposure [expr {$exposure + 1}]
  }
  
  proc exposeafter {type starttime args} {
    variable instrument
    waitfortelescope
    waitforinstrument
    set start [utcclock::seconds]
    variable exposure
    set exposuretimes $args
    log::info "exposing $type image for [join $exposuretimes /] seconds (exposure $exposure) after waiting until [utcclock::format $starttime]."
    set projectfullidentifier [server::getdata "projectfullidentifier"]
    set fitsfiledir "[directories::vartoday]/executor/images/[project::fullidentifier [project]]/[block::identifier [block]]/[visit::identifier [visit]]"
    file mkdir $fitsfiledir
    client::request $instrument "exposefull $type $fitsfiledir $starttime $exposuretimes"
    client::waituntilnot $instrument "exposing"
    log::info [format "finished exposing $type image (exposure $exposure) after %.1f seconds." [utcclock::diff now $start]]
    set exposure [expr {$exposure + 1}]
  }
  
  proc analyze {args} {
    variable instrument
    waitforinstrument
    set start [utcclock::seconds]
    set types $args
    log::info "analyzing [join $types /]."
    client::request $instrument "analyze $types"
    waitforinstrument
    log::info [format "finished analyzing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc setreadmode {args} {
    variable instrument
    waitforinstrument
    set start [utcclock::seconds]
    set readmodes $args
    log::info "setting read mode to [join $readmodes /]."
    variable lastreadmodes
    if {![string equal $readmodes $lastreadmodes]} {
      client::request $instrument "setreadmode $readmodes"
    }
    log::info [format "finished setting read modes after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setwindow {args} {
    variable instrument
    waitforinstrument
    set start [utcclock::seconds]
    set windows $args
    log::info "setting window to [join $windows /]."
    variable lastwindows
    if {![string equal $windows $lastwindows]} {
      client::request $instrument "setwindow $windows"
    }
    log::info [format "finished setting window after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setbinning {args} {
    variable instrument
    waitforinstrument
    set start [utcclock::seconds]
    set binnings $args
    log::info "setting binning to [join $binnings /]."
    variable lastbinnings
    if {![string equal $binnings $lastbinnings]} {
      client::request $instrument "setbinning $binnings"
    }
    log::info [format "finished setting binning after %.1f seconds." [utcclock::diff now $start]]
  }

  proc movefilterwheel {args} {
    variable instrument
    waitforinstrument
    set start [utcclock::seconds]
    set filterpositions $args
    log::info "moving filter wheel to [join $filterpositions /]."
    variable lastfilterpositions
    if {![string equal $filterpositions $lastfilterpositions]} {
      client::request $instrument "movefilterwheel $filterpositions"
      if {[server::withserver "secondary"]} {
        waitfortelescope
        client::request "secondary"  "moveforfilter [lindex $filterpositions 0]"
        client::wait "secondary"
      }
    }
    log::info [format "finished moving filter wheel after %.1f seconds." [utcclock::diff now $start]]
  }

  proc movefocuser {args} {
    variable instrument
    waitforinstrument
    set start [utcclock::seconds]
    set positions $args
    log::info "moving focuser to [join $positions /]."
    client::request $instrument "movefocuser $positions"
    log::info [format "finished moving focuser after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc setfocuser {args} {
    variable instrument
    waitforinstrument
    set start [utcclock::seconds]
    set positions $args
    log::info "setting focuser to [join $positions /]."
    client::request $instrument "setfocuser $positions"
    log::info [format "finished setting focuser after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc focusinstrument {exposuretime range step {witness false} {initial false}} {
    variable instrument
    waitforinstrument
    set start [utcclock::seconds]
    log::info "focusing with range $range and step $step."
    set projectfullidentifier [server::getdata "projectfullidentifier"]
    set fitsfileprefix "[directories::vartoday]/executor/images/[project::fullidentifier [project]]/[block::identifier [block]]/[visit::identifier [visit]]/"
    log::info "FITS file prefix is $fitsfileprefix."
    file mkdir [file dirname $fitsfileprefix]
    client::request $instrument "focus $fitsfileprefix $range $step $witness $initial $exposuretime"
    client::wait $instrument
    log::info [format "finished focusing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc mapfocus {range step args} {
    variable instrument
    waitforinstrument
    set start [utcclock::seconds]
    log::info "mapping focus with range $range and step $step."
    set projectfullidentifier [server::getdata "projectfullidentifier"]
    set fitsfileprefix "[directories::vartoday]/executor/images/[project::fullidentifier [project]]/[block::identifier [block]]/[visit::identifier [visit]]/"
    log::info "FITS file prefix is $fitsfileprefix."
    file mkdir [file dirname $fitsfileprefix]
    client::request $instrument "mapfocus $fitsfileprefix $range $step $args"
    client::wait $instrument
    log::info [format "finished mapping focus after %.1f seconds." [utcclock::diff now $start]]
  }

  proc setinstrument {newinstrument} {

    variable instrument

    set start [utcclock::seconds]
    log::summary "setting instrument to $newinstrument."

    variable instruments
    if {[lsearch -exact $instruments $newinstrument] == -1} {
      error "invalid instrument \"$newinstrument\"."
    }
  
    recoverifnecessary true
    foreach server [list telescope $instrument] {
      client::request $server "stop"
    }
    foreach server [list telescope $instrument] {
      client::wait $server
    }

    variable detectors
    variable pointingdetectors

    set instrument $newinstrument
    server::setdata "instrument" $instrument
    set detectors [config::getvalue $instrument "detectors"]
    set pointingdetectors [config::getvalue $instrument "pointingdetectors"]

    recoverifnecessary true
    client::request telescope "setport $instrument"
    client::request $instrument "stop"
    client::wait telescope
    client::wait $instrument

    log::info [format "finished setting instrument to $newinstrument after %.1f seconds." [utcclock::diff now $start]]
  
  }

  ######################################################################

  proc correctpointing {exposuretime} {
    variable instrument
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
      eval expose "astrometry" $exposuretimes
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
        client::resetifnecessary $instrument
        client::wait "telescope"
        client::wait $instrument
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

  proc addtopointingmodel {exposuretime} {
    variable instrument
    set start [utcclock::seconds]
    variable pointingdetectors
    log::info "attempting to add to the pointing model using $pointingdetectors."
    variable detectors
    set exposuretimes [lrepeat [llength $detectors] "none"]
    set analyzetypes  [lrepeat [llength $detectors] "none"]
    foreach detector $pointingdetectors {
      lset exposuretimes [lsearch -exact $detectors $detector] $exposuretime
      lset analyzetypes  [lsearch -exact $detectors $detector] "astrometry"
    } 
    if {$exposuretime != 0} {
      eval expose "astrometry" $exposuretimes
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
        log::warning "$detector pointing did not solve: unable to add to the pointing model."
        client::resetifnecessary "telescope"
        client::resetifnecessary $instrument
        client::wait "telescope"
        client::wait $instrument
        log::info [format "finished attempting to add to the pointing model after %.1f seconds." [utcclock::diff now $start]]
        return
      }
      log::info "solved $detector position is [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox."
      lappend alphalist $alpha
      lappend deltalist $delta
    }
    set alpha [astrometry::meanalpha $alphalist $deltalist]
    set delta [astrometry::meandelta $alphalist $deltalist]
    log::info "solved mean position is [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox."
    client::request "telescope" "addtopointingmodel $alpha $delta $equinox"
    client::wait "telescope"
    log::info [format "finished attempting to add to the pointing model after %.1f seconds." [utcclock::diff now $start]]
  }

  proc center {exposuretime {detector "C0"}} {
    variable instrument
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
      eval expose "astrometry" $exposuretimes
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
        client::resetifnecessary $instrument
        client::wait "telescope"
        client::wait $instrument
        log::info [format "finished attempting to correct the pointing model after %.1f seconds." [utcclock::diff now $start]]
        return
      }
      log::info "solved $detector position is [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox."
      lappend alphalist $alpha
      lappend deltalist $delta
    }
    set truealpha [astrometry::meanalpha $alphalist $deltalist]
    set truedelta [astrometry::meandelta $alphalist $deltalist]
    log::info "solved mean position is [astrometry::formatalpha $truealpha] [astrometry::formatdelta $truedelta] $equinox."
    
    client::update "target"
    set targetalpha   [client::getdata "target" standardalpha]
    set targetdelta   [client::getdata "target" standarddelta]
    set targetequinox [client::getdata "target" standardequinox]
    log::info "target position is [astrometry::formatalpha $targetalpha] [astrometry::formatdelta $targetdelta] $equinox."
    
    set d [astrometry::distance $targetalpha $targetdelta $truealpha $truedelta]
    log::info [format "correction is %s." [astrometry::formatdistance $d]]

    set dalpha [astrometry::foldradsymmetric [expr {$targetalpha - $truealpha}]]
    set ddelta [astrometry::foldradsymmetric [expr {$targetdelta - $truedelta}]]
    set alphaoffset [expr {$dalpha * cos($truedelta)}]
    set deltaoffset $ddelta
    log::info [format "correction is %s E and %s N." [astrometry::formatoffset $alphaoffset] [astrometry::formatoffset $deltaoffset]]

    variable maxcorrection
    if {$d >= $maxcorrection} {

      log::warning [format "ignoring correction: the correction distance of %s is larger than the maximum allowed of %s." [astrometry::formatdistance $d] [astrometry::formatdistance $maxcorrection]]

    } else {

      variable trackstart
      set trackstart [utcclock::seconds]
      client::update "target"
      set aperture [client::getdata "target" "requestedaperture"]
      log::info [format \
        "offsetting %s E and %s N at aperture %s." \
        [astrometry::formatoffset $alphaoffset] \
        [astrometry::formatoffset $deltaoffset] \
        $aperture \
      ]
      client::request "telescope" "offset $alphaoffset $deltaoffset $aperture"
      
    }
  }
  

  proc centerstar {exposuretime {detector "C0"}} {
    variable instrument
    set start [utcclock::seconds]
    log::info "attempting to center the brightest source in the field of $detector."
    variable detectors
    set exposuretimes [lrepeat [llength $detectors] "none"]
    set analyzetypes  [lrepeat [llength $detectors] "none"]
    lset exposuretimes [lsearch -exact $detectors $detector] $exposuretime
    lset analyzetypes  [lsearch -exact $detectors $detector] "center"
    if {$exposuretime != 0} {
      eval expose "astrometry" $exposuretimes
    }
    eval analyze $analyzetypes
    client::update $detector
    set alphaoffset [client::getdata $detector "alphaoffset"]
    set deltaoffset [client::getdata $detector "deltaoffset"]
    if {[string equal $alphaoffset ""]} {
      log::warning "unable to center the brightest source."
      client::resetifnecessary $instrument
      client::wait $instrument
      log::info [format "finished attempting to center the brightest source in the field of $detector after %.1f seconds." [utcclock::diff now $start]]
      return
    }
    log::info [format \
      "offset to brightest source is %s E and %s N." \
      [astrometry::formatoffset $alphaoffset] [astrometry::formatoffset $deltaoffset] \
    ]
    variable trackstart
    set trackstart [utcclock::seconds]
    client::update "target"
    set aperture [client::getdata "target" "requestedaperture"]
    log::info [format \
      "offsetting %s E and %s N at aperture %s." \
      [astrometry::formatoffset $alphaoffset] \
      [astrometry::formatoffset $deltaoffset] \
      $aperture \
    ]
    client::request "telescope" "offset $alphaoffset $deltaoffset $aperture"
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
    server::setdata "blocktimestamp" [utcclock::combinedformat]
    server::setdata "timestamp"      [utcclock::combinedformat]
  }

  proc updatevisitdata {} {
    if {[string equal [visit] ""]} {
      server::setdata "visitidentifier"   ""
      server::setdata "visitname"         ""
      server::setdata "visitcommand"      ""
      server::setdata "visittasks"        ""
    } else {
      server::setdata "visitidentifier"   [visit::identifier [visit]]
      server::setdata "visitname"         [visit::name [visit]]
      server::setdata "visitcommand"      [visit::command [visit]]
      server::setdata "visittasks"        [visit::tasks [visit]]
    }
    server::setdata "visittimestamp" [utcclock::combinedformat]
    server::setdata "timestamp"      [utcclock::combinedformat]
  }
  
  proc updatealertdata {} {
    if {[string equal "" [executor::alert]]} {
      server::setdata "alertname"            ""
      server::setdata "alertorigin"          ""
      server::setdata "alertidentifier"      ""
      server::setdata "alertswiftidentifier" ""
      server::setdata "alertfermiidentifier" ""
      server::setdata "alertlvcidentifier"   ""
      server::setdata "alertsvomidentifier"  ""
      server::setdata "alerttype"            ""
      server::setdata "alerteventtimestamp"  ""
      server::setdata "alertalerttimestamp"  ""
      server::setdata "alertalpha"           ""
      server::setdata "alertdelta"           ""
      server::setdata "alertequinox"         ""
      server::setdata "alertuncertainty"     ""
      server::setdata "alertpriority"        ""
    } else {
      server::setdata "alertname"            [alert::name [executor::alert]]
      server::setdata "alertorigin"          [alert::origin [executor::alert]]
      server::setdata "alertidentifier"      [alert::identifier [executor::alert]]
      server::setdata "alertswiftidentifier" [alert::originidentifier [executor::alert] "swift"]
      server::setdata "alertfermiidentifier" [alert::originidentifier [executor::alert] "fermi"]
      server::setdata "alertlvcidentifier"   [alert::originidentifier [executor::alert] "lvc"  ]
      server::setdata "alertsvomidentifier"  [alert::originidentifier [executor::alert] "svom" ]
      server::setdata "alerttype"            [alert::type [executor::alert]]
      server::setdata "alerteventtimestamp"  [alert::eventtimestamp [executor::alert]]
      server::setdata "alertalerttimestamp"  [alert::alerttimestamp [executor::alert]]
      server::setdata "alertalpha"           [astrometry::parsealpha   [alert::alpha [executor::alert]]]
      server::setdata "alertdelta"           [astrometry::parsedelta   [alert::delta [executor::alert]]]
      server::setdata "alertequinox"         [astrometry::parseequinox [alert::equinox [executor::alert]]]
      server::setdata "alertuncertainty"     [astrometry::parseoffset  [alert::uncertainty [executor::alert]]]
      server::setdata "alertpriority"        [alert::priority [executor::alert]]
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

  ######################################################################
  
  variable initialactivity
  
  proc setinitialactivity {} {
    variable initialactivity
    set initialactivity [server::getactivity]
  }
  
  proc recoverifnecessary {recovertoopen} {

    variable instrument

    variable initialactivity
    if {
      ![string equal $initialactivity "error"] &&
      ![string equal $initialactivity "started"]
    } {
      log::info "recovery is not necessary."
      return
    }

    set start [utcclock::seconds]
    log::summary "recovering."
    set pendingactivity [server::getactivity]

    if {[catch {
      set start [utcclock::seconds]
      log::summary [format "finished resetting after %.1f seconds." [utcclock::diff now $start]]
      server::setactivity "recovering"
      foreach server [list telescope $instrument] {
        client::request $server "recover"
        client::wait $server
      }
    }]} {
      error "unable to recover."
    }

    log::summary [format "finished recovering after %.1f seconds." [utcclock::diff now $start]]

    if {$recovertoopen} {
    set start [utcclock::seconds]
      log::summary "opening after recovery."
      server::setactivity "opening"
      if {[catch {
        foreach server [list $instrument telescope] {
          client::request $server "open"
          client::wait $server
        }
      }]} {
        error "unable to open."
      }
      log::summary [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
    }

    server::setactivity $pendingactivity

  }

  ######################################################################

  proc stopactivitycommand {} {
    variable instrument
    set start [utcclock::seconds]
    log::summary "stopping."
    foreach server [list telescope $instrument] {
      client::request $server "stop"
    }
    foreach server [list telescope $instrument] {
      client::wait $server
    }
    log::summary [format "finished stopping after %.1f seconds." [utcclock::diff now $start]]
  }

  proc interruptactivitycommand {} {
    variable instrument
    set start [utcclock::seconds]
    log::summary "interrupting."
    foreach server [list telescope $instrument] {
      client::request $server "stop"
    }
    sendchat "observations" "interrupting."
    foreach server [list telescope $instrument] {
      client::wait $server
    }
    log::summary [format "finished interrupting after %.1f seconds." [utcclock::diff now $start]]
  }

  proc emergencystopactivitycommand {} {
    variable instrument
    set start [utcclock::seconds]
    log::summary "emergency stopping."
    foreach server {telescope} {
      client::request $server "emergencystop"
    }
    foreach server {telescope} {
      client::wait $server
    }
    log::summary [format "finished emergency stopping after %.1f seconds." [utcclock::diff now $start]]
  }
  

  proc executeactivitycommand {filetype filename} {
  
    variable instrument

    recoverifnecessary true

    set blockstart [utcclock::seconds]

    setfiles $filetype $filename

    log::info "executing [filetype] file \"[file tail [filename]]\"."
    

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

    if {[string equal "alert" [filetype]]} {
      log::summary "executing alert block [block::identifier [block]] \"[block::name [block]]\"\"."
      sendchat "observations" "executing alert block [block::identifier [block]] \"[block::name [block]]\"."
    } else {
      log::summary "executing block [block::identifier [block]] \"[block::name [block]]\" of project [project::identifier [project]] \"[project::name [block::project [block]]]\"."
      sendchat "observations" "executing block [block::identifier [block]] \"[block::name [block]]\" of project [project::identifier [project]] \"[project::name [block::project [block]]]\"."
    }

    foreach visit [block::visits [block]] {

      setvisit $visit

      log::summary "executing visit [visit::identifier [visit]] \"[visit::name [visit]]\"."
      log::info "visit command is \"[visit::command [visit]]\"."
      
      set visitstart [utcclock::seconds]
      if {[catch {
        client::request $instrument "stop"
        eval [visit::command [visit]]
        client::wait $instrument        
      } result]} {
        log::error "while executing visit: $result"
        log::summary "aborting block."
        log::summary "recovering."
        foreach server [list telescope $instrument] {
          client::request $server "recover"
          client::wait $server
        }
        foreach server [list $instrument telescope] {
          client::request $server "open"
          client::wait $server
        }
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
    if {[string equal "alert" [filetype]]} {
      sendchat "observations" "finished executing alert block [block::identifier [block]] \"[block::name [block]]\"."
    } else {
      sendchat "observations" "finished executing block [block::identifier [block]] \"[block::name [block]]\" of project [project::identifier [project]] \"[project::name [block::project [block]]]\"."
    }
  }
  
  proc resetactivitycommand {} {
    variable instrument
    set start [utcclock::seconds]
    log::summary "resetting."
    foreach server [list telescope $instrument] {
      catch {client::waituntilstarted $server}
      client::request $server "reset"
      client::wait $server
    }
    log::summary [format "finished resetting after %.1f seconds." [utcclock::diff now $start]]
  }

  proc recovertoclosedactivitycommand {} {
    variable instrument
    set start [utcclock::seconds]
    log::summary "recovering to closed."
    catch {client::waituntilstarted "watchdog"}
    client::request "watchdog" "enable"
    client::wait "watchdog"
    foreach server [list telescope $instrument] {
      catch {client::waituntilstarted $server}
      client::request $server "recover"
      client::wait $server
    }
    log::summary [format "finished recovering to closed after %.1f seconds." [utcclock::diff now $start]]
  }

  proc recovertoopenactivitycommand {} {
    variable instrument
    set start [utcclock::seconds]
    log::summary "recovering to open."
    catch {client::waituntilstarted "watchdog"}
    client::request "watchdog" "enable"
    client::wait "watchdog"
    foreach server [list telescope $instrument] {
      catch {client::waituntilstarted $server}
      client::request $server "recover"
      client::wait $server
    }
    log::summary "opening after recovery."
    foreach server [list $instrument telescope] {
      catch {client::waituntilstarted $server}
      client::request $server "open"
      client::wait $server
    }
    log::summary [format "finished recovering to open after %.1f seconds." [utcclock::diff now $start]]
  }

  proc executecommandactivitycommand {command} {

    set start [utcclock::seconds]
    log::summary "executing command \"$command\"."

    eval $command

    log::summary [format "finished executing command after %.1f seconds." [utcclock::diff now $start]]
    
  }

  proc initializeactivitycommand {} {
    variable instrument
    variable initialinstrument

    set start [utcclock::seconds]
    log::summary "initializing."
    catch {client::waituntilstarted "watchdog"}
    client::request "watchdog" "enable"
    client::wait "watchdog"


    catch {client::waituntilstarted telescope}
    log::summary "initializing telescope."
    client::request telescope "initialize"
    client::wait telescope
  
    variable lastreadmodes
    variable lastwindows
    variable lastbinnings
    variable lastfilterpositions
    set lastreadmodes ""
    set lastwindows ""
    set lastbinnings ""
    set lastfilterpositions ""

    variable detectors
    variable pointingdetectors
      
    variable instruments
    foreach instrument $instruments {

      log::summary "initializing $instrument."

      server::setdata "instrument" $instrument
      set detectors [config::getvalue $instrument "detectors"]
      set pointingdetectors [config::getvalue $instrument "pointingdetectors"]
    
      catch {client::waituntilstarted $instrument}
      client::request $instrument "initialize"
      client::wait $instrument

    }

    log::summary "setting the instrument to $instrument."
    set "instrument" $initialinstrument

    server::setdata "instrument" $instrument
    set detectors [config::getvalue $instrument "detectors"]
    set pointingdetectors [config::getvalue $instrument "pointingdetectors"]
      
    client::request telescope "setport $instrument"
    client::wait telescope

    log::summary [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc openactivitycommand {} {
    variable instrument
    recoverifnecessary false
    set start [utcclock::seconds]
    log::summary "opening."
    foreach server [list $instrument telescope] {
      catch {client::waituntilstarted $server}
      client::request $server "open"
      client::wait $server
    }
    log::summary [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
  }

  proc opentoventilateactivitycommand {} {
    variable instrument
    recoverifnecessary false
    set start [utcclock::seconds]
    log::summary "opening to ventilate."
    foreach server [list $instrument telescope] {
      catch {client::waituntilstarted $server}
      client::request $server "opentoventilate"
      client::wait $server
    }
    log::summary [format "finished opening to ventilate after %.1f seconds." [utcclock::diff now $start]]
  }

  proc closeactivitycommand {} {
    variable instrument
    recoverifnecessary false
    set start [utcclock::seconds]
    log::summary "closing."
    set error false
    foreach server [list telescope $instrument] {
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
    variable instrument
    set start [utcclock::seconds]
    log::summary "emergency closing."
    foreach server [list telescope $instrument] {
      catch {client::waituntilstarted $server}
      catch {client::request $server "emergencyclose"}
      catch {client::wait $server}
    }
    updatecompleteddata false
    log::summary [format "finished emergency closing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc parkactivitycommand {} {
    variable instrument
    recoverifnecessary false
    set start [utcclock::seconds]
    log::summary "parking."
    foreach server {telescope} {
      catch {client::waituntilstarted $server}
      client::request $server "park"
      client::wait $server
    }
    log::summary [format "finished parking after %.1f seconds." [utcclock::diff now $start]]
  }

  proc unparkactivitycommand {} {
    variable instrument
    recoverifnecessary false
    set start [utcclock::seconds]
    log::summary "unparking."
    foreach server {telescope} {
      catch {client::waituntilstarted $server}
      client::request $server "unpark"
      client::wait $server
    }
    log::summary [format "finished unparking after %.1f seconds." [utcclock::diff now $start]]
  }

  proc idleactivitycommand {} {
    variable instrument
    recoverifnecessary true
    set start [utcclock::seconds]
    log::info "idling."
    foreach server [list telescope $instrument] {
      catch {client::waituntilstarted $server}
      client::request $server "reset"
      client::wait $server
    }
    client::request "telescope" "movetoidle"
    client::request $instrument "idle"
    foreach server [list telescope $instrument] {
      client::wait $server
    }
    log::info [format "finished idling after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  proc stop {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "stopping" [server::getstoppedactivity] \
      "executor::stopactivitycommand"
  }

  proc emergencystop {} {
    # Do not check status or activity.
    server::newactivitycommand "stopping" [server::getstoppedactivity] \
      "executor::emergencystopactivitycommand"
  }

  proc interrupt {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "stopping" [server::getstoppedactivity] \
      "executor::interruptactivitycommand"
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "resetting" [server::getstoppedactivity] \
      "executor::resetactivitycommand"
  }
  
  proc recovertoopen {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "recovering" "idle" \
      "executor::recovertoopenactivitycommand" 1800e3
  }
  
  proc recovertoclosed {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "recovering" "idle" \
      "executor::recovertoclosedactivitycommand" 1800e3
  }
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "initializing" "idle" \
      "executor::initializeactivitycommand" 1800e3
  }
  
  proc open {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "opening" "idle" \
      "executor::openactivitycommand" 900e3
  }
  
  proc opentoventilate {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "opening" "idle" \
      "executor::opentoventilateactivitycommand" 900e3
  }
  
  proc close {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "closing" "idle" \
      "executor::closeactivitycommand" 900e3
  }
  
  proc emergencyclose {} {
    # Do not check status or activity.
    server::newactivitycommand "closing" "idle" \
      "executor::emergencycloseactivitycommand" 900e3
  }
  
  proc park {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "parking" "idle" \
      "executor::parkactivitycommand" 900e3
  }
  
  proc unpark {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "unparking" "idle" \
      "executor::unparkactivitycommand" 900e3
  }
  
  proc execute {filetype filename} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "executing" "idle" \
      "executor::executeactivitycommand $filetype $filename" 7200e3
  }

  proc executecommand {command} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "executing" "idle" \
      "executor::executecommandactivitycommand \"$command\"" 7200e3
  }
  
  proc idle {} {
    server::checkstatus
    server::checkactivityforreset
    setinitialactivity
    server::newactivitycommand "executing" "idle" \
      "executor::idleactivitycommand"
  }
  
  ######################################################################

  set server::datalifeseconds 0

  proc start {} {
    variable instrument
    server::setrequestedactivity "started"
    server::setdata "instrument" $instrument
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
