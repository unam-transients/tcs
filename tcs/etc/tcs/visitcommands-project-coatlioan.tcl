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

  log::summary "alertvisit: starting."
  
  if {[string equal "" [alert::eventtimestamp]]} {
    log::info [format "alertvisit: no event timestamp."]
  } else {  
    log::info [format "alertvisit: event timestamp is %s." [utcclock::format [alert::eventtimestamp]]]
  }
  if {[string equal "" [alert::alerttimestamp]]} {
    log::info [format "alertvisit: no alert timestamp."]
  } else {  
    log::info [format "alertvisit: alert timestamp is %s." [utcclock::format [alert::alerttimestamp]]]
  }
  
  switch -glob [proposal::identifier] {
    *-1002 {
      set filters {"BB" "BR"}
      set binning            2
      set exposuretime       30
      set exposuresperdither 2
    }
    default {
      set filters {"w"}
      set alertdelay [alert::delay]
      log::summary [format "alertvisit: alert delay is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
      if {$alertdelay < 1800} {
        set binning            2
        set exposuretime       5
        set exposuresperdither 10
      } else {
        set binning            2
        set exposuretime       30
        set exposuresperdither 2
      }
    }
  }
  log::summary [format "alertvisit: taking %.0f second exposures with binning of %d in %s." $exposuretime $binning $filters]
  log::summary [format "alertvisit: taking %d exposures per dither." $exposuresperdither]
  
  executor::setsecondaryoffset 0
  executor::track

  executor::setreadmode 1MHz
  executor::setwindow  "default"
  executor::setbinning $binning
  executor::movefilterwheel [lindex $filters 0]

  executor::waituntiltracking
  log::summary [format "alertvisit: correcting pointing."]
  correctpointing 30

  set lastalpha       [visit::alpha]
  set lastdelta       [visit::delta]
  set lastequinox     [visit::equinox]
  set lasteastoffset  [astrometry::parseangle "0as"]
  set lastnorthoffset [astrometry::parseangle "0as"]
    
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

    set eastoffset  [astrometry::parseangle $eastoffset]
    set northoffset [astrometry::parseangle $northoffset]

    if {$alpha != $lastalpha || $delta != $lastdelta || $equinox != $lastequinox} {
      log::summary "alertvisit: the coordinates have been updated."
      executor::track $eastoffset $northoffset "default"
      executor::waituntiltracking
    } elseif {$eastoffset != $lasteastoffset || $northoffset != $lastnorthoffset} {
      executor::offset $eastoffset $northoffset "default"
      executor::waituntiltracking
    }

    set lastalpha       $alpha
    set lastdelta       $delta
    set lastequinox     $equinox
    set lasteastoffset $eastoffset
    set lastnorthoffset $northoffset
    
    foreach filter $filters {
      executor::movefilterwheel $filter
      set i 0
      while {$i < $exposuresperdither} {
        executor::expose "object" $exposuretime
        incr i
      }
    }

  }

  log::summary "alertvisit: finished."

  return false
}

########################################################################

proc gridvisit {gridrepeats gridpoints exposuresperdither exposuretime filters} {

  log::summary "gridvisit: starting."

  executor::setsecondaryoffset 0
  executor::track

  executor::setreadmode 1MHz
  executor::setwindow "default"
  executor::setbinning 2

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
    foreach {eastoffset northoffset} $dithers {
      executor::offset $eastoffset $northoffset "default"
      executor::waituntiltracking
      foreach filter $filters {
        executor::movefilterwheel $filter
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

proc initialfocusvisit {} {

  log::summary "initialfocusvisit: starting."
  
  set focusfilter BI
  set correctpointingfilter w

  setsecondaryoffset 0

  log::summary "initialfocusvisit: moving to brighter star."
  track
#  setreadmode 6MHz
  setwindow "default"
  setbinning 4
#  movefilterwheel "$focusfilter"
  waituntiltracking
  log::summary "initialfocusvisit: focusing with binning 4."
  focussecondary C0 1 500 50 false
  
}

proc initialpointingcorrectionvisit {} {

  log::summary "initialpointingcorrectionvisit: moving to fainter star."
  track
  setwindow "default"
  setbinning 1
#  movefilterwheel "$focusfilter"
  waituntiltracking
  correctpointing 10

  log::summary "initialpointingcorrectionvisit: finished."

  return false
}

proc focusvisit {} {

  log::summary "initialfocusvisit: moving to fainter star."
  track
#  setreadmode 6MHz
#  setwindow "1kx1k"
  setbinning 1
#  movefilterwheel "$focusfilter"
  waituntiltracking
  log::summary "initialfocusvisit: focusing with binning 1."
  focussecondary C0 1 100 10 true

  setfocused

  log::summary "initialfocusvisit: finished."

  return false
}

########################################################################

proc donutvisit {} {

  log::summary "donutvisit: starting."

  setsecondaryoffset +600
  track

  setreadmode 6MHz
  setbinning 1
  movefilterwheel "$focusfilter"

  waituntiltracking
  expose object 5

  setsecondaryoffset +400
  offset
  waituntiltracking
  expose object 5

  setsecondaryoffset +200
  offset
  waituntiltracking
  expose object 5

  setsecondaryoffset -200
  offset
  waituntiltracking
  expose object 5

  setsecondaryoffset -400
  offset
  waituntiltracking
  expose object 5

  setsecondaryoffset -600
  offset
  waituntiltracking
  expose object 5

  log::summary "donutvisit: finished."

  return true
}

########################################################################

proc pointingmapvisit {} {

  log::summary "pointingmapvisit: starting."

  setsecondaryoffset 0
  tracktopocentric

  setwindow "default"
  setbinning 1

  waituntiltracking

  expose object 10

  log::summary "pointingmapvisit: finished."
  return true
}

########################################################################

proc twilightflatsvisit {} {

  log::summary "twilightflatsvisit: starting."

  setsecondaryoffset 0
  move

  setreadmode 6MHz
  setwindow "default"
  setbinning 1
  
  set maxlevel 7000
  set minlevel 2000
  set targetlevel 4000
  
  set minexposuretime 10
  set maxexposuretime 20

#    "BV" 2 7
#    "BI" 4 7
#    "BR" 3 7
#    "BB" 1 7
#    "w"  0 15
  foreach {filter visitidentifier targetngood} {
    "BV" 2 7
    "BI" 4 7
    "BB" 1 7
    "BR" 3 7
    "w"  0 15
  } {
    log::info "twilightflatsvisit: starting with filter $filter."
    visit::setidentifier $visitidentifier
    movefilterwheel $filter
    set exposuretime $minexposuretime
    set ngood 0
    set mingoodlevel $maxlevel
    set maxgoodlevel $minlevel
    while {true} {
      expose flat $exposuretime
      analyze levels
      set level [exposureaverage C0]
      log::info [format "twilightflatsvisit: level is %.1f DN in filter $filter in $exposuretime seconds." $level]
      if {$level > $maxlevel} {
        log::info "twilightflatsvisit: level is too bright."
      } elseif {$level < $minlevel} {
        log::info "twilightflatsvisit: level is too faint."
        if {$exposuretime == $maxexposuretime} {
          break
        }
      } else {
        log::info "twilightflatsvisit: level is good."
        incr ngood
        set mingoodlevel [expr {min($level,$mingoodlevel)}]
        set maxgoodlevel [expr {max($level,$maxgoodlevel)}]
        if {$ngood == $targetngood} {
          break
        }
      }
      set exposuretime [expr {min($maxexposuretime,max($minexposuretime,int($exposuretime * $targetlevel / $level)))}]
    }
    log::info "twilightflatsvisit: finished with filter $filter."
    if {$ngood == 0} {
      log::summary [format "twilightflatsvisit: $ngood good flats with filter $filter."]
    } else {
      log::summary [format "twilightflatsvisit: $ngood good flats with filter $filter (%.0f to %.0f DN)." $mingoodlevel $maxgoodlevel]
    }
  }

  log::summary "twilightflatsvisit: finished."

  return true
}

########################################################################

proc biasesvisit {} {
  log::summary "biasesvisit: starting."
  setsecondaryoffset 0
  move
  movefilterwheel "w" 
  foreach {readmode binning visitidentifier} {
    1MHz 1 0
    1MHz 2 1
    6MHz 1 2
    6MHz 2 3
  } { 
    setreadmode $readmode
    setwindow "default"
    setbinning $binning
    visit::setidentifier $visitidentifier
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
  movefilterwheel "w" 
  foreach {readmode binning visitidentifier} {
    1MHz 1 0
    1MHz 2 1
    6MHz 1 2
    6MHz 2 3
  } { 
    setreadmode $readmode
    setwindow "default"
    setbinning $binning
    visit::setidentifier $visitidentifier
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

proc skybrightnessvisit {} {
  log::summary "skybrightnessvisit: starting."
  executor::setsecondaryoffset 0
  executor::tracktopocentric
  executor::setreadmode 1MHz
  executor::setwindow "default"
  executor::setbinning 2
  executor::movefilterwheel "w"
  executor::waituntiltracking
  foreach {filter exposuretime visitidentifier} {
    "w"  10 0
    "BB" 30 1
    "BV" 30 2
    "BR" 30 3
    "BI" 30 4
  } {
    executor::movefilterwheel $filter
    visit::setidentifier $visitidentifier
    executor::expose object $exposuretime
  }
  log::summary "skybrightnessvisit: finished."  
  return true
}
