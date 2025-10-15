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

variable instrument "ddrago"

if {[string equal $instrument "ogse"]} {
  variable fieldsize [astrometry::parsedistance "13am"]
} elseif {[string equal $instrument "ddrago"]} {
  variable fieldsize [astrometry::parsedistance "26am"]
} else {
  error "invalid instrument \"$instrument\"."
}

proc alertvisit {filters} {
  
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

  set alertdelay [alert::delay [executor::alert]]
  log::summary [format "alertvisit: alert delay at start of visit is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]

  set uncertainty [astrometry::parsedistance [alert::uncertainty [executor::alert]]]
  log::summary [format "alertvisit: uncertainty is %s." [astrometry::formatdistance $uncertainty 2]]

  log::summary [format "alertvisit: filters are %s." $filters]
  set nfilters [llength [parsefilters $filters]]
  set exposurerepeats [expr {int(16 / $nfilters)}]
  
  variable fieldsize
  variable window
  
  if {$alertdelay <= 180 && $uncertainty <= [astrometry::parsedistance "3am"]} {

    set window "6am"
    set exposuretime 10
    log::summary [format "alertvisit: exposures are %d x %.0f seconds." $exposurerepeats $exposuretime]

    log::summary "alertvisit: no dithering."
    gridvisit 1 1 $exposurerepeats $exposuretime $filters
    
  } elseif {$alertdelay <= 180 && $uncertainty <= 0.5 * $fieldsize} {
  
    set window "default"
    set exposuretime 10
    log::summary [format "alertvisit: exposures are %d x %.0f seconds." $exposurerepeats $exposuretime]

    log::summary "alertvisit: no dithering."
    gridvisit 1 1 $exposurerepeats $exposuretime $filters
  
  } elseif {$alertdelay <= 480 && $uncertainty <= 0.5 * $fieldsize} {
  
    set window "default"
    set exposuretime 30
    log::summary [format "alertvisit: exposures are %d x %.0f seconds." $exposurerepeats $exposuretime]

    log::summary "alertvisit: dithering 1 × 1 fields."
    dithervisit $exposurerepeats $exposuretime $filters
  
  } elseif {$uncertainty <= 0.5 * $fieldsize} {

    set window "default"
    set exposuretime 60
    log::summary [format "alertvisit: exposures are %d x %.0f seconds." $exposurerepeats $exposuretime]
 
    log::summary "alertvisit: dithering 1 × 1 fields."
    dithervisit $exposurerepeats $exposuretime $filters
    
  } else {

    set window "default"
    set exposuretime 60
    log::summary [format "alertvisit: exposures are %d x %.0f seconds." $exposurerepeats $exposuretime]
 
    log::summary "alertvisit: dithering 2 × 2 fields."
    quaddithervisit $exposurerepeats $exposuretime $filters

  }
  
  set alertdelay [alert::delay [executor::alert]]
  log::summary [format "alertvisit: alert delay at end of visit is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]

  return

}

########################################################################

proc parsefilters {filters} {
  switch $filters {

    "g/r/i/z/y" {
      set filters {{r g z} {r r y} {r i y}}
    }
    "g/r/i" -
    "g/r/i/z" {
      set filters {{r g z} {r r z} {r i z}}
    }
    "g/r/i/y" {
      set filters {{r g y} {r r y} {r i y}}
    }
    "g/r/i/zy" {
      set filters {{r g zy} {r r zy} {r i zy}}
    }
    
    "g/r/z/y" {
      set filters {{r g z} {r r y} {r g y} {r r z} {r g y} {r r y}}
    }
    "g/r" -
    "g/r/z" {
      set filters {{r g z} {r r z}}
    }
    "g/r/y" {
      set filters {{r g y} {r r y}}
    }
    "g/r/zy" {
      set filters {{r g zy} {r r zy}}
    }

    "g/i/z/y" {
      set filters {{r g z} {r i y} {r g y} {r i z} {r g y} {r i y}}
    }
    "g/i" -
    "g/i/z" {
      set filters {{r g z} {r i z}}
    }
    "g/i/y" {
      set filters {{r g y} {r i y}}
    }
    "g/i/zy" {
      set filters {{r g zy} {r i zy}}
    }

    "r/i/z/y" {
      set filters {{r r z} {r i y} {r r y} {r i z} {r r y} {r i y}}
    }
    "r/i" -
    "r/i/z" {
      set filters {{r r z} {r i z}}
    }
    "r/i/y" {
      set filters {{r r y} {r i y}}
    }
    "r/i/zy" {
      set filters {{r r zy} {r i zy}}
    }

    "g/z/y" {
      set filters {{r g z} {r g y} {r g y}}
    }
    "g" -
    "g/z" {
      set filters {{r g z}}
    }
    "g/y" {
      set filters {{r g y}}
    }
    "g/zy" {
      set filters {{r g zy}}
    }

    "r/z/y" {
      set filters {{r r z} {r r y} {r r y}}
    }
    "r" -
    "r/z" {
      set filters {{r r z}}
    }
    "r/y" {
      set filters {{r r y}}
    }
    "r/zy" {
      set filters {{r r zy}}
    }

    "i/z/y" {
      set filters {{r i z} {r i y} {r i z}}
    }
    "i" -
    "i/z" {
      set filters {{r i z}}
    }
    "i/y" {
      set filters {{r i y}}
    }
    "i/zy" {
      set filters {{r i zy}}
    }

    "gri" -
    "gri/zy" {
      set filters {{r gri zy}}
    }

    "g/r/i/B" -
    "g/r/i/B/z" {
      set filters {{r g z} {r r z} {r i z} {r B z}}
    }

    "g/r/i/gri/B/z/y/zy" {
      set filters {{r g z} {r r y} {r i y} {r gri zy} {r B zy}}
    }

  }

  return $filters
}

########################################################################

variable window "default"
variable binning "default"

proc setdetector {} {
  variable window
  executor::setwindow $window
  set window "default"
  variable binning
  executor::setbinning $binning
  set binning "default"
}

########################################################################

proc gridvisitoffset {gridsize eastoffsetfactor northoffsetfactor track} {
  set gridsize [astrometry::parseoffset $gridsize]
  set eastoffset  [expr {$eastoffsetfactor  * $gridsize}]
  set northoffset [expr {$northoffsetfactor * $gridsize}]
  if {$track} {
    executor::track $eastoffset $northoffset "default"
  } else {
    executor::offset $eastoffset $northoffset "default"
  }
}

proc gridvisit {gridrepeats gridpoints exposurerepeats exposuretimes filters {gridsize 1am} {offsetfastest false}} {

  log::summary "gridvisit: starting."

  set filters [parsefilters $filters]
  if {[llength $exposuretimes] == 1} {
    set exposuretimes [lrepeat [llength $filters] $exposuretimes]
  } elseif {[llength $filters] == 1} {
    set filters [lrepeat [llength $exposuretimes] $filters]
  } elseif {[llength $exposuretimes] != [llength $filters]} {
    error "the exposuretimes and filters arguments have different lengths."
  }

  executor::setsecondaryoffset 0

  setdetector

  set track true

  # Thus gives reasonable results for 1, 2, 4, 5, and 9 gridpoints.
  if {$gridpoints == 1} {
    set ditherofsetfactors { 0 0 }
  } else {
    set ditherofsetfactors [lrange {
          +0.5 +0.5
          -0.5 -0.5
          +0.5 -0.5
          -0.5 +0.5
          +0.0 +0.0
          +0.5 +0.0
          -0.5 +0.0
          +0.0 +0.5
          +0.0 -0.5
        } 0 [expr {$gridpoints * 2 - 1}]]
  }
  
  set gridrepeat 0
  while {$gridrepeat < $gridrepeats} {
    if {$offsetfastest} {
      foreach filter $filters exposuretime $exposuretimes {
        eval executor::movefilterwheel $filter
        foreach {eastoffsetfactor northoffsetfactor} $ditherofsetfactors {
          gridvisitoffset $gridsize $eastoffsetfactor $northoffsetfactor $track
          set track false
          set exposure 0
          while {$exposure < $exposurerepeats} {
            executor::expose object $exposuretime
            incr exposure
          }
        }
      }
    } else {
      foreach {eastoffsetfactor northoffsetfactor} $ditherofsetfactors {
        gridvisitoffset $gridsize $eastoffsetfactor $northoffsetfactor $track
        set track false
        foreach filter $filters exposuretime $exposuretimes {
          eval executor::movefilterwheel $filter
          set exposure 0
          while {$exposure < $exposurerepeats} {
            executor::expose object $exposuretime
            incr exposure
          }
        }
      }
    }
    incr gridrepeat
  }

  log::summary "gridvisit: finished."
  return true
}

########################################################################

proc dithervisitoffset {diameter track} {
  set diameter [astrometry::parseoffset $diameter]
  while {true} {
    set eastoffset  [expr {(rand() - 0.5) * $diameter}]
    set northoffset [expr {(rand() - 0.5) * $diameter}]
    if {$eastoffset * $eastoffset + $northoffset * $northoffset < 0.25 * $diameter * $diameter} {
      break
    }
  }
  if {$track} {
    executor::track $eastoffset $northoffset "default"
  } else {
    executor::offset $eastoffset $northoffset "default"
  }
}

proc dithervisit {dithers exposuretimes filters {diameter "1am"} {offsetfastest false}} {

  log::summary "dithervisit: starting."

  set filters [parsefilters $filters]
  if {[llength $exposuretimes] == 1} {
    set exposuretimes [lrepeat [llength $filters] $exposuretimes]
  } elseif {[llength $filters] == 1} {
    set filters [lrepeat [llength $exposuretimes] $filters]
  } elseif {[llength $exposuretimes] != [llength $filters]} {
    error "the exposuretimes and filters arguments have different lengths."
  }
    
  executor::setsecondaryoffset 0

  setdetector

  set track true
  
  log::summary "dithervisit: dithering in a circle of diameter $diameter."
  if {$offsetfastest} {
      set exposure 0
      foreach filter $filters exposuretime $exposuretimes {
        eval executor::movefilterwheel $filter
        set dither 0
        while {$dither < $dithers} {
          dithervisitoffset $diameter $track
          set track false
          incr dither
          executor::expose object $exposuretime
          incr exposure
        }
      }
  } else {
    set exposure 0
    set dither 0
    while {$dither < $dithers} {    
      dithervisitoffset $diameter $track
      set track false
      incr dither
      foreach filter $filters exposuretime $exposuretimes {
        eval executor::movefilterwheel $filter
        executor::expose object $exposuretime
        incr exposure
      }
    }
  }

  log::summary "dithervisit: finished."
  return true
}

########################################################################

proc quaddithervisitoffset {diameter eastcenteroffset northcenteroffset} {
  set diameter [astrometry::parseoffset $diameter]
  set eastcenteroffset  [astrometry::parseoffset $eastcenteroffset ]
  set northcenteroffset [astrometry::parseoffset $northcenteroffset]
  while {true} {
    set eastoffset  [expr {(rand() - 0.5) * $diameter}]
    set northoffset [expr {(rand() - 0.5) * $diameter}]
    if {$eastoffset * $eastoffset + $northoffset * $northoffset < 0.25 * $diameter * $diameter} {
      break
    }
  }
  set eastoffset  [expr {$eastoffset  + $eastcenteroffset }]
  set northoffset [expr {$northoffset + $northcenteroffset}]  
  executor::offset $eastoffset $northoffset "default"
}

proc quaddithervisit {exposurerepeats exposuretimes filters {offsetfastest false} {diameter "1am"}} {

  log::summary "quaddithervisit: starting."

  set filters [parsefilters $filters]
  if {[llength $exposuretimes] == 1} {
    set exposuretimes [lrepeat [llength $filters] $exposuretimes]
  } elseif {[llength $filters] == 1} {
    set filters [lrepeat [llength $exposuretimes] $filters]
  } elseif {[llength $exposuretimes] != [llength $filters]} {
    error "the exposuretimes and filters arguments have different lengths."
  }
  
  executor::setsecondaryoffset 0
  executor::track

  setdetector

  log::summary "quaddithervisit: dithering in a circle of diameter $diameter in a 2 × 2 grid."
  foreach filter $filters exposuretime $exposuretimes {
    eval executor::movefilterwheel $filter
    set exposure 0
    while {$exposure < $exposurerepeats} {
      foreach {visitidentifier eastcenteroffsetfactor northcenteroffsetfactor} {
        0 +0.45 +0.45
        1 -0.45 +0.45
        2 +0.45 -0.45
        3 -0.45 -0.45
      } {
        variable fieldsize
        set eastcenteroffset  [expr {$eastcenteroffsetfactor  * $fieldsize}]
        set northcenteroffset [expr {$northcenteroffsetfactor * $fieldsize}]
        executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
        quaddithervisitoffset $diameter $eastcenteroffset $northcenteroffset
        executor::expose object $exposuretime
        incr exposure
      }
    }
  }

  log::summary "quaddithervisit: finished."
  return true

}

########################################################################

proc coarsefocusvisit {{exposuretime 5} {filter {"r" "i" "z"}}} {

  log::summary "coarsefocusvisit: starting."
  
  executor::setsecondaryoffset 0
  executor::track
  executor::setwindow "default"
  executor::setbinning 8
  eval executor::movefilterwheel $filter

  log::summary "coarsefocusvisit: centering."
  executor::center $exposuretime

  variable instrument
  if {[string equal $instrument "ogse"]} {
    set window "2kx2k"
    set binning 16
    set detector "C0"
  } elseif {[string equal $instrument "ddrago"]} {
    set window "2kx2k"
    set binning 8
    set detector "C1"
  } else {
    error "invalid instrument \"$instrument\"."
  }
  
  log::summary [format \
    "coarsefocusvisit: focusing in filter $filter with $exposuretime second exposures and binning %d." \
    $binning \
  ]

  executor::setwindow $window
  executor::setbinning $binning
  executor::focussecondary $detector $exposuretime 1000 100 false true

  log::summary "coarsefocusvisit: finished."

  return true
}

########################################################################

proc focusvisit {{exposuretime 5} {filter {"r" "i" "z"}} {detector "C1"}} {

  log::summary "focusvisit: starting."
  
  variable instrument
  if {[string equal $instrument "ogse"]} {
    set window "1kx1k"
    set binning 2
    set detector "C0"
  } elseif {[string equal $instrument "ddrago"]} {
    set window "1kx1k"
    set binning 1
  } else {
    error "invalid instrument \"$instrument\"."
  }

  executor::setsecondaryoffset 0
  executor::track
  executor::setwindow "default"
  executor::setbinning "default"
  eval executor::movefilterwheel "$filter"

  log::summary "focusvisit: centering."
  executor::center $exposuretime

  log::summary [format \
    "focusvisit: focusing in filter $filter with $exposuretime second exposures and binning %d." \
    $binning \
  ]
  executor::setwindow $window
  executor::setbinning $binning
  executor::focussecondary $detector $exposuretime 100 10 true false
  
  log::summary "focusvisit: finished."

  return true
}

########################################################################

proc focustiltvisit {{exposuretime 5} {filter {"r" "i" "z"}}} {

  log::summary "focustiltvisit: starting."
  
  variable instrument
  if {[string equal $instrument "ogse"]} {
    set binning 2
    set detectors "C0"
  } elseif {[string equal $instrument "ddrago"]} {
    set binning 1
    set detectors {"C1" "C2"}
  } else {
    error "invalid instrument \"$instrument\"."
  }

  executor::setsecondaryoffset 0
  executor::track
  executor::setwindow "default"
  executor::setbinning $binning
  eval executor::movefilterwheel "$filter"

  foreach detector $detectors {
    log::summary "focustiltvisit: focusing $detector in filter $filter with $exposuretime second exposures and binning $binning."
    executor::focussecondary $detector $exposuretime 100 10 true false
  }
  executor::setunfocused
  
  log::summary "focustiltvisit: finished."

  return true
}

########################################################################

proc focuswitnessvisit {{exposuretime 5} {filter {"r" "i" "z"}}} {

  log::summary "focuswitnessvisit: starting."

  executor::setsecondaryoffset 0
  executor::track
  executor::setwindow "default"
  executor::setbinning "default"
  eval executor::movefilterwheel $filter
  
  set dithers {
      0as   0as
    +30as +30as
    -30as -30as
    +30as -30as
    -30as +30as
  }

  foreach {eastoffset northoffset} $dithers {
    executor::offset $eastoffset $northoffset "default"
    executor::expose "object" $exposuretime
    executor::analyze "fwhmwitness"
  }

  log::summary "focuswitnessvisit: finished."

  return true
}

########################################################################

proc pointingcorrectionvisit {{exposuretime 5} {filter {"r" "i" "z"}}} {

  log::summary "correctpointingvisit: starting."

  executor::setsecondaryoffset 0

  executor::track

  executor::setwindow "default"
  executor::setbinning "default"
  eval executor::movefilterwheel $filter

  log::summary "correctpointingvisit: correcting pointing."
  executor::correctpointing $exposuretime

  log::summary "correctpointingvisit: finished."
  return true
}

########################################################################

proc biasesvisit {{exposures 10} {binning "default"}} {
  log::summary "biasesvisit: starting."
  executor::move
  executor::setwindow "default"
  executor::setbinning $binning
  set exposure 0
  while {$exposure < $exposures} {
    executor::expose bias 0
    incr exposure
  }
  log::summary "biasesvisit: finished."
  return true
}

########################################################################

proc darksvisit {{exposuretime 30} {exposures 10} {binning "default"}} {
  log::summary "darksvisit: starting."
  executor::move
  executor::setwindow "default"
  executor::setbinning $binning
  set exposure 0
  while {$exposure < $exposures} {
    executor::expose dark $exposuretime
    incr exposure
  }
  log::summary "darksvisit: finished."
  return true
}

########################################################################

proc twilightflatsvisit {} {

  log::summary "twilightflatsvisit: starting."

  executor::setsecondaryoffset 0
  executor::move

  executor::setwindow "default"
  executor::setbinning "default"

  # The dark current is about 1000 DN/s at -10 C, so use shorter exposures than
  # normal. The gain is about 2.2 electrons/DN and the bias about 500 DN, so 15k
  # and 25k correspond to SNRs of 200 and 100. We set the upper limit to 30k in
  # order to change from i to g earlier. We take the flats in the order y, z, i,
  # g, and finally r.

  set targetngood 7
  set maxlevel 30000
  set minlevel  5000
  set exposuretime 5
  
  # set filters {
  #   { r B   y  }
  #   { r i   y  }
  #   { r r   z  }
  #   { r g   zy }
  #   { r gri zy }
  # }
  set filters1 {B i r g gri}
  set filters2 {y z zy}
  
  variable instrument
  if {[string equal $instrument "ogse"]} {
    set detector "C0"
  } elseif {[string equal $instrument "ddrago"]} {
    set detector "C1"
  } else {
    error "invalid instrument \"$instrument\"."
  }

  set finished1     false
  set ngood1        0
  set mingoodlevel1 $maxlevel
  set maxgoodlevel1 $minlevel

  set finished2     false
  set ngood2        0
  set mingoodlevel2 $maxlevel
  set maxgoodlevel2 $minlevel      

  while {!$finished1 || !$finished2} {

    set filter1 [lindex $filters1 0]
    set filter2 [lindex $filters2 0]
    log::info "twilightflatsvisit: filters are $filter1/$filter2."
    eval executor::movefilterwheel [list "r" $filter1 $filter2]

    executor::expose flat $exposuretime
    executor::analyze levels

    foreach i {1 2} {

      set finished     [set finished$i]
      set filters      [set filters$i]
      set ngood        [set ngood$i]
      set mingoodlevel [set mingoodlevel$i]
      set maxgoodlevel [set maxgoodlevel$i]

      if {!$finished} {
        set filter [lindex $filters 0]
        set level [executor::exposureaverage "C$i"]
        log::info [format "twilightflatsvisit: C$i: level is %.1f DN in $filter in $exposuretime seconds." $level]
        if {$level > $maxlevel} {
          log::info "twilightflatsvisit: C$i: level is too bright."
        } elseif {$level < $minlevel} {
          log::info "twilightflatsvisit: C$i: level is too faint."
        } else {
          log::info "twilightflatsvisit: C$i: level is good."
          incr ngood
          set mingoodlevel [expr {min($level,$mingoodlevel)}]
          set maxgoodlevel [expr {max($level,$maxgoodlevel)}]
        }

        if {$level < $minlevel || $ngood == $targetngood} {
          if {$ngood == 0} {
            log::summary [format "twilightflatsvisit: C$i: $ngood good flats in filter $filter."]
          } else {
            log::summary [format "twilightflatsvisit: C$i: $ngood good flats in filter $filter (%.0f to %.0f DN)." $mingoodlevel $maxgoodlevel]
          }
          if {[llength $filters] > 1} {
            set filters [lrange $filters 1 end]
            set ngood 0
            set mingoodlevel $maxlevel
            set maxgoodlevel $minlevel
          } else {
            set finished true
          }
        }

      }

      set finished$i     $finished
      set filters$i      $filters
      set ngood$i        $ngood
      set mingoodlevel$i $mingoodlevel
      set maxgoodlevel$i $maxgoodlevel

    }

  }

  log::summary "twilightflatsvisit: finished."

  return true
}

########################################################################

proc brightstarvisit {{offset 10am} {exposuretime 5} {filter {"r" "i" "z"}}} {

  log::summary "brightstarvisit: starting."

  executor::setsecondaryoffset 0
  executor::track
  executor::setwindow "default"
  executor::setbinning "default"
  eval executor::movefilterwheel $filter

  log::summary "brightstarvisit: offset is $offset."
  
  set dithers "       \
     0am      0am     \
     0am     +$offset \
     0am     -$offset \
    +$offset  0am     \
    -$offset  0am     \
    +$offset +$offset \
    -$offset -$offset \
    +$offset -$offset \
    -$offset +$offset \
  "

  foreach {eastoffset northoffset} $dithers {
    executor::offset $eastoffset $northoffset "default"
    executor::expose object $exposuretime
  }

  log::summary "brightstarvisit: finished."

  return true
}

########################################################################

proc hartmanntestvisit {secondaryoffset {eastoffset 0am} {northoffset 0am} {exposuretime 10} {filter {"r" "g" "z"}} {exposures 10}} {

  log::summary "hartmanntestvisit: starting."

  log::summary "hartmanntestvisit: offset is $eastoffset $northoffset."

  executor::setwindow "default"
  executor::setbinning "default"
  eval executor::movefilterwheel $filter

  log::summary "hartmanntestvisit: extrafocal images: secondary offset is +$secondaryoffset."

  executor::setsecondaryoffset +$secondaryoffset
  executor::track $eastoffset $northoffset
  
  set exposure 0
  while {$exposure < $exposures} {
    executor::expose object $exposuretime
    incr exposure
  }
  
  log::summary "hartmanntestvisit: intrafocal images: secondary offset is -$secondaryoffset."

  executor::setsecondaryoffset -$secondaryoffset
  executor::offset $eastoffset $northoffset

  set exposure 0
  while {$exposure < $exposures} {
    executor::expose object $exposuretime
    incr exposure
  }

  executor::setsecondaryoffset 0

  log::summary "hartmanntestvisit: finished."
  

  return true
}

########################################################################

proc tokovinintestvisit {{eastoffset 0am} {northoffset 0am} {exposuretime 10} {filter {"r" "i" "z"}} {exposures 10}} {

  log::summary "tokovinintestvisit: starting."

  log::summary "tokovinintestvisit: offset is $eastoffset $northoffset."

  executor::setwindow "default"
  executor::setbinning "default"
  eval executor::movefilterwheel $filter

  executor::track $eastoffset $northoffset

  #log::summary "tokovinintestvisit: correcting pointing."
  #executor::correctpointing $exposuretime

  foreach secondaryoffset {-1000 +1000} {

    log::summary "tokovinintestvisit: images with secondary offset of $secondaryoffset."

    executor::setsecondaryoffset $secondaryoffset
    executor::offset  $eastoffset $northoffset
      
    set exposure 0
    while {$exposure < $exposures} {
      executor::expose object $exposuretime
      incr exposure
    }
  
  }

  executor::setsecondaryoffset 0

  log::summary "tokovinintestvisit: finished."
  

  return true
}

########################################################################

proc nearfocustestvisit {{exposuretime 10} {filter {"r" "i" "z"}} {exposures 3}} {

  log::summary "nearfocustestvisit: starting."

  executor::setwindow "default"
  executor::setbinning "default"
  eval executor::movefilterwheel $filter

  executor::track 0 0

  #log::summary "tokovinintestvisit: correcting pointing."
  #executor::correctpointing $exposuretime

  foreach secondaryoffset {-90 -60 -30 -15 -10 -5 0 +5 +10 +15 +30 +60 +90} {

    log::summary "nearfocustestvisit: images with secondary offset of $secondaryoffset."

    executor::setsecondaryoffset $secondaryoffset
    executor::offset 0 0
      
    set exposure 0
    while {$exposure < $exposures} {
      executor::expose object $exposuretime
      incr exposure
    }
  
  }

  executor::setsecondaryoffset 0

  log::summary "nearfocustestvisit: finished."
  

  return true
}

########################################################################

proc addtopointingmodelvisit {{exposuretime 10} {filter {"r" "i" "z"}}} {

  log::summary "addtopointingmodelvisit: starting."

  executor::setsecondaryoffset 0
  executor::track

  executor::setwindow "2kx2k"
  executor::setbinning "default"
  
  eval executor::movefilterwheel $filter
  
  executor::addtopointingmodel $exposuretime

  log::summary "addtopointingmodelvisit: finished."
  return true
}

########################################################################




