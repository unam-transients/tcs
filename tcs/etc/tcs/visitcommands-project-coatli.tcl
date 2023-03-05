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

proc alertvisit {{filters "r"} {readmode "conventionaldefault"}} {

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
    set exposuretime       15
    set exposuresperdither 4
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

  executor::track

  executor::movefocuser "center"
  executor::setreadmode $readmode
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

proc gridvisit {gridrepeats gridpoints exposurerepeats exposuretimes filters {offsetfastest true} {readmode "conventionaldefault"}} {

  log::summary "gridvisit: starting."

  executor::setsecondaryoffset 0

  executor::track

  executor::movefocuser "center"
  executor::setreadmode $readmode
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
        +10as +10as
        -10as -10as
        +10as -10as
        -10as +10as
        +10as   0as
        -10as   0as
          0as +10as
          0as -10as
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

proc coarsefocussecondaryvisit {{exposuretime 5} {filter "i"} {readmode "conventionaldefault"}} {

  log::summary "coarsefocussecondaryvisit: starting."
  
  setsecondaryoffset 0
  
  track

  executor::movefocuser "center"
  setreadmode $readmode
  setwindow "default"
  setbinning 2
  movefilterwheel "$filter"

  waituntiltracking

  log::summary "coarsefocussecondaryvisit: focusing in filter $filter with $exposuretime second exposures and binning 2."
  focussecondary C0 $exposuretime 300 30 false true
  executor::setfocused
  
  log::summary "coarsefocussecondaryvisit: finished."

  return true
}

########################################################################

proc focussecondaryvisit {{exposuretime 5} {filter "i"} {readmode "fastguidingdefault"}} {

  log::summary "focussecondaryvisit: starting."

  setsecondaryoffset 0

  track

  executor::movefocuser "center"
  setreadmode $readmode
  setwindow "default"
  setbinning 1
  movefilterwheel $filter

  waituntiltracking

  log::summary "focussecondaryvisit: focusing in filter $filter with $exposuretime second exposures and binning 1."
  log::summary "focussecondaryvisit: readmode is $readmode."
  focussecondary C0 $exposuretime 100 10 true false
  executor::setfocused
  
  log::summary "focussecondaryvisit: finished."

  return true
}

########################################################################

proc focuswitnessvisit {{exposuretime 5} {filter "i"} {readmode "fastguidingdefault"}} {

  log::summary "focuswitnessvisit: starting."

  executor::setsecondaryoffset 0

  executor::track

  executor::movefocuser "center"
  executor::setreadmode $readmode
  executor::setwindow "default"
  executor::movefilterwheel $filter
  executor::setbinning 1

  executor::waituntiltracking
  
  foreach filter {g r i z y w} {
  
   log::summary "focuswitnessvisit: taking images in $filter."

  
    movefilterwheel $filter

    set dithers {
        0as   0as
      +10as +10as
      -10as -10as
      +10as -10as
      -10as +10as
    }

    foreach {eastoffset northoffset} $dithers {
      executor::offset $eastoffset $northoffset "default"
      executor::waituntiltracking
      executor::expose object $exposuretime
      executor::focuswitness
    }
    
  }

  log::summary "focuswitnessvisit: finished."

  return true
}

########################################################################

proc coarsefocusvisit {{exposuretime 5} {filter "i"} {readmode "conventionaldefault"}} {

  log::summary "coarsefocusvisit: starting."

  executor::setsecondaryoffset 0

  track

  setreadmode $readmode
  setwindow "default"
  setbinning 2
  movefilterwheel $filter

  waituntiltracking

  executor::focus $exposuretime 100000 10000 true true
  executor::setfocused

  log::summary "coarsefocusvisit: finished."
  return false
}

########################################################################

proc focusvisit {{exposuretime 5} {filter "i"} {readmode "fastguidingdefault"}} {

  log::summary "focusvisit: starting."

  executor::setsecondaryoffset 0

  track

  setreadmode $readmode
  setwindow "default"
  setbinning 1
  movefilterwheel $filter

  waituntiltracking

  executor::focus $exposuretime 60000 6000 true false
  executor::setfocused

  log::summary "focusvisit: finished."
  return false
}

########################################################################

proc initialpointingcorrectionvisit {{exposuretime 30} {filter "i"} {readmode "conventionaldefault"}} {

  log::summary "initialpointingcorrectionvisit: starting."

  executor::setsecondaryoffset 0

  tracktopocentric

  executor::movefocuser "center"
  setreadmode $readmode
  setwindow "default"
  setbinning 2
  movefilterwheel $filter

  waituntiltracking

  log::summary "initialpointingcorrectionvisit: correcting pointing."
  correctpointing $exposuretime

  log::summary "initialpointingcorrectionvisit: finished."
  return true
}

########################################################################

proc pointingcorrectionvisit {{exposuretime 15} {filter "i"} {readmode "conventionaldefault"}} {

  log::summary "correctpointingvisit: starting."

  executor::setsecondaryoffset 0

  track

  executor::movefocuser "center"
  setreadmode $readmode
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

proc donutvisit {{exposuretime 10} {filter "i"}} {

  log::summary "donutvisit: starting."

  executor::setsecondaryoffset 0

  track

  setreadmode "conventionaldefault"
  setwindow "default"
  setbinning 1
  movefilterwheel $filter

  waituntiltracking
  
  set n 3

  log::summary "donutvisit: moving focuser to intrafocal position."
  executor::movefocuser "minimum"

  log::summary "donutvisit: taking intrafocal images."
  set i 0
  while {$i < $n} { 
    expose object $exposuretime
    incr i
  }
  
  log::summary "donutvisit: moving focuser to extrafocal position."
  executor::movefocuser "maximum"

  log::summary "donutvisit: taking extrafocal images."
  set i 0
  while {$i < $n} { 
    expose object $exposuretime
    incr i
  }

  log::summary "donutvisit: moving focuser to center position."
  executor::movefocuser "center"

  log::summary "donutvisit: finished."

  return true
}

########################################################################

proc pointingmapvisit {{exposuretime 5} {filter "i"} {readmode "conventionaldefault"}} {

  log::summary "pointingmapvisit: starting."

  setsecondaryoffset 0

  tracktopocentric

  executor::movefocuser "center"
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

proc twilightflatsvisit {targetngood filter} {

  log::summary "twilightflatsvisit: starting."

  executor::setsecondaryoffset 0

  executor::move

  executor::movefocuser "center"
  executor::setreadmode "conventionaldefault"
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
    log::summary [format "twilightflatsvisit: $ngood good flats in filter $filter."]
  } else {
    log::summary [format "twilightflatsvisit: $ngood good flats in filter $filter (%.0f to %.0f DN)." $mingoodlevel $maxgoodlevel]
  }

  log::summary "twilightflatsvisit: finished."

  return true
}

########################################################################

proc domeflatsvisit {} {

  log::summary "domeflatsvisit: starting."

  executor::setsecondaryoffset 0

  if {[executor::isunparked]} {
    executor::move
  }

  executor::movefocuser "center"
  executor::setreadmode "conventionaldefault"
  executor::setwindow "default"
  executor::setbinning 1

  set maxlevel 16000
  set minlevel 3500
  set exposuretime 10
  set filter "i"
  executor::movefilterwheel $filter
  set isevening [executor::isevening]  
  if {$isevening} {
    set visits {
     "1MHz-low"  0
     "1MHz-high" 1
    }
  } else { 
    set visits {
     "1MHz-high" 1
     "1MHz-low"  0
    }
  }
  foreach {readmode visitidentifier} $visits { 
    executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
    set ngood 0
    set mingoodlevel $maxlevel
    set maxgoodlevel $minlevel
    executor::setreadmode $readmode
    log::info [format "domeflatsvisit: starting flats in readmode $readmode."]
    while {true} {
      executor::expose flat $exposuretime
      executor::analyze levels
      set level [executor::exposureaverage C0]
      log::info [format "domeflatsvisit: level is %.1f DN." $level]
      if {$level > $maxlevel && $isevening} {
        log::info "domeflatsvisit: waiting (too bright)."
        coroutine::after 60000
      } elseif {$level < $minlevel && !$isevening} {
        log::info "domeflatsvisit: waiting (too faint)."
        coroutine::after 60000
      } elseif {$minlevel <= $level && $level <= $maxlevel} {
        if {$ngood == 0} {
          log::info "domeflatsvisit: first good flat in readmode $readmode."
        }
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
      log::summary [format "domeflatsvisit: $ngood good flats in readmode $readmode."]
    } else {
      log::summary [format "domeflatsvisit: $ngood good flats in readmode $readmode (%.0f to %.0f DN)." $mingoodlevel $maxgoodlevel]
    }
  }
  log::summary "domeflatsvisit: finished."
  return true
}

########################################################################

proc biasesvisit {} {
  log::summary "biasesvisit: starting."

  setsecondaryoffset 0

  if {[executor::isunparked]} {
    executor::move
  }

  executor::movefocuser "center"
  movefilterwheel "dark"

  foreach {readmode binning visitidentifier} {
     "1MHz-low"  1 0
     "1MHz-high" 1 1
  } { 
    setreadmode $readmode
    setwindow "default"
    setbinning $binning
    executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
    set i 0
    while {$i < 10} {
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

  executor::movefocuser "center"
  movefilterwheel "dark"

  foreach {readmode binning visitidentifier} {
     "1MHz-low"         1 0
     "1MHz-high"        1 1
     "em-10MHz-low"     1 2
     "em-10MHz-high"    1 3
     "em-20MHz-low"     1 4
     "em-20MHz-high"    1 5
     "em-30MHz-low"     1 6
     "em-30MHz-high"    1 7
     "em-10MHz-low-100" 1 8
     "em-20MHz-low-100" 1 9
     "em-30MHz-low-100" 1 10
  } { 
    setreadmode $readmode
    setwindow "default"
    setbinning $binning
    executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
    set i 0
    while {$i < 5} {
      expose dark 15
      analyze levels
      incr i
    }
  }
  log::summary "darksvisit: finished."
  return true
}

########################################################################

proc gainvisit {} {
  log::summary "gainvisit: starting."

  setsecondaryoffset 0

  move

  executor::movefocuser "center"
  
#     "1MHz-0"     1 0 "656/3"  0.1
#     "1MHz-1"     1 1 "656/3"  0.1
#     "em-10MHz-0" 1 2 "656/3"  1
#     "em-10MHz-1" 1 3 "656/3"  1
#     "em-20MHz-0" 1 4 "640/10" 1
#     "em-20MHz-1" 1 5 "640/10" 1
#     "em-30MHz-0" 1 6 "640/10" 1
#     "em-30MHz-1" 1 7 "640/10" 1
  foreach {readmode binning visitidentifier filter exposuretime} {
    "em-30MHz-0" 1 6 "z" 1
  } { 
    movefilterwheel $filter
    setreadmode $readmode
    setwindow "default"
    setbinning $binning
    executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
    set i 0
    while {$i < 6} {
      expose flat $exposuretime
      analyze levels
      coroutine::after 1000
      incr i
    }
  }
  log::summary "gainvisit: finished."
  return true
}

########################################################################

proc readnoisevisit {} {
  log::summary "readnoisevisit: starting."

  setsecondaryoffset 0

  move

  executor::movefocuser "center"
  movefilterwheel "dark"

#     "em-10MHz-0" 1 2 0
#     "em-10MHz-1" 1 3 0
#     "em-20MHz-0" 1 4 0
#     "em-20MHz-1" 1 5 0
#     "em-30MHz-0" 1 6 0
#     "em-30MHz-1" 1 7 0
  foreach {readmode binning visitidentifier exposuretime} {
     "1MHz-0"     1 0 0
     "1MHz-1"     1 1 0

  } { 
    setreadmode $readmode
    setwindow "default"
    setbinning $binning
    executor::setvisit [visit::updatevisitidentifier [executor::visit] $visitidentifier]
    set i 0
    while {$i < 6} {
      expose bias $exposuretime
      analyze levels
      coroutine::after 1000
      incr i
    }
  }
  log::summary "readnoisevisit: finished."
  return true
}

########################################################################

proc hartmanntestvisit {secondaryoffset {exposuretime 10} {filter "470/10"} {exposures 10} {dither "20as"}} {

  log::summary "hartmanntestvisit: starting."

  executor::setwindow "default"
  executor::setbinning 4
  executor::movefilterwheel $filter
  executor::movefocuser "center"

  log::summary "hartmanntestvisit: extrafocal images: secondary offset is +$secondaryoffset."


  executor::setsecondaryoffset +$secondaryoffset
  executor::track
  executor::waituntiltracking
  
  set dither [astrometry::parseoffset $dither]
  
  set exposure 0
  while {$exposure < $exposures} {
    set eastoffset [expr {$dither * (rand() - 0.5)}]
    set northoffset [expr {$dither * (rand() - 0.5)}]
    executor::offset $eastoffset $northoffset
    executor::waituntiltracking
    executor::expose object $exposuretime
    incr exposure
  }
  
  log::summary "hartmanntestvisit: intrafocal images: secondary offset is -$secondaryoffset."

  executor::setsecondaryoffset -$secondaryoffset
  executor::offset
  executor::waituntiltracking

  set exposure 0
  while {$exposure < $exposures} {
    set eastoffset [expr {$dither * (rand() - 0.5)}]
    set northoffset [expr {$dither * (rand() - 0.5)}]
    executor::offset $eastoffset $northoffset
    executor::waituntiltracking
    executor::expose object $exposuretime
    incr exposure
  }

  executor::setsecondaryoffset 0

  log::summary "hartmanntestvisit: finished."
  

  return true
}

########################################################################

proc satellitevisit {start exposures exposuretime} {

  log::summary "satellitevisit: starting."

  executor::setsecondaryoffset 0

  executor::track

  executor::movefocuser "center"
  executor::movefilterwheel "g"
  executor::setreadmode "conventionaldefault"
  executor::setwindow "default"
  executor::setbinning 1
  executor::waituntiltracking
  
  log::summary "satellitevisit: waiting until $start."
  
  set startseconds [utcclock::scan $start]
  while {[utcclock::seconds] <= $startseconds} {
    coroutine::after 100
  }

  log::summary "satellitevisit: starting exposures."

  set exposure 0
  while {$exposure < $exposures} {
    executor::expose object $exposuretime
    incr exposure
  }

  log::summary "satellitevisit: finished exposures."

  log::summary "satellitevisit: finished."
  return true
}

########################################################################


