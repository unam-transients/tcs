########################################################################

# This file is part of the UNAM telescope control system.

# $Idvisit: alertvisit-project-ddotioan 3388 2019-11-01 19:50:09Z Alan $

########################################################################

# Copyright © 2019 Alan M. Watson <alan@astro.unam.mx>
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

proc alertvisit {alertfile} {

  set proposalidentifier [proposal::identifier]
  set visitidentifier    [visit::identifier]

  # First refocus.

  proposal::setidentifier [proposal::makeidentifier 12]
  executor::track
  #executor::setwindow "6kx6k"
  #executor::setbinning 4
  executor::waituntiltracking
  #log::summary "alertvisit: focusing with binning 4."
  #executor::focus 12000 1200 false 1
  log::summary "alertvisit: focusing with binning 1."
  executor::setwindow "1kx1k"
  executor::setbinning 1
  executor::focus 4000 400 true 4
  executor::setfocused
  
  # Then correct pointing

  log::summary "alertvisit: correcting pointing."
  executor::setwindow "6kx6k"
  executor::setbinning 1
  executor::correctpointing 4

  log::summary "alertvisit: observing target."

  proposal::setidentifier $proposalidentifier

  executor::setwindow "default"

  if {[string equal "" [alert::eventtimestamp]]} {
    log::summary [format "alertvisit: no event timestamp."]
  } else {  
    log::summary [format "alertvisit: event timestamp is %s." [utcclock::format [alert::eventtimestamp]]]
  }
  if {[string equal "" [alert::alerttimestamp]]} {
    log::summary [format "alertvisit: no alert timestamp."]
  } else {  
    log::summary [format "alertvisit: alert timestamp is %s." [utcclock::format [alert::alerttimestamp]]]
  }

  set alertdelay [alert::delay]
  log::summary [format "alertvisit: alert delay is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
  if {$alertdelay < 1800} {
    set exposuretime       30
    set exposuresperdither 4
    set binning            1
  } else {
    set exposuretime       60
    set exposuresperdither 2
    set binning            1
  }
  executor::setbinning $binning
  log::summary [format "alertvisit: %.0f second exposures with binning of %d." $exposuretime $binning]
  
  # The decisions below aim to choose the smallest grid that includes
  # the 90% region, assuming each field is 6.6d x 9.8d.
  set uncertainty [astrometry::parsedistance [alert::uncertainty]]
  log::summary [format "alertvisit: uncertainty is %s." [astrometry::formatdistance $uncertainty 2]]
  if {$uncertainty <= [astrometry::parsedistance "1.65d"]} {
    log::summary "alertvisit: grid is 1 × 1 fields."
    set visits [list $visitidentifier 0.0d 0.0d]
    set aperture "W"
  } elseif {$uncertainty <= [astrometry::parsedistance "3.3d"]} {
    log::summary "alertvisit: grid is 1 × 1 fields."
    set visits [list $visitidentifier 0.0d 0.0d]
    set aperture "default"
  } elseif {$uncertainty <= [astrometry::parsedistance "4.9d"]} {
    log::summary "alertvisit: grid is 2 × 1 fields."
    set visits {
      0 -3.3d 0.0d
      1 +3.3d 0.0d
    }
    set aperture "default"
  } elseif {$uncertainty <= [astrometry::parsedistance "6.6d"]} {
    log::summary "alertvisit: grid is 2 × 2 fields."
    set visits {
      0 -3.3d -4.9d
      1 +3.3d -4.9d
      2 -3.3d +4.9d
      3 +3.3d +4.9d
    }
    set aperture "default"
  } else {
    log::summary "alertvisit: grid is 3 × 2 fields."
    set visits {
      0 -6.6d -4.9d
      1  0.0d -4.9d
      2 +6.6d -4.9d
      3 -6.6d +4.9d
      4  0.0d +4.9d
      5 +6.6d +4.9d
    }
    set aperture "default"
  }
  set fields [expr {[llength $visits] / 3}]
  set dithersperfield [expr {12 / $fields}]
  log::summary [format "alertvisit: %d fields with %d dithers per field and %d exposures per dither." $fields $dithersperfield $exposuresperdither]
  log::summary [format "alertvisit: total of %d exposures of %.0f seconds with binning of 1." \
    [expr {$fields * $dithersperfield * $exposuresperdither}] $exposuretime \
  ]

  set lastalpha ""
  set lastdelta ""
  set lastequinox ""
  
  set dither 0
  while {$dither < $dithersperfield} {
    
    set dithereastrange  "0.33d"
    set dithernorthrange "0.33d"
    
    if {[file exists $alertfile]} {
      if {[catch {source $alertfile} message]} {
        log::error "alertvisit: error while loading alert file \"$alertfile\"visit: $message"
        return false
      }
      executor::updatedata
    }

    if {![alert::enabled]} {
      log::summary "alertvisit: the alert is no longer enabled."
      return false
    }

    set alpha   [visit::alpha]
    set delta   [visit::delta]
    set equinox [visit::equinox]
    
    if {![string equal $lastalpha ""] && ($alpha != $lastalpha || $delta != $lastdelta || $equinox != $lastequinox)} {
      log::summary "alertvisit: the coordinates have been updated."
    }
    
    set dithereastoffset  [expr {[astrometry::parsedistance $dithereastrange ] * (rand() - 0.5)}]
    set dithernorthoffset [expr {[astrometry::parsedistance $dithernorthrange] * (rand() - 0.5)}]
    log::info [format "alertvisit: dither %d is %+.2fd east and %+.2fd north." \
      $dither \
      [astrometry::radtodeg $dithereastoffset ] \
      [astrometry::radtodeg $dithernorthoffset] \
    ]      
    
    set lastalpha   $alpha
    set lastdelta   $delta
    set lastequinox $equinox

    foreach {visitidentifier visiteastoffset visitnorthoffset} $visits {
    
      set eastoffset  [expr {[astrometry::parseoffset $visiteastoffset ] + [astrometry::parseoffset $dithereastoffset ]}]
      set northoffset [expr {[astrometry::parseoffset $visitnorthoffset] + [astrometry::parseoffset $dithernorthoffset]}]
      executor::track $eastoffset $northoffset $aperture
      executor::waituntiltracking

      visit::setidentifier $visitidentifier
      set exposure 0
      while {$exposure < $exposuresperdither} {
        executor::expose object $exposuretime
        incr exposure
      }
      
    }

    incr dither
  }

  log::summary "alertvisit: finished."

  return false
}

########################################################################

proc gridvisit {gridrepeats gridpoints exposuresperdither exposuretime} {

  set proposalidentifier [proposal::identifier]

  # First refocus.

  proposal::setidentifier [proposal::makeidentifier 12]
  executor::track
  #executor::setwindow "6kx6k"
  #executor::setbinning 4
  executor::waituntiltracking
  #log::summary "gridvisit: focusing with binning 4."
  #executor::focus 12000 1200 false 1
  log::summary "gridvisit: focusing with binning 1."
  executor::setwindow "1kx1k"
  executor::setbinning 1
  executor::focus 4000 400 true 4
  executor::setfocused
  
  # Then correct pointing.

  log::summary "gridvisit: correcting pointing."
  executor::setwindow "6kx6k"
  executor::setbinning 1
  executor::correctpointing 4

  # Then observe the target.
  
  set binning 1

  log::summary "gridvisit: observing target."

  proposal::setidentifier $proposalidentifier

  executor::setwindow "default"

  executor::setbinning $binning
  log::summary [format "gridvisit: %d × %.0f second exposures with binning of %d." \
    [expr {$gridrepeats * $gridpoints * $exposuresperdither}] $exposuretime $binning \
  ]
  log::summary [format "gridvisit: %d grid repeats." $gridrepeats]
  log::summary [format "gridvisit: %d dithers per repeat." $gridpoints]
  log::summary [format "gridvisit: %d exposures per dither." $exposuresperdither]

  switch $gridpoints {
    4 {
      set dithers {
        +0.1d +0.1d
        -0.1d -0.1d
        +0.1d -0.1d
        -0.1d +0.1d
      }
    }
    5 {
      set dithers {
         0.0d  0.0d
        +0.1d +0.1d
        -0.1d -0.1d
        +0.1d -0.1d
        -0.1d +0.1d
      }
    }
    8 {
      set dithers {
        +0.1d +0.1d
        -0.1d -0.1d
        +0.1d -0.1d
        -0.1d +0.1d
        +0.1d +0.0d
        -0.1d +0.0d
        +0.0d +0.1d
        +0.0d -0.1d
      }
    }
    9 {
      set dithers {
         0.0d  0.0d
        +0.1d +0.1d
        -0.1d -0.1d
        +0.1d -0.1d
        -0.1d +0.1d
        +0.1d +0.0d
        -0.1d +0.0d
        +0.0d +0.1d
        +0.0d -0.1d
      }
    }
  }
  
  executor::track
  executor::waituntiltracking
  
  set gridrepeat 0
  while {$gridrepeat < $gridrepeats} {
    foreach {eastoffset northoffset} $dithers {
      executor::offset $eastoffset $northoffset
      executor::waituntiltracking
      set exposure 0
      while {$exposure < $exposuresperdither} {
        executor::expose object $exposuretime
        incr exposure
      }
    }
    incr gridrepeat
  }

  log::summary "gridvisit: finished."

  return true
}

########################################################################

proc steppedgridvisit {gridrepeats exposuresperdither exposuretime} {

  set proposalidentifier [proposal::identifier]

  # First refocus.

  proposal::setidentifier [proposal::makeidentifier 12]
  executor::track
  #executor::setwindow "6kx6k"
  #executor::setbinning 4
  executor::waituntiltracking
  #log::summary "gridvisit: focusing with binning 4."
  #executor::focus 12000 1200 false 1
  log::summary "steppedgridvisit: focusing with binning 1."
  executor::setwindow "1kx1k"
  executor::setbinning 1
  executor::focus 4000 400 true 4
  executor::setfocused
  
  # Then correct pointing.

  log::summary "steppedgridvisit: correcting pointing."
  executor::setwindow "6kx6k"
  executor::setbinning 1
  executor::correctpointing 4

  # Then observe the target.
  
  log::summary "steppedgridvisit: observing target."

  proposal::setidentifier $proposalidentifier

  set binning 1
  executor::setwindow "default"
  executor::setbinning $binning
  
  log::summary [format "steppedgridvisit: %d × %.0f second exposures with binning of %d." \
    [expr {$gridrepeats * 5 * $exposuresperdither}] $exposuretime $binning \
  ]
  log::summary [format "steppedgridvisit: %d grid repeats." $gridrepeats]
  log::summary [format "steppedgridvisit: %d dithers per repeat." 5]
  log::summary [format "steppedgridvisit: %d exposures per dither." $exposuresperdither]

  set dithers {
    0 +0.0d +0.0d
    1 +3.4d +3.4d
    2 -3.4d -3.4d
    3 +3.4d -3.4d
    4 -3.4d +3.4d
  }
  
  executor::track
  executor::waituntiltracking
  
  set gridrepeat 0
  while {$gridrepeat < $gridrepeats} {
    foreach {visitidentifier eastoffset northoffset} $dithers {
      visit::setidentifier $visitidentifier
      executor::offset $eastoffset $northoffset
      executor::waituntiltracking
      set exposure 0
      while {$exposure < $exposuresperdither} {
        executor::expose object $exposuretime
        incr exposure
      }
    }
    incr gridrepeat
  }

  log::summary "steppedgridvisit: finished."

  return true
}

########################################################################

proc initialfocusvisit {} {

  log::summary "initialfocusvisit: starting."

  executor::track
  executor::setreadmode 16MHz
  executor::setwindow "2kx2k"
  executor::setbinning 4
  log::summary "initialfocusvisit: focusing with binning 4."
  executor::waituntiltracking
  executor::focus 12000 1200 false 1
  executor::setwindow "1kx1k"
  executor::setbinning 1
  log::summary "initialfocusvisit: focusing with binning 1."
  executor::focus 4000 400 true 4
  executor::setfocused

  log::summary "initialfocusvisit: setting focusers to 32767"
  executor::setfocuser 32767

  log::summary "initialfocusvisit: taking tilt witness."
  executor::setwindow "default"
  executor::setbinning 1
  executor::expose object 4

  executor::setwindow "6kx6k"
  executor::setbinning 1

  log::summary "initialfocusvisit: attempting to correct pointing at +1h +45d."
  visit::settargetcoordinates fixed +1h +45d now
  executor::tracktopocentric
  executor::waituntiltracking
  executor::correctpointing 4

  log::summary "initialfocusvisit: attempting to correct pointing at -1h +45d."
  executor::tracktopocentric
  executor::waituntiltracking
  executor::correctpointing 4

  log::summary "initialfocusvisit: finished."

  return false
}

########################################################################

proc focusvisit {} {

  log::summary "focusvisit: starting."

  executor::track
  executor::setreadmode 16MHz
  executor::setwindow "2kx2k"
  executor::setbinning 4
  executor::waituntiltracking
  log::summary "focusvisit: focusing with binning 4."
  executor::focus 12000 1200 false 1
  executor::setwindow "1kx1k"
  executor::setbinning 1
  log::summary "focusvisit: focusing with binning 1."
  executor::focus 4000 400 true 4

  executor::setfocused

  log::summary "focusvisit: finished."
  return false
}

########################################################################

proc fullfocusvisit {} {

  log::summary "fullfocusvisit: starting."

  set exposuretime 5

  executor::track
  executor::setwindow "default"
  executor::setbinning 4
  executor::waituntiltracking

  log::summary "fullfocusvisit: focusing with binning 4."
  executor::focus 20000 1200 false $exposuretime

  log::summary "fullfocusvisit: focusing with binning 2."
  executor::setbinning 2
  executor::focus 10000 600 false $exposuretime

  log::summary "fullfocusvisit: focusing with binning 1."
  executor::setbinning 1
  executor::focus 5000 300 false $exposuretime "-S 2048"
  
  log::summary "fullfocusvisit: finished."

  return true
}

########################################################################

proc focusmapvisit {args} {

  log::summary "focusmapvisit: starting."
  
  set ha    [visit::observedha]
  set delta [visit::observeddelta]

  log::summary "focusmapvisit: focusing first at +1h +30d."
  visit::settargetcoordinates fixed +1h +30d now
  executor::tracktopocentric
  executor::waituntiltracking
  
  set detectors [client::getdata instrument detectors]
  
  foreach detector $detectors {
    client::request $detector "movefocuser 32767"
  } 
  foreach detector $detectors {
    client::wait $detector
  }
  
  executor::setwindow "2kx2k"
  executor::setreadmode 16MHz
  executor::setbinning 4
  executor::focus 12000 1200 false 5
  executor::setwindow "1kx1k"
  executor::setreadmode 16MHz
  executor::setbinning 2
  executor::focus 8000 800 true 5
  executor::setfocused

  log::summary "focusmapvisit: setting focusers to 32767"
  executor::setfocuser 32767

  log::summary "focusmapvisit: focusing at $ha $delta."
  visit::settargetcoordinates fixed $ha $delta now
  executor::tracktopocentric  
  executor::waituntiltracking
  executor::setwindow "2kx2k"
  executor::setreadmode 16MHz
  executor::setbinning 4
  executor::focus 12000 1200 false 5
  executor::setwindow "1kx1k"
  executor::setbinning 2
  executor::focus 8000 800 true 5

  return true
}

########################################################################

proc pointingmapvisit {args} {

  log::summary "pointingmapvisit: starting."
  
  set ha    [visit::ha]
  set delta [visit::delta]

  log::summary "focusmapvisit: focusing at $ha $delta."
  visit::settargetcoordinates fixed $ha $delta now
  executor::tracktopocentric  
  executor::waituntiltracking
  executor::setwindow "6kx6k"
  executor::setbinning 1
  executor::expose object 4

  return true
}

########################################################################

proc twilightflatsvisit {} {
  log::summary "twilightflatsvisit: starting."
  executor::move
  executor::setbinning 1
  executor::setwindow "default"
  set detectors [client::getdata instrument detectors]
  set leveldetector [lindex $detectors 0]
  set minlevel 1000
  set maxlevel 4000
  set filter "w"
  set ngood 0
  set mingoodlevel $maxlevel
  set maxgoodlevel $minlevel
  while {true} {
    executor::expose flat 5
    executor::analyze levels
    set level [executor::exposureaverage $leveldetector]
    log::info [format "twilightflatsvisit: level is %.1f DN in filter $filter." $level]
    if {$level > $maxlevel} {
      log::info "twilightflatsvisit: waiting (too bright)."
      scheduler::after 60000
    } elseif {$level > $minlevel} {
      if {$ngood == 0} {
        log::info "twilightflatsvisit: first good flat with filter $filter."
      }
      scheduler::after 10000
      incr ngood
      set mingoodlevel [expr {min($level,$mingoodlevel)}]
      set maxgoodlevel [expr {max($level,$maxgoodlevel)}]
    } else {
      if {$ngood == 0} {
        log::summary [format "twilightflatsvisit: $ngood good flats with filter $filter."]
      } else {      
        log::summary [format "twilightflatsvisit: $ngood good flats (%.0f to %.0f DN) with filter $filter." $mingoodlevel $maxgoodlevel]
      }
      log::info "twilightflatsvisit: finished with filter $filter (too faint)."
      break
    }
  }
  log::summary "twilightflatsvisit: finished."
  return true
}

########################################################################

proc biasesvisit {} {
  log::summary "biasesvisit: starting."
  executor::move
  executor::setwindow "default"
  set visitidentifier 0
  foreach readmode {16MHz} {
    executor::setreadmode $readmode
    foreach binning {1} {
      visit::setidentifier $visitidentifier
      executor::setbinning $binning
      set i 0
      while {$i < 20} {
        executor::expose bias 0
        executor::analyze levels
        incr i
        scheduler::after 10000
      }
      incr visitidentifier
    }
  }
  log::summary "biasesvisit: finished."
  return true
}

########################################################################

proc darksvisit {} {
  log::summary "darksvisit: starting."
  executor::move
  executor::setwindow "default"
  set visitidentifier 0
  foreach readmode {16MHz} {
    executor::setreadmode $readmode
    foreach binning {1} {
      visit::setidentifier $visitidentifier
      executor::setbinning $binning
      set i 0
      while {$i < 20} {
        executor::expose dark 60
        executor::analyze levels
        incr i
        scheduler::after 10000
      }
      incr visitidentifier
    }
  }
  log::summary "darksvisit: finished."
  return true
}

########################################################################

proc aperturesvisit {} {
  log::summary "aperturesvisit: starting."
  executor::setbinning 4
  executor::setwindow "default"
  executor::track
  executor::waituntiltracking
  log::summary "aperturesvisit: correcting pointing."
  executor::correctpointing 1
  foreach aperture { "default" "W" "NW" "NE" "E" "SE" "SW" } {
    log::summary "aperturesvisit: checking aperture $aperture."
    executor::track 0 0 $aperture
    executor::waituntiltracking
    executor::expose object 1
  }
  log::summary "aperturesvisit: finished."
  return true
}
