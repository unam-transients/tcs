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

proc gridvisit {gridrepeats gridpoints exposurerepeats exposuretimes filters {offsetfastest true}} {

  log::summary "gridvisit: starting."

  executor::setsecondaryoffset 0
  executor::track

  executor::setwindow "default"
  executor::setbinning 1

  executor::waituntiltracking
  
  if {[llength $exposuretimes] == 1} {
    set exposuretimes [lrepeat [llength $filters] $exposuretimes]
  } elseif {[llength $exposuretimes] != [llength $filters]} {
    error "the exposuretimes and filters arguments have different lengths."
  }
  
  set dithers [lrange {
          0as   0as
        +30as +30as
        -30as -30as
        +30as -30as
        -30as +30as
        +30as   0as
        -30as   0as
          0as +30as
          0as -30as
      } 0 [expr {$gridpoints * 2 - 1}]]

  set gridrepeat 0
  while {$gridrepeat < $gridrepeats} {
    if {$offsetfastest} {
      foreach filter $filters exposuretime $exposuretimes {
        executor::movefilterwheel $filter
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
          executor::movefilterwheel $filter
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

proc coarsefocusvisit {{exposuretime 5} {filter "i"}} {

  log::summary "coarsefocusvisit: starting."
  
  setsecondaryoffset 0
  track
  setwindow "1kx1k"
  setbinning 4
  movefilterwheel "$filter"
  waituntiltracking

  log::summary "coarsefocusvisit: focusing in filter $filter with $exposuretime second exposures and binning 4."
  focussecondary C0 $exposuretime 500 50 false true
  
  log::summary "coarsefocusvisit: finished."

  return true
}

########################################################################

proc focusvisit {{exposuretime 5} {filter "i"}} {

  log::summary "focusvisit: starting."
  
  setsecondaryoffset 0
  track
  setwindow "1kx1k"
  setbinning 1
  movefilterwheel "$filter"
  waituntiltracking

  log::summary "focusvisit: focusing in filter $filter with $exposuretime second exposures and binning 1."
  focussecondary C0 $exposuretime 100 10 true false
  
  log::summary "focusvisit: finished."

  return true
}

########################################################################

proc focustiltvisit {{exposuretime 5} {filter "i"}} {

  log::summary "focustiltvisit: starting."
  
  setsecondaryoffset 0
  track
  setwindow "4kx4k"
  setbinning 1
  movefilterwheel "$filter"
  waituntiltracking

  log::summary "focustiltvisit: focusing in filter $filter with $exposuretime second exposures and binning 1."
  focussecondary C0 $exposuretime 300 15 false false
  setunfocused
  
  log::summary "focustiltvisit: finished."

  return true
}

########################################################################

proc focuswitnessvisit {{exposuretime 5} {filter "i"}} {

  log::summary "focuswitnessvisit: starting."

  executor::setsecondaryoffset 0
  executor::track
  executor::setwindow "default"
  executor::setbinning 1
  executor::movefilterwheel $filter
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
    executor::expose object $exposuretime
    executor::focuswitness
  }

  log::summary "focuswitnessvisit: finished."

  return true
}

########################################################################

proc biasesvisit {{exposures 10} {binning 1}} {
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

proc darksvisit {{exposuretime 60} {exposures 10} {binning 1}} {
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
  executor::setbinning 1

  # The dark current is about 1000 DN/s at -10 C, so use shorter exposures than
  # normal. The gain is about 2.2 electrons/DN and the bias about 500 DN, so 15k
  # and 25k correspond to SNRs of 200 and 100. We set the upper limit to 30k in
  # order to change from i to g earlier. We take the flats in the order y, z, i,
  # g, and finally r.

  set maxlevel 30000
  set minlevel 15000
  set exposuretime 5
  
  log::info "twilightflatsvisit: filter $filter."
  executor::movefilterwheel $filter

  set ngood 0
  set mingoodlevel $maxlevel
  set maxgoodlevel $minlevel
  while {true} {
    executor::expose flat $exposuretime
    executor::analyze levels
    set level [executor::exposureaverage C0]
    log::info [format "twilightflatsvisit: level is %.1f DN in filter $filter in $exposuretime seconds." $level]
    if {$level > 2 * $maxlevel} {
      log::info "twilightflatsvisit: level is much too bright."
      log::info "twilightflatsvisit: waiting for 60 seconds."
      coroutine::after 60000
    } elseif {$level > $maxlevel} {
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

  log::summary "twilightflatsvisit: finished."

  return true
}

########################################################################

proc brightstarvisit {{offset 10am} {exposuretime 5} {filter "i"}} {

  log::summary "brightstarvisit: starting."

  executor::setsecondaryoffset 0
  executor::track
  executor::setwindow "default"
  executor::setbinning 1
  executor::movefilterwheel $filter
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

proc hartmanntestvisit {secondaryoffset {eastoffset 0am} {northoffset 0am} {exposuretime 10} {filter "g"} {exposures 10}} {

  log::summary "hartmanntestvisit: starting."

  log::summary "hartmanntestvisit: offset is $eastoffset $northoffset."

  executor::setwindow "default"
  executor::setbinning 1
  executor::movefilterwheel $filter

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

proc tokovinintestvisit {{eastoffset 0am} {northoffset 0am} {exposuretime 10} {filter "g"} {exposures 10}} {

  log::summary "tokovinintestvisit: starting."

  log::summary "tokovinintestvisit: offset is $eastoffset $northoffset."

  executor::setwindow "default"
  executor::setbinning 1
  executor::movefilterwheel $filter

  executor::track $eastoffset $northoffset
  executor::waituntiltracking

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

proc pointingmapvisit {{exposuretime 15} {filter "i"} {readmode "conventionaldefault"}} {

  log::summary "pointingmapvisit: starting."

  setsecondaryoffset 0
  tracktopocentric

  setwindow "default"
  setreadmode "default"
  setbinning 1
  movefilterwheel $filter
  waituntiltracking

  expose object $exposuretime

  log::summary "pointingmapvisit: finished."
  return true
}

########################################################################


