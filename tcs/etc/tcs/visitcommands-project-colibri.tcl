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

  log::summary [format "alertvisit: filters are %s." $filters]
  set nfilters [llength [parsefilters $filters]]
  set exposurerepeats [expr {int(16 / $nfilters)}]
  set exposuretime 60
  log::summary [format "alertvisit: exposures are %d x %.0f seconds." $exposurerepeats $exposuretime]

  set uncertainty [astrometry::parsedistance [alert::uncertainty [executor::alert]]]
  log::summary [format "alertvisit: uncertainty is %s." [astrometry::formatdistance $uncertainty 2]]
  
  if {$uncertainty <= [astrometry::parsedistance "13am"]} {
    log::summary "alertvisit: grid is 1 × 1 fields."
    dithervisit $exposurerepeats $exposuretime $filters false
  } elseif {$uncertainty <= [astrometry::parsedistance "26am"]} {
    log::summary "alertvisit: grid is 2 × 2 fields."
    quaddithervisit $exposurerepeats $exposuretime $filters false
  }

  return

  if {true || $uncertainty <= [astrometry::parsedistance "6am"]} {
    log::summary "alertvisit: grid is 1 × 1 fields."
    dithervisit $exposurerepeats $exposuretime $filters false
  } elseif {$uncertainty <= [astrometry::parsedistance "13am"]} {
    log::summary "alertvisit: grid is 2 × 2 fields."
    quaddithervisit $exposurerepeats $exposuretime $filters false
  }

}

########################################################################

proc parsefilters {filters} {
  switch $filters {
    "gri" -
    "gri/zy" {
      set filters {{r gri zy}}
    }
    "g" -
    "g/z" {
      set filters {{r g z}}
    }
    "g/r" -
    "g/r/z" {
      set filters {{r g z} {r r z}}
    }
    "g/r/zy" {
      set filters {{r g zy} {r r zy}}
    }
    "g/i" -
    "g/i/z" {
      set filters {{r g z} {r i z}}
    }
    "g/i/zy" {
      set filters {{r g zy} {r i zy}}
    }
    "g/r/i" -
    "g/r/i/z" {
      set filters {{r g z} {r r z} {r i z}}
    }
    "g/r/i/zy" {
      set filters {{r g zy} {r r zy} {r i zy}}
    }
    "g/r/i/z/y" {
      set filters {{r g z} {r r y} {r i y}}
    }
    "g/r/i/B" -
    "g/r/i/B/z" {
      set filters {{r g z} {r r z} {r i z} {r B z}}
    }
    "r" -
    "r/z" {
      set filters {{r r z}}
    }
    "r/zy" {
      set filters {{r r zy}}
    }
    "r/i" -
    "r/i/z" {
      set filters {{r r z} {r i z}}
    }
    "r/i/zy" {
      set filters {{r r zy} {r i zy}}
    }
    "i" -
    "i/z" {
      set filters {{r i z}}
    }
    "i/zy" {
      set filters {{r i zy}}
    }    
    "g/r/i/gri/B" {
      set filters {{r g zy} {r r zy} {r i zy} {r gri zy} {r B zy}}
    }
  }
  return $filters
}

########################################################################

proc gridvisit {gridrepeats gridpoints exposurerepeats exposuretimes filters {offsetfastest false}} {

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
  executor::track

  executor::setwindow "default"
  executor::setbinning 2

  executor::waituntiltracking
  
  # Thus gives reasonable results for 1, 2, 4, 5, and 9 gridpoints.
  if {$gridpoints == 0} {
    set dithers { 0as 0as }
  } else {
    set dithers [lrange {
          +30as +30as
          -30as -30as
          +30as -30as
          -30as +30as
            0as   0as
          +30as   0as
          -30as   0as
            0as +30as
            0as -30as
        } 0 [expr {$gridpoints * 2 - 1}]]
  }

  set gridrepeat 0
  while {$gridrepeat < $gridrepeats} {
    if {$offsetfastest} {
      foreach filter $filters exposuretime $exposuretimes {
        eval executor::movefilterwheel $filter
        foreach {eastoffset northoffset} $dithers {
          executor::offset $eastoffset $northoffset "default"
          executor::waituntiltracking
          set exposure 0
          while {$exposure < $exposurerepeats} {
            executor::expose object $exposuretime
            incr exposure
          }
        }
      }
    } else {
      foreach {eastoffset northoffset} $dithers {
        executor::offset $eastoffset $northoffset "default"
        executor::waituntiltracking
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

proc fullgridvisit {gridrepeats gridpoints exposurerepeats exposuretimes filters {offsetfastest false}} {

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
  executor::track

  executor::setwindow "default"
  executor::setbinning 2

  executor::waituntiltracking
  
  # Thus gives reasonable results for 1, 2, 4, 5, and 9 gridpoints.
  if {$gridpoints == 0} {
    set dithers { 0as 0as }
  } else {
    set dithers [lrange {
          +30as +30as
          -30as -30as
          +30as -30as
          -30as +30as
            0as   0as
          +30as   0as
          -30as   0as
            0as +30as
            0as -30as
        } 0 [expr {$gridpoints * 2 - 1}]]
  }

  set gridrepeat 0
  while {$gridrepeat < $gridrepeats} {
    if {$offsetfastest} {
      foreach filter $filters exposuretime $exposuretimes {
        eval executor::movefilterwheel $filter
        foreach {eastdither northdither} $dithers {
          foreach {eaststep northstep} { 
            "-6am" "-6am"
            "+6am" "-6am"
            "-6am" "+6am"
            "+6am" "+6am"
          } {
            set eastoffset  [expr {[astrometry::parseoffset $eaststep ] + [astrometry::parseoffset $eastdither ]}]
            set northoffset [expr {[astrometry::parseoffset $northstep] + [astrometry::parseoffset $northdither]}]
            executor::offset $eastoffset $northoffset "default"
            executor::waituntiltracking
            set exposure 0
            while {$exposure < $exposurerepeats} {
              executor::expose object $exposuretime
              incr exposure
            }
          }
        }
      }
    } else {
      foreach {eastoffset northoffset} $dithers {
        executor::offset $eastoffset $northoffset "default"
        executor::waituntiltracking
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

proc dithervisit {dithers exposuretimes filters {offsetfastest false} {diameter "1am"}} {

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

  executor::setwindow "default"
  executor::setbinning 2

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
          executor::waituntiltracking
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
      executor::waituntiltracking
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

  executor::setwindow "default"
  executor::setbinning 2

  executor::waituntiltracking
  
  log::summary "quaddithervisit: dithering in a circle of diameter $diameter in a 2 × 2 grid."
  foreach filter $filters exposuretime $exposuretimes {
    eval executor::movefilterwheel $filter
    set exposure 0
    while {$exposure < $exposurerepeats} {
      foreach {visitidentifier eastcenteroffset northcenteroffset} {
        0 +12am +12am
        1 -12am +12am
        2 +12am -12am
        3 -12am -12am
      } {
        executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
        quaddithervisitoffset $diameter $eastcenteroffset $northcenteroffset
        executor::waituntiltracking
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
  executor::waituntiltracking

  log::summary "coarsefocusvisit: centering."
  executor::center $exposuretime
  executor::waituntiltracking

  log::summary "coarsefocusvisit: focusing in filter $filter with $exposuretime second exposures and binning 8."
  executor::setwindow "2kx2k"
  executor::setbinning 8
  executor::focussecondary "C0" $exposuretime 1000 100 false true
  #executor::focussecondary "C1" $exposuretime 1000 100 true false
  #executor::focussecondary "C2" $exposuretime 100 10 true false
  
  log::summary "coarsefocusvisit: finished."

  return true
}

########################################################################

proc focusvisit {{exposuretime 5} {filter {"r" "i" "z"}}} {

  log::summary "focusvisit: starting."
  
  executor::setsecondaryoffset 0
  executor::track
  executor::setwindow "default"
  executor::setbinning 2
  eval executor::movefilterwheel "$filter"
  executor::waituntiltracking

  log::summary "focusvisit: centering."
  executor::center $exposuretime
  executor::waituntiltracking

  executor::setwindow "1kx1k"
  if {0} {
    executor::setbinning 2
    foreach filter {i} {
      log::summary "focusvisit: focusing in filter $filter with $exposuretime second exposures and binning 1."
      executor::focussecondary C1 $exposuretime 100 10 true false
    }
    foreach filter {z} {
      log::summary "focusvisit: focusing in filter $filter with $exposuretime second exposures and binning 1."
      executor::focussecondary C2 $exposuretime 100 10 true false
    }
  } else {
      log::summary "focusvisit: focusing in filter $filter with $exposuretime second exposures and binning 1."
      executor::setbinning 2
      executor::focussecondary C0 $exposuretime 100 10 true false
      #executor::focussecondary C1 $exposuretime 100 10 true false
  }
  
  log::summary "focusvisit: finished."

  return true
}

########################################################################

proc focustiltvisit {{exposuretime 5} {filter {"r" "i" "z"}}} {

  log::summary "focustiltvisit: starting."
  
  executor::setsecondaryoffset 0
  executor::track
  executor::setwindow "4kx4k"
  executor::setbinning 2
  eval executor::movefilterwheel "$filter"
  executor::waituntiltracking

  log::summary "focustiltvisit: focusing in filter $filter with $exposuretime second exposures and binning 2."
  executor::focus $exposuretime 300 15 false false
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
  executor::setbinning 2
  eval executor::movefilterwheel $filter
  executor::waituntiltracking
  
  set dithers {
      0as   0as
    +30as +30as
    -30as -30as
    +30as -30as
    -30as +30as
  }

  foreach {eastoffset northoffset} $dithers {
    executor::offset $eastoffset $northoffset "default"
    executor::waituntiltracking
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
  executor::setbinning 2
  eval executor::movefilterwheel $filter

  executor::waituntiltracking

  log::summary "correctpointingvisit: correcting pointing."
  executor::correctpointing $exposuretime

  log::summary "correctpointingvisit: finished."
  return true
}

########################################################################

proc biasesvisit {{exposures 10} {binning 2}} {
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

proc darksvisit {{exposuretime 30} {exposures 10} {binning 2}} {
  log::summary "darksvisit: starting."
#  executor::move
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

proc twilightflatsvisit {targetngood filter} {

  log::summary "twilightflatsvisit: starting."

  executor::setsecondaryoffset 0
  executor::move

  executor::setwindow "default"
  executor::setbinning 2

  # The dark current is about 1000 DN/s at -10 C, so use shorter exposures than
  # normal. The gain is about 2.2 electrons/DN and the bias about 500 DN, so 15k
  # and 25k correspond to SNRs of 200 and 100. We set the upper limit to 30k in
  # order to change from i to g earlier. We take the flats in the order y, z, i,
  # g, and finally r.

  set maxlevel 30000
  set minlevel  5000
  set exposuretime 5
  
  set filters {
    { r B   y  }
    { r i   y  }
    { r r   z  }
    { r g   zy }
    { r gri zy }
  }
  
  foreach filter $filters {
  
      log::info "twilightflatsvisit: filter $filter."
      eval executor::movefilterwheel $filter
    
      set ngood 0
      set mingoodlevel $maxlevel
      set maxgoodlevel $minlevel
      while {true} {
        executor::expose flat $exposuretime
        executor::analyze levels
        set level [executor::exposureaverage C0]
        log::info [format "twilightflatsvisit: level is %.1f DN in filter $filter in $exposuretime seconds." $level]
        if {$level > $maxlevel} {
          log::info "twilightflatsvisit: level is too bright."
        } elseif {$level < $minlevel} {
          log::info "twilightflatsvisit: level is too faint."
          break
        } else {
          log::info "twilightflatsvisit: level is good."
          incr ngood
          set mingoodlevel [expr {min($level,$mingoodlevel)}]
          set maxgoodlevel [expr {max($level,$maxgoodlevel)}]
          if {$ngood == $targetngood} {
            break
          }
        }
      }
    
      if {$ngood == 0} {
        log::summary [format "twilightflatsvisit: $ngood good flats in filter $filter."]
      } else {
        log::summary [format "twilightflatsvisit: $ngood good flats in filter $filter (%.0f to %.0f DN)." $mingoodlevel $maxgoodlevel]
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
  executor::setbinning 2
  eval executor::movefilterwheel $filter
  executor::waituntiltracking
  
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
    executor::waituntiltracking
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
  executor::setbinning 2
  eval executor::movefilterwheel $filter

  log::summary "hartmanntestvisit: extrafocal images: secondary offset is +$secondaryoffset."

  executor::setsecondaryoffset +$secondaryoffset
  executor::track $eastoffset $northoffset
  executor::waituntiltracking
  
  set exposure 0
  while {$exposure < $exposures} {
    executor::expose object $exposuretime
    incr exposure
  }
  
  log::summary "hartmanntestvisit: intrafocal images: secondary offset is -$secondaryoffset."

  executor::setsecondaryoffset -$secondaryoffset
  executor::offset $eastoffset $northoffset
  executor::waituntiltracking

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
  executor::setbinning 2
  eval executor::movefilterwheel $filter

  executor::track $eastoffset $northoffset
  executor::waituntiltracking

  #log::summary "tokovinintestvisit: correcting pointing."
  #executor::correctpointing $exposuretime
  #executor::waituntiltracking

  foreach secondaryoffset {-1000 +1000} {

    log::summary "tokovinintestvisit: images with secondary offset of $secondaryoffset."

    executor::setsecondaryoffset $secondaryoffset
    executor::offset  $eastoffset $northoffset
    executor::waituntiltracking
      
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
  executor::setbinning 2
  eval executor::movefilterwheel $filter

  executor::track 0 0
  executor::waituntiltracking

  #log::summary "tokovinintestvisit: correcting pointing."
  #executor::correctpointing $exposuretime
  #executor::waituntiltracking

  foreach secondaryoffset {-90 -60 -30 -15 -10 -5 0 +5 +10 +15 +30 +60 +90} {

    log::summary "nearfocustestvisit: images with secondary offset of $secondaryoffset."

    executor::setsecondaryoffset $secondaryoffset
    executor::offset 0 0
    executor::waituntiltracking
      
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

proc pointingmapvisit {{exposuretime 15} {filter {"r" "i" "z"}}} {

  log::summary "pointingmapvisit: starting."

  executor::setsecondaryoffset 0
  executor::track

  executor::setwindow "default"
  executor::setbinning 2
  
  eval executor::movefilterwheel $filter
  
  executor::waituntiltracking

  executor::center $exposuretime
  executor::center $exposuretime

  log::summary "pointingmapvisit: taking long exposures."
  executor::expose object 300

  log::summary "pointingmapvisit: finished."
  return true
}

########################################################################




