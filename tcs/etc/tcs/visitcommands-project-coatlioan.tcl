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

proc alertvisit {{filters "r"}} {

  log::summary "alertvisit: starting."
  log::summary "alertvisit: filters are $filters."
  
  set alpha   [visit::alpha   [executor::visit]]
  set delta   [visit::delta   [executor::visit]]
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
  log::summary [format "alertvisit: alert delay at start of visit is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
  if {$alertdelay < 1800} {
    set binning            1
    set exposuretime       5
    set exposuresperdither 10
  } else {
    set binning            1
    set exposuretime       15
    set exposuresperdither 4
  }
  set exposuresperfilterperdither [expr {int($exposuresperdither / [llength $filters])}]
  if {$exposuresperfilterperdither == 0} {
    set exposuresperfilterperdither 1
  }
  log::summary [format "alertvisit: taking %.0f second exposures with binning of %d in %s." $exposuretime $binning $filters]
  log::summary [format "alertvisit: taking %d exposures per filter per dither." $exposuresperfilterperdither]
  
  executor::setsecondaryoffset 0
  executor::setguidingmode "none"
  executor::setpointingmode "none"

  executor::track

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning $binning
  executor::movefilterwheel [lindex $filters 0]

  executor::waituntiltracking

  set lastalpha   [alert::alpha [executor::alert]]
  set lastdelta   [alert::delta [executor::alert]]
  set lastequinox [alert::equinox [executor::alert]]
    
  set first true
  foreach {eastoffset northoffset} {
      0as   0as
    +30as +30as
    +30as -30as
    -30as -30as
    -30as +30as
      0as -30as
    +30as   0as
      0as +30as
    -30as   0as
  } {
  
    log::info "alertvisit: dithering $eastoffset E and $northoffset N."    

    set lastalpha       $alpha
    set lastdelta       $delta
    set lastequinox     $equinox
    
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

    set alpha   [alert::alpha [executor::alert]]
    set delta   [alert::delta [executor::alert]]
    set equinox [alert::equinox [executor::alert]]

    if {$alpha != $lastalpha || $delta != $lastdelta || $equinox != $lastequinox} {
      log::summary "alertvisit: the coordinates have been updated."
      log::summary [format "alertvisit: new alert coordinates are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]
      executor::setvisit [visit::updatevisittargetcoordinates [executor::visit] [visit::makeequatorialtargetcoordinates $alpha $delta $equinox]]
      executor::track $eastoffset $northoffset "default"
      executor::waituntiltracking
    } else {
      executor::offset $eastoffset $northoffset "default"
      executor::waituntiltracking
    }

    foreach filter $filters {
      executor::movefilterwheel $filter
      set i 0
      while {$i < $exposuresperfilterperdither} {
        if {$first} {
          set alertdelay [alert::delay [executor::alert]]
          log::summary [format "alertvisit: alert delay at start of first exposure is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
          log::summary [format "alertvisit: alert coordinates at start of first exposure are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]
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
  log::summary [format "alertvisit: alert delay after end of last exposure is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
  log::summary [format "alertvisit: alert coordinates after end of last exposure are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]

  log::summary "alertvisit: finished."

  return false
}

########################################################################

proc gridvisit {gridrepeats gridpoints exposuresperdither exposuretime filters} {

  log::summary "gridvisit: starting."

  executor::setsecondaryoffset 0
  executor::track

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning 1

  executor::waituntiltracking
  
  switch $gridpoints {
    4 {
      set dithers {
        +30as +30as
        -30as -30as
        +30as -30as
        -30as +30as
      }
    }
    5 {
      set dithers {
          0as   0as
        +30as +30as
        -30as -30as
        +30as -30as
        -30as +30as
      }
    }
    8 {
      set dithers {
        +30as +30as
        -30as -30as
        +30as -30as
        -30as +30as
        +30as   0as
        -30as   0as
          0as +30as
          0as -30as
      }
    }
    9 {
      set dithers {
          0as   0as
        +30as +30as
        -30as -30as
        +30as -30as
        -30as +30as
        +30as   0as
        -30as   0as
          0as +30as
          0as -30as
      }
    }
  }

  set gridrepeat 0
  while {$gridrepeat < $gridrepeats} {
    foreach filter $filters {
      executor::movefilterwheel $filter
      foreach {eastoffset northoffset} $dithers {
        executor::offset $eastoffset $northoffset "default"
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

  log::summary "gridvisit: finished."
  return true
}


########################################################################

proc coarsefocusvisit {{filter "i"} {exposuretime 1}} {

  log::summary "coarsefocusvisit: starting."
  
  setsecondaryoffset 0

  track
  setreadmode "default"
  setwindow "default"
  setbinning 4
  movefilterwheel "$filter"
  waituntiltracking
  log::summary "coarsefocusvisit: focusing in filter $filter with $exposuretime second exposures and binning 4."
  focussecondary C0 $exposuretime 500 50 false
  
  log::summary "coarsefocusvisit: finished."

  return true
}

########################################################################

proc focusvisit {{filter "i"} {exposuretime 1}} {

  log::summary "focusvisit: starting."
  track
  setreadmode "default"
  setwindow "default"
  setbinning 1
  movefilterwheel $filter
  waituntiltracking

  log::summary "focusvisit: focusing in filter $filter with $exposuretime second exposures and binning 1."
  focussecondary C0 $exposuretime 100 10 true

  setfocused

  log::summary "focusvisit: finished."

  return true
}

########################################################################

proc initialpointingcorrectionvisit {} {

  set filter       "r"
  set exposuretime 30

  log::summary "initialpointingcorrectionvisit: starting."

  tracktopocentric
  setreadmode "default"
  setwindow "default"
  setbinning 1
  movefilterwheel $filter
  waituntiltracking

  log::summary "initialpointingcorrectionvisit: correcting pointing."
  correctpointing $exposuretime

  log::summary "initialpointingcorrectionvisit: finished."
  return true
}

########################################################################

proc pointingcorrectionvisit {} {

  set filter       "r"
  set exposuretime 5

  log::summary "correctpointingvisit: starting."

  track
  setreadmode "default"
  setwindow "default"
  setbinning 1
  movefilterwheel $filter
  waituntiltracking

  log::summary "correctpointingvisit: correcting pointing."
  correctpointing $exposuretime

  log::summary "correctpointingvisit: finished."
  return true
}

########################################################################

proc donutvisit {} {

  set filter       "i"
  set exposuretime 5

  log::summary "donutvisit: starting."
  setreadmode "default"
  setwindow "default"
  setbinning 1
  movefilterwheel $filter

  setsecondaryoffset +400
  track
  waituntiltracking
  expose object $exposuretime

  setsecondaryoffset -400
  offset
  waituntiltracking
  expose object $exposuretime

  setsecondaryoffset 0

  log::summary "donutvisit: finished."

  return true
}

########################################################################

proc pointingmapvisit {} {

  set filter       "r"
  set exposuretime 5

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

proc twilightflatsvisit {filter targetngood} {

  log::summary "twilightflatsvisit: starting."

  executor::setsecondaryoffset 0
  executor::move

  executor::setreadmode "default"
  executor::setwindow "default"
  executor::setbinning 1

  set maxlevel 16000
  set minlevel 3500
  
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
    log::summary [format "twilightflatsvisit: $ngood good flats with filter $filter."]
  } else {
    log::summary [format "twilightflatsvisit: $ngood good flats with filter $filter (%.0f to %.0f DN)." $mingoodlevel $maxgoodlevel]
  }

  log::summary "twilightflatsvisit: finished."

  return true
}


########################################################################

proc biasesvisit {} {
  log::summary "biasesvisit: starting."
  setsecondaryoffset 0
  move
  movefilterwheel 0
  foreach {readmode binning visitidentifier} {
    "default" 1 0
  } { 
    setreadmode $readmode
    setwindow "default"
    setbinning $binning
    executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
    set i 0
    while {$i < 20} {
      expose bias 0
      analyze levels
      incr i
    }
  }
  log::summary "biasesvisit: finished."
  return true
}

########################################################################

proc darksvisit {} {
  log::summary "darksvisit: starting."
  setsecondaryoffset 0
  move
  movefilterwheel 0
  foreach {readmode binning visitidentifier} {
    "default" 1 0
  } { 
    setreadmode $readmode
    setwindow "default"
    setbinning $binning
    executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
    set i 0
    while {$i < 5} {
      expose dark 60
      analyze levels
      incr i
    }
  }
  log::summary "darksvisit: finished."
  return true
}

########################################################################
