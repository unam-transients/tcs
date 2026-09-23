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
proc alertvisit {{filters "r"}} {
  log::summary "alertvisit: starting."
  log::summary "alertvisit: filters are $filters."

  set alpha [visit::alpha   [executor::visit]]
  set delta [visit::delta   [executor::visit]]
  set equinox [visit::equinox [executor::visit]]

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
    log::info [format "alertvisit: no event timestamp."]
  } else {
    log::info [format "alertvisit: event timestamp is %s." [utcclock::format [alert::eventtimestamp [executor::alert]]]]
  }
  if {[string equal "" [alert::alerttimestamp [executor::alert]]]} {
    log::info [format "alertvisit: no alert timestamp."]
  } else {
    log::info [format "alertvisit: alert timestamp is %s." [utcclock::format [alert::alerttimestamp [executor::alert]]]]
  }

  set alertdelay [alert::delay [executor::alert]]
  log::summary \
    [format "alertvisit: alert delay at start of visit is %.1f seconds (%.1f hours)." $alertdelay \
    [expr {$alertdelay / 3600}]]
  if {$alertdelay < 1800} {
    set exposuretime 15
    set exposuresperdither 4
  } else {
    set exposuretime 15
    set exposuresperdither 4
  }
  set exposuresperfilterperdither [expr {int($exposuresperdither / [llength $filters])}]
  if {$exposuresperfilterperdither == 0} {
    set exposuresperfilterperdither 1
  }
  log::summary [format "alertvisit: taking %.0f second exposures in %s." $exposuretime $filters]
  log::summary [format "alertvisit: taking %d exposures per filter per dither." $exposuresperfilterperdither]

  executor::setsecondaryoffset 0

  executor::track

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning "default"
  executor::movefilterwheel [lindex $filters 0]

  set lastalpha [alert::alpha [executor::alert]]
  set lastdelta [alert::delta [executor::alert]]
  set lastequinox [alert::equinox [executor::alert]]

  set first true
  foreach {eastoffset northoffset} {
      0as   0as
    +15as +15as
    +15as -15as
    -15as -15as
    -15as +15as
      0as -15as
    +15as   0as
      0as +15as
    -15as   0as
  } {
    log::info "alertvisit: dithering $eastoffset E and $northoffset N."

    set lastalpha $alpha
    set lastdelta $delta
    set lastequinox $equinox

    if {![file exists [executor::filename]]} {
      log::summary "alertvisit: the alert is no longer in the queue."
      break
    }

    executor::setblock [alert::alerttoblock [alert::readalertfile [executor::filename]]]
    executor::setalert [block::alert [executor::block]]

    if {![alert::enabled [executor::alert]]} {
      log::summary "alertvisit: the alert is no longer enabled."
      return false
    }

    set alpha [alert::alpha [executor::alert]]
    set delta [alert::delta [executor::alert]]
    set equinox [alert::equinox [executor::alert]]

    if {$alpha != $lastalpha || $delta != $lastdelta || $equinox != $lastequinox} {
      log::summary "alertvisit: the coordinates have been updated."
      log::summary \
        [format "alertvisit: new alert coordinates are %s %s %s." [astrometry::formatalpha $alpha] \
        [astrometry::formatdelta $delta] $equinox]
      executor::setvisit \
        [visit::updatevisittargetcoordinates [executor::visit] \
        [visit::makeequatorialtargetcoordinates $alpha $delta $equinox]]
      executor::track $eastoffset $northoffset "default"
    } else {
      executor::offset $eastoffset $northoffset "default"
    }

    foreach filter $filters {
      executor::movefilterwheel $filter
      set i 0
      while {$i < $exposuresperfilterperdither} {
        if {$first} {
          set alertdelay [alert::delay [executor::alert]]
          log::summary \
            [format "alertvisit: alert delay at start of first exposure is %.1f seconds (%.1f hours)." $alertdelay \
            [expr {$alertdelay / 3600}]]
          log::summary \
            [format "alertvisit: alert coordinates at start of first exposure are %s %s %s." \
            [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]
        }
        executor::expose "object" $exposuretime
        if {false && $first} {
          log::summary "alertvisit: correcting pointing."
          executor::correctpointing 0
          log::summary "alertvisit: finished correcting pointing."
        }
        set first false
        incr i
      }
    }
  }

  set alertdelay [alert::delay [executor::alert]]
  log::summary \
    [format "alertvisit: alert delay after end of last exposure is %.1f seconds (%.1f hours)." $alertdelay \
    [expr {$alertdelay / 3600}]]
  log::summary \
    [format "alertvisit: alert coordinates after end of last exposure are %s %s %s." [astrometry::formatalpha $alpha] \
    [astrometry::formatdelta $delta] $equinox]

  log::summary "alertvisit: finished."

  return false
}

########################################################################
proc gridvisit {gridrepeats gridpoints exposurerepeats exposuretimes filters {offsetfastest true}} {
  log::summary "gridvisit: starting."

  executor::setsecondaryoffset 0

  executor::track

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning "default"

  if {[llength $exposuretimes] == 1} {
    set exposuretimes [lrepeat [llength $filters] $exposuretimes]
  } elseif {[llength $exposuretimes] != [llength $filters]} {
    error "the exposuretimes and filters arguments have different lengths."
  }

  set dithers [lrange {
         0as  0as
        +5as +5as
        -5as -5as
        +5as -5as
        -5as +5as
        +5as  0as
        -5as  0as
         0as +5as
         0as -5as
      } 0 [expr {$gridpoints * 2 - 1}]]

  set gridrepeat 0
  while {$gridrepeat < $gridrepeats} {
    if {$offsetfastest} {
      foreach filter $filters exposuretime $exposuretimes {
        executor::movefilterwheel $filter
        foreach {eastoffset northoffset} $dithers {
          executor::offset $eastoffset $northoffset "default"
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

  set binning 8

  executor::setsecondaryoffset 0

  executor::track

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning $binning
  executor::movefilterwheel "$filter"

  log::summary "coarsefocusvisit: focusing in filter $filter with binning $binning and $exposuretime second exposures."
  executor::focus $exposuretime 500 50 false true
  executor::setfocused

  log::summary "coarsefocusvisit: finished."

  return true
}

########################################################################
proc focusvisit {{exposuretime 5} {filter "i"}} {
  log::summary "focusvisit: starting."

  set binning 2

  executor::setsecondaryoffset 0

  executor::track

  executor::setreadmode "default"
  executor::movefilterwheel $filter
  executor::setbinning $binning
  executor::setwindow "default"

  log::summary "focusvisit: focusing in filter $filter with binning $binning and $exposuretime second exposures."
  executor::focus $exposuretime 150 15 true false
  executor::setfocused

  log::summary "focusvisit: finished."

  return true
}

########################################################################
proc focuswitnessvisit {{exposuretime 5} {filter "i"}} {
  log::summary "focuswitnessvisit: starting."

  set binning 2

  executor::setsecondaryoffset 0

  executor::track

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning $binning

  foreach filter {g r i z y w} {
    log::summary "focuswitnessvisit: taking images in $filter."

    executor::movefilterwheel $filter

    set dithers {
       0as  0as
      +5as +5as
      -5as -5as
      +5as -5as
      -5as +5as
    }

    foreach {eastoffset northoffset} $dithers {
      executor::offset $eastoffset $northoffset "default"
      executor::expose "object" $exposuretime
      executor::analyze "fwhmwitness"
    }
  }

  log::summary "focuswitnessvisit: finished."

  return true
}

########################################################################
proc initialpointingcorrectionvisit {{exposuretime 30} {filter "r"}} {
  log::summary "initialpointingcorrectionvisit: starting."

  set binning 8

  executor::setsecondaryoffset 0

  executor::tracktopocentric

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning $binning
  executor::movefilterwheel $filter

  log::summary "initialpointingcorrectionvisit: correcting pointing."
  executor::correctpointing $exposuretime

  log::summary "initialpointingcorrectionvisit: finished."
  return true
}

########################################################################
proc pointingcorrectionvisit {{exposuretime 15} {filter "r"}} {
  log::summary "correctpointingvisit: starting."

  set binning 2

  executor::setsecondaryoffset 0

  executor::track

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning $binning
  executor::movefilterwheel $filter

  log::summary "correctpointingvisit: correcting pointing."
  executor::correctpointing $exposuretime

  log::summary "correctpointingvisit: finished."
  return true
}

########################################################################
proc donutvisit {{exposuretime 10} {filter "i"}} {
  log::summary "donutvisit: starting."

  set binning 2

  executor::setsecondaryoffset 0

  executor::track

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning $binning
  executor::movefilterwheel $filter

  set n 3

  log::summary "donutvisit: moving focuser to intrafocal position."

  log::summary "donutvisit: taking intrafocal images."
  set i 0
  while {$i < $n} {
    executor::expose object $exposuretime
    incr i
  }

  log::summary "donutvisit: moving focuser to extrafocal position."

  log::summary "donutvisit: taking extrafocal images."
  set i 0
  while {$i < $n} {
    executor::expose object $exposuretime
    incr i
  }

  log::summary "donutvisit: moving focuser to center position."

  log::summary "donutvisit: finished."

  return true
}

########################################################################
proc pointingmapvisit {{exposuretime 5} {filter "r"}} {
  log::summary "pointingmapvisit: starting."

  set binning 3

  executor::setsecondaryoffset 0

  executor::tracktopocentric

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning $binning
  executor::movefilterwheel $filter

  executor::expose object $exposuretime

  log::summary "pointingmapvisit: finished."
  return true
}

########################################################################
proc twilightflatsvisit {targetngood filter} {
  log::summary "twilightflatsvisit: starting."

  executor::setsecondaryoffset 0
  executor::move

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning "default"

  set maxlevel 3000
  set minlevel 1000

  set exposuretime 10

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
    log::summary \
      [format "twilightflatsvisit: $ngood good flats in filter $filter (%.0f to %.0f DN)." $mingoodlevel $maxgoodlevel]
  }

  log::summary "twilightflatsvisit: finished."

  return true
}

########################################################################
proc darksvisit {exposurerepeats exposuretime} {
  log::summary "darksvisit: starting."

  executor::setsecondaryoffset 0

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning "default"

  executor::movefilterwheel "dark"
  set exposure 0
  while {$exposure < $exposurerepeats} {
    executor::expose dark $exposuretime
    executor::analyze levels
    incr exposure
  }

  log::summary "darksvisit: finished."
  return true
}

########################################################################
proc hartmanntestvisit {secondaryoffset {exposuretime 10} {filter "g"} {exposures 10} {dither "20as"}} {
  log::summary "hartmanntestvisit: starting."

  set binning 2

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning $binning
  executor::movefilterwheel $filter

  log::summary "hartmanntestvisit: extrafocal images: secondary offset is +$secondaryoffset."

  executor::setsecondaryoffset +$secondaryoffset
  executor::track

  set dither [astrometry::parseoffset $dither]

  set exposure 0
  while {$exposure < $exposures} {
    set eastoffset [expr {$dither * (rand() - 0.5)}]
    set northoffset [expr {$dither * (rand() - 0.5)}]
    executor::offset $eastoffset $northoffset
    executor::expose object $exposuretime
    incr exposure
  }

  log::summary "hartmanntestvisit: intrafocal images: secondary offset is -$secondaryoffset."

  executor::setsecondaryoffset -$secondaryoffset
  executor::offset

  set exposure 0
  while {$exposure < $exposures} {
    set eastoffset [expr {$dither * (rand() - 0.5)}]
    set northoffset [expr {$dither * (rand() - 0.5)}]
    executor::offset $eastoffset $northoffset
    executor::expose object $exposuretime
    incr exposure
  }

  executor::setsecondaryoffset 0

  log::summary "hartmanntestvisit: finished."

  return true
}
########################################################################
