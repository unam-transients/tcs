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
  
  variable blockfile
  variable alertfile
  
  set block [alert::readfile $blockfile $alertfile]
  set alert [block::alert $block]
  
  if {[string equal "" [alert::eventtimestamp $alert]]} {
    log::info [format "alertvisit: no event timestamp."]
  } else {  
    log::info [format "alertvisit: event timestamp is %s." [utcclock::format [alert::eventtimestamp $alert]]]
  }
  if {[string equal "" [alert::alerttimestamp $alert]]} {
    log::info [format "alertvisit: no alert timestamp."]
  } else {  
    log::info [format "alertvisit: alert timestamp is %s." [utcclock::format [alert::alerttimestamp $alert]]]
  }
  
  set alertdelay [alert::delay $alert]
  log::summary [format "alertvisit: alert delay is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
  set exposuretime       60
  set exposuresperdither 1
  
  executor::setsecondaryoffset 0
  executor::setguidingmode "none"
  executor::setpointingmode "finder"

  executor::track

  executor::setwindow  "default"
  executor::setbinning 2 2 1 1
  executor::movefilterwheel [lindex $filters 0] "none" "none" "none"

  executor::waituntiltracking

  set lastalpha       [alert::alpha $alert]
  set lastdelta       [alert::delta $alert]
  set lastequinox     [alert::equinox $alert]
  set lasteastoffset  [astrometry::parseangle "0as"]
  set lastnorthoffset [astrometry::parseangle "0as"]
  set lastaperture    "default"
  
  set exposuretype firstalertobject
  
  foreach {aperture eastoffset northoffset} {
    riZJcenter -10as -30as
    riYHcenter -10as -30as
    riYHcenter -10as   0as
    riZJcenter -10as   0as
    riZJcenter -10as +30as
    riYHcenter -10as +30as
    riYHcenter  +0as -15as
    riZJcenter  +0as -15as
    riZJcenter  +0as +15as
    riYHcenter  +0as +15as
    riYHcenter +10as -30as
    riZJcenter +10as -30as
    riZJcenter +10as   0as
    riYHcenter +10as   0as
    riYHcenter +10as +30as
    riZJcenter +10as +30as
  } {
  
    log::info "alertvisit: dithering $eastoffset E and $northoffset N about aperture $aperture."    

    if {[file exists $alertfile]} {
      set block [alert::readfile $blockfile $alertfile]
      set alert [block::alert $block]
    }

    if {![alert::enabled $alert]} {
      log::summary "alertvisit: the alert is no longer enabled."
      return false
    }

    set alpha   [alert::alpha $alert]
    set delta   [alert::delta $alert]
    set equinox [alert::equinox $alert]

    set eastoffset  [astrometry::parseangle $eastoffset]
    set northoffset [astrometry::parseangle $northoffset]

    if {$alpha != $lastalpha || $delta != $lastdelta || $equinox != $lastequinox} {
      log::summary "alertvisit: the coordinates have been updated."
      executor::track $eastoffset $northoffset $aperture
      executor::waituntiltracking
    } elseif {$eastoffset != $lasteastoffset || $northoffset != $lastnorthoffset || ![string equal $aperture $lastaperture]} {
      executor::offset $eastoffset $northoffset $aperture
      executor::waituntiltracking
    }

    set lastalpha       $alpha
    set lastdelta       $delta
    set lastequinox     $equinox
    set lasteastoffset  $eastoffset
    set lastnorthoffset $northoffset
    set lastaperture    $aperture
    
    foreach filter $filters {
      executor::movefilterwheel $filter "none" "none" "none"
      set i 0
      while {$i < $exposuresperdither} {
        executor::expose $exposuretype 80 80 60 60
        set exposuretype object
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
  executor::setbinning 2 2 1 1

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
  
  executor::setsecondaryoffset 0
  
  executor::setguidingmode "none"
  executor::setpointingmode "none"

  executor::track
  executor::waituntiltracking
  
  log::summary "initialfocusvisit: focusing finders."
  executor::focusfinders 1

  executor::setpointingmode "finder"
  
  executor::track
  executor::waituntiltracking
  executor::setwindow "default"
  executor::setbinning 8 8 1 1
  log::summary "initialfocusvisit: focusing C1 with binning 8."
  executor::focussecondary C1 1 1000 100 false

  log::summary "initialfocusvisit: finished."

  return false
}

########################################################################

proc initialpointingcorrectionvisit {} {

  log::summary "initialpointingcorrectionvisit: starting."

  executor::setpointingmode "finder"

  executor::track
  executor::waituntiltracking

  log::summary "initialpointingcorrectionvisit: correcting pointing."
  executor::correctpointing 30

  log::summary "initialpointingcorrectionvisit: finished."

  return false
}

########################################################################

proc focusvisit {} {

  log::summary "focusvisit: starting."

  executor::setsecondaryoffset 0
  executor::setguidingmode "none"
  executor::setpointingmode "finder"

  executor::track
  executor::setwindow "default"
  executor::setbinning 4 4 1 1
  executor::waituntiltracking
  log::summary "focusvisit: focusing with binning 4."
  executor::focussecondary C1 1 500 50 false
  executor::setbinning 2 2 1 1
  log::summary "focusvisit: focusing with binning 2."
  executor::focussecondary C1 4 250 25 true
  executor::setfocused

  log::summary "focusvisit: finished."
  return false
}

########################################################################

proc twilightflatsbrightvisit {filter targetngood} {

  log::summary "twilightflatsbrightvisit: starting."

  executor::setsecondaryoffset 0
  executor::move

  set maxlevel 20000
  set minlevel 5000
  
  set exposuretime 10

  log::info "twilightflatsbrightvisit: filter $filter."
  executor::movefilterwheel $filter "none" "none" "none"

  set ngood 0
  set mingoodlevel $maxlevel
  set maxgoodlevel $minlevel
  while {true} {
    executor::expose flat $exposuretime
    executor::analyze levels "none" "none" "none"
    set level [executor::exposureaverage C0]
    log::info [format "twilightflatsbrightvisit: level is %.1f DN in filter $filter in $exposuretime seconds." $level]
    if {$level > $maxlevel} {
      log::info "twilightflatsbrightvisit: level is too bright."
    } elseif {$level < $minlevel} {
      log::info "twilightflatsbrightvisit: level is too faint."
      break
    } else {
      log::info "twilightflatsbrightvisit: level is good."
      incr ngood
      set mingoodlevel [expr {min($level,$mingoodlevel)}]
      set maxgoodlevel [expr {max($level,$maxgoodlevel)}]
      if {$ngood == $targetngood} {
        break
      }
    }
  }

  if {$ngood == 0} {
    log::summary [format "twilightflatsbrightvisit: $ngood good flats with filter $filter."]
  } else {
    log::summary [format "twilightflatsbrightvisit: $ngood good flats with filter $filter (%.0f to %.0f DN)." $mingoodlevel $maxgoodlevel]
  }

  log::summary "twilightflatsbrightvisit: finished."

  return true
}

########################################################################

proc twilightflatsfaintvisit {} {
  log::summary "twilightflatsfaintvisit: starting."
  executor::setsecondaryoffset 0
  executor::move
  executor::movefilterwheel "r" "none" "none" "none"
  set i 0
  while {$i < 20} {
    executor::expose flat "none" "none" 10 10
    incr i
  }
  log::summary "twilightflatsfaintvisit: finished."
  return true
}

########################################################################

proc biasesvisit {} {
  log::summary "biasesvisit: starting."
  executor::setsecondaryoffset 0
  executor::move
  executor::movefilterwheel "r" "none" "none" "none"
  set i 0
  while {$i < 20} {
    executor::expose bias 0 0 "none" "none"
    incr i
  }
  log::summary "biasesvisit: finished."
  return true
}

########################################################################

proc darksvisit {} {
  log::summary "darksvisit: starting."
  executor::setsecondaryoffset 0
  executor::move
  executor::movefilterwheel "r" "none" "none" "none"
  set i 0
  while {$i < 20} {
    executor::expose dark 60 60 none none
    incr i
  }
  log::summary "darksvisit: finished."
  return true
}

########################################################################
