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

proc alertvisit {{filters ""}} {

  log::summary "alertvisit: starting."

  executor::track
  executor::setwindow "default"
  executor::setbinning 1

  set lastalpha   [alert::alpha [executor::alert]]
  set lastdelta   [alert::delta [executor::alert]]
  set lastequinox [alert::equinox [executor::alert]]

  set i 0
  set first true
  while {$i < 20} {

    if {[file exists [executor::filename]]} {
      executor::setblock [alert::alerttoblock [alert::readalertfile [executor::filename]]]
      executor::setalert [block::alert [executor::block]]
    }

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
      executor::track 0as 0as "default"
      executor::waituntiltracking
    }

    set lastalpha   $alpha
    set lastdelta   $delta
    set lastequinox $equinox

    if {$first} {
      set alertdelay [alert::delay [executor::alert]]
      log::summary [format "alertvisit: alert delay at start of first exposure is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
      log::summary [format "alertvisit: alert coordinates at start of first exposure are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]
      set first false
    }
    executor::expose object 10
    incr i

  }

  set alertdelay [alert::delay [executor::alert]]
  log::summary [format "alertvisit: alert delay after end of last exposure is %.1f seconds (%.1f hours)." $alertdelay [expr {$alertdelay / 3600}]]
  log::summary [format "alertvisit: alert coordinates after end of last exposure are %s %s %s." [astrometry::formatalpha $alpha]  [astrometry::formatdelta $delta] $equinox]

  log::summary "alertvisit: finished."
  return true
}

proc alertprologvisit {} {

  log::summary "alertprologvisit: starting."

  executor::track
  executor::setwindow "default"
  executor::setbinning 1

  executor::expose object 10

  log::summary "alertprologvisit: finished."
  return true
}

########################################################################

proc biasesvisit {} {
  log::summary "biasesvisit: starting."
  executor::move
  executor::setwindow "default"
  executor::setbinning 1
  set i 0
  while {$i < 20} {
    executor::expose bias 0
    executor::analyze levels
    incr i
    coroutine::after 10000
  }
  log::summary "biasesvisit: finished."
  return true
}

########################################################################

proc darksvisit {} {
  log::summary "darksvisit: starting."
  executor::move
  executor::setwindow "default"
  executor::setbinning 1
  set i 0
  while {$i < 20} {
    executor::expose dark 60
    executor::analyze levels
    incr i
    coroutine::after 10000
  }
  log::summary "darksvisit: finished."
  return true
}

########################################################################
