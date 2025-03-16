########################################################################

# This file is part of the UNAM telescope control system.

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

proc alertvisit {{filter "w"}} {

  log::summary "alertvisit: starting."
  
  set alpha   [visit::alpha   [executor::visit]]
  set delta   [visit::delta   [executor::visit]]
  set equinox [visit::equinox [executor::visit]]

  log::summary [format "alertvisit: alert coordinates are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]

  log::info "alertvisit: reading alert."

  if {![file exists [executor::filename]]} {
    log::summary "alertvisit: the alert is no longer in the queue."
    return false
  }

  executor::setblock [alert::alerttoblock [alert::readalertfile [executor::filename]]]
  executor::setalert [block::alert [executor::block]]

  if {![alert::enabled [executor::alert]]} {
    log::summary "alertvisit: the alert is no longer enabled."
    return false
  }

  if {[string equal "" [alert::eventtimestamp [executor::alert]]]} {
    log::summary [format "alertvisit: no event timestamp."]
  } else {  
    log::summary [format "alertvisit: event timestamp is %s." [utcclock::format [alert::eventtimestamp [executor::alert]]]]
  }
  if {[string equal "" [alert::alerttimestamp [executor::alert]]]} {
    log::summary [format "alertvisit: no alert timestamp."]
  } else {  
    log::summary [format "alertvisit: alert timestamp is %s." [utcclock::format [alert::alerttimestamp [executor::alert]]]]
  }

  set alertdelay [alert::delay [executor::alert]]
  log::summary [format "alertvisit: alert delay at start of visit is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
  if {$alertdelay < 1800} {
    set exposuretime       30
    set exposuresperdither 4
  } else {
    set exposuretime       60
    set exposuresperdither 2
  }
  log::summary [format "alertvisit: %.0f second exposures." $exposuretime]

  executor::setbinning "default"
  executor::setwindow "default"

  # For the time being, we just use one field.
  # The decisions below aim to choose the smallest grid that includes
  # the 90% region, assuming each field is 6.6d x 9.8d.
  set uncertainty [astrometry::parsedistance [alert::uncertainty [executor::alert]]]
  log::summary [format "alertvisit: uncertainty is %s." [astrometry::formatdistance $uncertainty 2]]
  if {$uncertainty <= [astrometry::parsedistance "1.65d"]} {
    log::summary "alertvisit: grid is 1 × 1 fields."
    set visits {
      0 0.0d 0.0d
    }
    set aperture "W"
  } elseif {$uncertainty <= [astrometry::parsedistance "10d"]} {
    log::summary "alertvisit: grid is 1 × 1 fields."
    set visits {
      0 0.0d 0.0d
    }
    set aperture "default"
  } else {
    log::summary "alertvisit: grid is 2 × 1 fields."
    set visits {
      0 0d -3.3d
      1 0d -3.3d
    }
    set aperture "default"
  }
  set fields [expr {[llength $visits] / 3}]
  set dithersperfield [expr {12 / $fields}]
  log::summary [format "alertvisit: %d fields with %d dithers per field and %d exposures per dither." $fields $dithersperfield $exposuresperdither]
  log::summary [format "alertvisit: total of %d exposures of %.0f seconds with binning of 1." \
    [expr {$fields * $dithersperfield * $exposuresperdither}] $exposuretime \
  ]

  set dither 0
  set first true
  while {$dither < $dithersperfield} {
    
    set dithereastrange  "0.33d"
    set dithernorthrange "0.33d"
    
    set lastalpha   $alpha
    set lastdelta   $delta
    set lastequinox $equinox
  
    if {![file exists [executor::filename]]} {
      log::summary "alertvisit: the alert is no longer in the queue."
      break
    }

    log::info "alertvisit: reading alert."
    executor::setblock [alert::alerttoblock [alert::readalertfile [executor::filename]]]
    executor::setalert [block::alert [executor::block]]

    if {![alert::enabled [executor::alert]]} {
      log::summary "alertvisit: the alert is no longer enabled."
      break
    }

    set alpha   [alert::alpha [executor::alert]]
    set delta   [alert::delta [executor::alert]]
    set equinox [alert::equinox [executor::alert]]
    
    log::summary [format "alertvisit: alert coordinates are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]

    if {$alpha != $lastalpha || $delta != $lastdelta || $equinox != $lastequinox} {
      log::summary "alertvisit: the coordinates have been updated."
      log::summary [format "alertvisit: new alert coordinates are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]
      executor::setvisit [visit::updatevisittargetcoordinates [executor::visit] [visit::makeequatorialtargetcoordinates $alpha $delta $equinox]]
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
    
      executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]

      set eastoffset  [astrometry::parseoffset $visiteastoffset ]
      set northoffset [astrometry::parseoffset $visitnorthoffset]
    
      set eastoffset [correctedeastoffset $eastoffset $northoffset $delta]

      set eastoffset  [expr {$eastoffset  + [astrometry::parseoffset $dithereastoffset ]}]
      set northoffset [expr {$northoffset + [astrometry::parseoffset $dithernorthoffset]}]
            
      executor::track $eastoffset $northoffset $aperture
      executor::waituntiltracking

      set exposure 0
      while {$exposure < $exposuresperdither} {
        if {$first} {
          set alertdelay [alert::delay [executor::alert]]
          log::summary [format "alertvisit: alert delay at start of first exposure is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
          log::summary [format "alertvisit: alert coordinates at start of first exposure are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]
          set first false
        }
        executor::expose object $exposuretime
        incr exposure
      }
      
    }

    incr dither
  }

  set alertdelay [alert::delay [executor::alert]]
  log::summary [format "alertvisit: alert delay after end of last exposure is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
  log::summary [format "alertvisit: alert coordinates after end of last exposure are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]

  log::summary "alertvisit: finished."

  return false
}

proc alertprologvisit {} {

  log::summary "alertprologvisit: starting."

  # First refocus.

  executor::track

  log::summary "alertprologvisit: focusing with binning 8."
  executor::setwindow "2kx2k"
  executor::setbinning 8
  executor::waituntiltracking
  executor::focus 1 2000 250 false true

  log::summary "alertprologvisit: focusing with binning 1."
  executor::setwindow "1kx1k"
  executor::setbinning "default"
  executor::focus 4 600 75 false false

  # Then correct pointing

  log::summary "alertprologvisit: correcting pointing."
  executor::setwindow "6kx6k"
  executor::setbinning "default"
  executor::correctpointing 4
  
  log::summary "alertprologvisit: finished."

}

########################################################################

proc correctedeastoffset {eastoffset northoffset delta} {

  # This procedure corrects the east offset for convergence in alpha
  # away from the equator. The telescope compensates for the convergence at the
  # field center. However, the field edges are significantly north and south of
  # the field center. Therefore, we calculate the delta at the field edge
  # closest to the equator and multiply the nominal east offset by the ratio
  # of the cosine of delta at the field center to the field edge.
  
  set eastoffset  [astrometry::parseoffset $eastoffset ]
  set northoffset [astrometry::parseoffset $northoffset]
  set delta       [astrometry::parsedelta $delta]

  # The half size of the field.
  set halfsizeindelta [astrometry::parsedistance "4.9d"]

  set centerdelta [expr {$delta + $northoffset}]

  # Determine the delta of the field edge closest to the equator.
  set northedgedelta [expr {$centerdelta + $halfsizeindelta}]
  set southedgedelta [expr {$centerdelta - $halfsizeindelta}]
  if {abs($northedgedelta) < abs($southedgedelta)} {
    set edgedelta $northedgedelta
  } else {
    set edgedelta $southedgedelta
  }  
  
  set correctedeastoffset [expr {$eastoffset * cos($centerdelta) / cos($edgedelta)}]

  return $correctedeastoffset
}

########################################################################

proc starevisit {exposures exposuretime {filters "w"}} {

  log::summary "starevisit: starting."

  executor::setwindow "default"
  executor::setbinning "default"
  
  log::summary [format "starevisit: %d × %.0f second exposures." \
    $exposures $exposuretime \
  ]

  executor::track
  executor::waituntiltracking
  
  set exposure 0
  while {$exposure < $exposures} {
    executor::expose object $exposuretime
    incr exposure
  }

  log::summary "starevisit: finished."

  return true
}

########################################################################

proc gridvisit {gridrepeats gridpoints exposuresperdither exposuretime {filters "w"}} {

  log::summary "gridvisit: starting."

  executor::setwindow "default"
  executor::setbinning "default"
  
  log::summary [format "gridvisit: %d × %.0f second exposures." \
    [expr {$gridrepeats * $gridpoints * $exposuresperdither}] $exposuretime \
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

  log::summary "steppedgridvisit: starting."

  variable visit

  executor::setwindow "default"
  executor::setbinning "default"
  
  log::summary [format "steppedgridvisit: %d × %.0f second exposures." \
    [expr {$gridrepeats * 5 * $exposuresperdither}] $exposuretime \
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
      executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
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

proc allskyvisit {} {

  log::summary "allskyvisit: starting."

  executor::setwindow "default"
  executor::setbinning "default"
  
  set eastoffsets  {0.0d 0.85d 1.70d 2.55d}
  set northoffsets {0.0d 0.85d 1.70d 2.55d}

  set gridrepeats 1
  set exposuresperdither 1
  set exposuretime 60
  set gridpoints [expr {[llength $eastoffsets] * [llength $northoffsets]}]  

  log::summary [format "allskyvisit: %d × %.0f second exposures." \
    [expr {$gridrepeats * $gridpoints * $exposuresperdither}] $exposuretime \
  ]
  log::summary [format "allskyvisit: %d grid repeats." $gridrepeats]
  log::summary [format "allskyvisit: %d dithers per repeat." $gridpoints]
  log::summary [format "allskyvisit: %d exposures per dither." $exposuresperdither]

  executor::track
  executor::waituntiltracking
  
  set gridrepeat 0
  while {$gridrepeat < $gridrepeats} {
    foreach eastoffset $eastoffsets {
      foreach northoffset $northoffsets {
        executor::offset $eastoffset $northoffset
        executor::waituntiltracking
        set exposure 0
        while {$exposure < $exposuresperdither} {
          executor::expose object $exposuretime
          incr exposure
        }
      }
    }
    incr gridrepeat
  }

  log::summary "allskyvisit: finished."

  return true
}

proc allskyprologvisit {} {

  log::summary "allskyprologvisit: starting."

  executor::track
  executor::waituntiltracking

  # First refocus.
  
  client::update "target"
  set zenithdistance [client::getdata "target" "observedzenithdistance"]
  if {$zenithdistance > [astrometry::parsedistance "45d"]} {
    log::summary "allskyprologvisit: focusing with binning 8."
    executor::setwindow "2kx2k"
    executor::setbinning 8
    executor::focus 1 3000 400 false true
  }

  log::summary "allskyprologvisit: focusing with binning 4."
  executor::setwindow "2kx2k"
  executor::setbinning 4
  executor::focus 2 1000 100 false false
  executor::setfocused

  log::summary "allskyprologvisit: focusing with binning 1."
  executor::setwindow "1kx1k"
  executor::setbinning 1
  executor::focus 4 1000 100 true false
  executor::setfocused

  # Then correct pointing

  log::summary "allskyprologvisit: correcting pointing."
  executor::setwindow "6kx6k"
  executor::setbinning "default"
  executor::correctpointing 4
  
  log::summary "allskyprologvisit: finished."

}

########################################################################

proc trackingtestvisit {exposures exposuretime} {

  log::summary "trackingvisit: starting."
  log::summary [format "trackingvisit: %d × %.0f second exposures." $exposures $exposuretime]

  executor::setwindow "1kx1k"
  executor::setbinning "default"
  
  executor::tracktopocentric
  executor::waituntiltracking
  
  set exposure 0
  while {$exposure < $exposures} {
    executor::expose object $exposuretime
    incr exposure
  }

  log::summary "trackingvisit: finished."

  return true
}

########################################################################

proc initialfocusvisit {} {

  log::summary "initialfocusvisit: starting."

  executor::setreadmode 16MHz

  executor::track

  log::summary "initialfocusvisit: focusing with binning 8."
  executor::setwindow "2kx2k"
  executor::setbinning 8
  executor::waituntiltracking
  executor::focus 1 2000 250 false true
    
  log::summary "initialfocusvisit: focusing with binning 1."
  executor::setwindow "1kx1k"
  executor::setbinning 1
  executor::focus 4 600 75 false false

  log::summary "initialfocusvisit: focus witness with binning 1."
  executor::expose "object" 4
  executor::analyze "fwhmwitness"

  executor::setfocused

  log::summary "initialfocusvisit: full focus witness with binning 1."
  executor::setwindow "default"
  executor::expose "object" 4
  executor::analyze "fwhmwitness"

  log::summary "initialfocusvisit: finished."

  return false
}

########################################################################

proc correctpointingvisit {} {
  log::summary "correctpointingvisit: starting."
  executor::tracktopocentric
  executor::setwindow "6kx6k"
  executor::setbinning "default"
  executor::waituntiltracking
  log::summary "correctpointingvisit: correcting."
  executor::correctpointing 4
  log::summary "correctpointingvisit: finished."
}

########################################################################

proc focusvisit {} {

  log::summary "focusvisit: starting."

  executor::setreadmode 16MHz

  executor::track

  log::summary "focusvisit: focusing with binning 8."
  executor::setwindow "2kx2k"
  executor::setbinning 8
  executor::waituntiltracking
  executor::focus 1 2000 250 false true

  log::summary "focusvisit: focus witness with binning 4."
  executor::setbinning 4
  executor::expose "object" 1
  executor::analyze "fwhmwitness"
    
  log::summary "focusvisit: focusing with binning 1."
  executor::setwindow "1kx1k"
  executor::setbinning 1
  executor::focus 4 400 50 false false

  log::summary "focusvisit: focus witness with binning 1."
  executor::expose "object" 4
  executor::analyze "fwhmwitness"

  executor::setfocused

  log::summary "focusvisit: finished."

  return false
}

########################################################################

proc finefocusvisit {} {

  log::summary "finefocusvisit: starting."

  executor::track
  executor::setreadmode 16MHz

  log::summary "focusvisit: focusing with binning 1."
  executor::setwindow "1kx1k"
  executor::setbinning 1
  executor::waituntiltracking
  executor::focus 4 600 75 false false

  executor::setfocused

  log::summary "finefocusvisit: focus witness with binning 1."
  executor::expose "object" 4
  executor::analyze "fwhmwitness"

  log::summary "finefocusvisit: finished."
  return false
}

########################################################################

proc fullfocusvisit {range exposuretime} {

  log::summary "fullfocusvisit: starting."

  executor::track
  executor::setreadmode 16MHz
  executor::setwindow "default"
  executor::setbinning 1
  executor::waituntiltracking
  
  log::summary "fullfocusvisit: focusing with binning 1."
  executor::focus $exposuretime $range [expr {$range / 10}] false true
  
  log::summary "fullfocusvisit: finished."

  return true
}

########################################################################

proc focusmapvisit {} {

  log::summary "focusmapvisit: starting."
   
  set ha    [visit::observedha    [executor::visit]]
  set delta [visit::observeddelta [executor::visit]]
  log::summary [format "focusmapvisit: focusing at %s %s." [astrometry::formatha $ha]  [astrometry::formatdelta $delta]]
   
  executor::setreadmode 16MHz

  executor::tracktopocentric

  log::summary "focusmapvisit: focusing with binning 8."
  executor::setwindow "2kx2k"
  executor::setbinning 8
  executor::waituntiltracking
  executor::focus 1 1000 125 false true

  log::summary "focusmapvisit: focus witness with binning 8."
  executor::setbinning 8
  executor::expose "object" 1
  executor::analyze "fwhmwitness"
    
  set worstfwhmarcsec [client::getdata "instrument" "worstfwhmarcsec"]
  if {[string equal $worstfwhmarcsec "unknown"] || $worstfwhmarcsec > 100} {
    log::summary "focusmapvisit: aborting with worst witness FWHM of ${worstfwhmarcsec}as."
    log::summary "focusmapvisit: finished."
    return true
  }

  log::summary "focusmapvisit: focusing with binning 1."
  executor::setwindow "1kx1k"
  executor::setbinning 1
  executor::focus 4 600 75 false false

  log::summary "focusmapvisit: focus witness with binning 1."
  executor::expose "object" 4
  executor::analyze "fwhmwitness"

  set worstfwhmarcsec [client::getdata "instrument" "worstfwhmarcsec"]
  if {[string equal $worstfwhmarcsec "unknown"] || $worstfwhmarcsec > 12} {
    log::summary "focusmapvisit: aborting with worst witness FWHM of ${worstfwhmarcsec}as."
    log::summary "focusmapvisit: finished."
    return true
  }
    
  log::summary "focusmapvisit: succeeded with worst witness FWHM is ${worstfwhmarcsec}as."
  log::summary "focusmapvisit: finished."

  return true
}

########################################################################

proc focuswitnessvisit {} {

  log::summary "focuswitnessvisit: starting."

  executor::track

  executor::setwindow "6kx6k"
  executor::setbinning 1

  executor::waituntiltracking
  
  set dithers {
     0as  0as
    +5am +5am
    -5am -5am
    +5am -5am
    -5am +5am
  }

  foreach {eastoffset northoffset} $dithers {
    executor::offset $eastoffset $northoffset "default"
    executor::waituntiltracking
    executor::expose "object" 4
    executor::analyze "fwhmwitness"
  }
    
  log::summary "focuswitnessvisit: finished."

  return true
}

########################################################################

proc pointingmapvisit {} {

  log::summary "pointingmapvisit: starting."
  
#   set ha    [visit::ha]
#   set delta [visit::delta]
# 
#   log::summary "focusmapvisit: focusing at $ha $delta."
#   visit::settargetcoordinates fixed $ha $delta now
#   executor::tracktopocentric  
#   executor::waituntiltracking
#   executor::setwindow "6kx6k"
#   executor::setbinning 1
#   executor::expose object 4

  return true
}

########################################################################

proc twilightflatsvisit {} {
  log::summary "twilightflatsvisit: starting."
  executor::move
  executor::setbinning 1
  executor::setwindow "default"
  set detectors [client::getdata instrument activedetectors]
  set leveldetector [lindex $detectors 0]
  set minlevel 1000
  set maxlevel 3000
  set filter "w"
  set ngood 0
  set mingoodlevel $maxlevel
  set maxgoodlevel $minlevel
  set evening [executor::isevening]
  while {true} {
    executor::expose flat 5
    executor::analyze levels
    set level [executor::exposureaverage $leveldetector]
    log::info [format "twilightflatsvisit: level is %.1f DN in filter $filter." $level]
    if {$level > $maxlevel && $evening} {
      log::info "twilightflatsvisit: waiting (too bright)."
      coroutine::after 60000
    } elseif {$level < $minlevel && !$evening} {
      log::info "twilightflatsvisit: waiting (too faint)."
      coroutine::after 60000
    } elseif {$minlevel <= $level && $level <= $maxlevel} {
      if {$ngood == 0} {
        log::info "twilightflatsvisit: first good flat with filter $filter."
      }
      coroutine::after 10000
      incr ngood
      set mingoodlevel [expr {min($level,$mingoodlevel)}]
      set maxgoodlevel [expr {max($level,$maxgoodlevel)}]
    } else {
      break
    }
  }
  if {$ngood == 0} {
    log::summary [format "twilightflatsvisit: $ngood good flats with filter $filter."]
  } else {      
    log::summary [format "twilightflatsvisit: $ngood good flats (%.0f to %.0f DN) with filter $filter." $mingoodlevel $maxgoodlevel]
  }
  if {$evening} {
    log::info "twilightflatsvisit: finished with filter $filter (too faint)."
  } else {
    log::info "twilightflatsvisit: finished with filter $filter (too bright)."
  }
  log::summary "twilightflatsvisit: finished."
  return true
}

########################################################################

proc domeflatsvisit {} {
  log::summary "domeflatsvisit: starting."
  executor::setbinning 1
  executor::setwindow "default"
  set detectors [client::getdata instrument detectors]
  set leveldetector [lindex $detectors 0]
  set minlevel 1000
  set maxlevel 3000
  set filter "w"
  set ngood 0
  set mingoodlevel $maxlevel
  set maxgoodlevel $minlevel
  set evening [executor::isevening]
  while {true} {
    executor::expose flat 5
    executor::analyze levels
    set level [executor::exposureaverage $leveldetector]
    log::info [format "domeflatsvisit: level is %.1f DN." $level]
    if {$level > $maxlevel && $evening} {
      log::info "domeflatsvisit: waiting (too bright)."
      coroutine::after 60000
    } elseif {$level < $minlevel && !$evening} {
      log::info "domeflatsvisit: waiting (too faint)."
      coroutine::after 60000
    } elseif {$minlevel <= $level && $level <= $maxlevel} {
      if {$ngood == 0} {
        log::info "domeflatsvisit: first good flat."
      }
      coroutine::after 10000
      incr ngood
      set mingoodlevel [expr {min($level,$mingoodlevel)}]
      set maxgoodlevel [expr {max($level,$maxgoodlevel)}]
    } else {
      break
    }
    if {$ngood == 10} {
      break
    }
  }
  if {$ngood == 0} {
    log::summary [format "domeflatsvisit: $ngood good flats."]
  } else {      
    log::summary [format "domeflatsvisit: $ngood good flats (%.0f to %.0f DN)." $mingoodlevel $maxgoodlevel]
  }
  log::summary "domeflatsvisit: finished."
  return true
}

########################################################################

proc biasesvisit {{exposures 10}} {
  log::summary "biasesvisit: starting."
  executor::setwindow "default"
  executor::setreadmode "16MHz"
  executor::setbinning 1
  set exposure 0
  while {$exposure < $exposures} {
    executor::expose bias 0
    executor::analyze levels
    incr exposure
    coroutine::after 10000
  }
  log::summary "biasesvisit: finished."
  return true
}

########################################################################

proc darksvisit {{exposures 10} {exposuretime 60}} {
  log::summary "darksvisit: starting."
  executor::setwindow "default"
  executor::setreadmode "16MHz"
  executor::setbinning 1
  set exposure 0
  while {$exposure < $exposures} {
    executor::expose dark $exposuretime
    executor::analyze levels
    incr exposure
    coroutine::after 10000
  }
  log::summary "darksvisit: finished."
  return true
}

########################################################################

proc aperturesvisit {} {
  log::summary "aperturesvisit: starting."
  executor::setbinning 8
  executor::setwindow "default"
  executor::track
  executor::waituntiltracking
  log::summary "aperturesvisit: correcting pointing."
  executor::correctpointing 4
  foreach aperture { "default" "W" "NW" "NE" "E" "SE" "SW" } {
    log::summary "aperturesvisit: checking aperture $aperture."
    executor::track 0 0 $aperture
    executor::waituntiltracking
    executor::expose object 4
  }
  log::summary "aperturesvisit: finished."
  return true
}
########################################################################

proc satellitevisit {starttime exposures exposuretime} {

  log::summary "satellitevisit: starting."

  executor::track 0 0 "default"
  executor::setbinning 1
  executor::setwindow "default"
  executor::waituntiltracking

  log::summary "satellitevisit: waiting to take first exposure after [utcclock::format $starttime]."

  set startseconds [utcclock::scan $starttime]
  while {[utcclock::seconds] + 10 <= $startseconds} {
    coroutine::after 100
  }

  log::summary "satellitevisit: starting exposures."

  set exposure 0
  while {$exposure < $exposures} {
    executor::exposeafter object $starttime $exposuretime
    incr exposure
  }

  log::summary "satellitevisit: finished exposures."

  log::summary "satellitevisit: finished."
  return true
}

########################################################################
