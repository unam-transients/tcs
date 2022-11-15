########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "config"
package require "controller"
package require "client"
package require "log"
package require "coroutine"
package require "server"

package provide "secondaryratiroan" 0.0

# The actual range is more like 0 to 19150, but we want to stay away
# from the limits.

config::setdefaultvalue "secondary" "controllerhost"    "secondary-z"
config::setdefaultvalue "secondary" "controllerport"    "3333"
config::setdefaultvalue "secondary" "minz"              "500"
config::setdefaultvalue "secondary" "maxz"              "18500"
config::setdefaultvalue "secondary" "initialz0"         "6400"
config::setdefaultvalue "secondary" "dztweak"           "+30"
config::setdefaultvalue "secondary" "dzdzenithdistance" "+352.0"
config::setdefaultvalue "secondary" "dzdha"             "-6.5"
config::setdefaultvalue "secondary" "dzddelta"          "-14.0"
config::setdefaultvalue "secondary" "dzdT"              "35.0"
config::setdefaultvalue "secondary" "temperaturesensor" "dome-temperature"
config::setdefaultvalue "secondary" "allowedzerror"     "1"
config::setdefaultvalue "secondary" "zdeadzonewidth"    "5"

namespace eval "secondary" {

  ######################################################################

  variable controllerhost    [config::getvalue "secondary" "controllerhost"   ]
  variable controllerport    [config::getvalue "secondary" "controllerport"   ]
  
  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::statuscommand               ":D00;"
  set controller::timeoutmilliseconds         500
  set controller::intervalmilliseconds        50
  set controller::updatedata                  secondary::updatecontrollerdata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 5

  ######################################################################

  variable settledelayseconds 5

  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    if {[string equal $controllerresponse ""]} {
      return false
    }

    if {[scan $controllerresponse ":D005%4x%1d%1d" z zlowerlimit zupperlimit] != 3} {
      error "invalid controller response \"$controllerresponse\"."
    }

    if {$zlowerlimit} {
      set zlowerlimit true
    } else {
      set zlowerlimit false
    }
    if {$zupperlimit} {
      set zupperlimit true
    } else {
      set zupperlimit false
    }

    if {$z > 32767} {
      set z [expr {$z - 65536}]
    }

    if {[catch {
      expr {$z - [server::getdata "requestedz"]}
    } zerror]} {
      set zerror ""
    }

    set lastz            [server::getdata "z"]
    set stoppedtimestamp [server::getdata "stoppedtimestamp"]
    if {$z != $lastz} {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $timestamp
    }

    variable settledelayseconds
    set settled          [server::getdata "settled"]
    set settledtimestamp [server::getdata "settledtimestamp"]
    if {![string equal $stoppedtimestamp ""] &&
        [utcclock::diff $timestamp $stoppedtimestamp] >= $settledelayseconds} {
      if {!$settled} {
        set settled true
        set settledtimestamp $timestamp
      }
    } else {
      if {$settled} {
        set settled false
        set settledtimestamp $timestamp
      }
    }

    server::setstatus "ok"
    server::setdata "timestamp"        $timestamp
    server::setdata "lastz"            $lastz
    server::setdata "z"                $z
    server::setdata "zlowerlimit"      $zlowerlimit
    server::setdata "zupperlimit"      $zupperlimit
    server::setdata "zerror"           $zerror
    server::setdata "stoppedtimestamp" $stoppedtimestamp
    server::setdata "settled"          $settled
    server::setdata "settledtimestamp" $settledtimestamp

    return true
  }

  proc settle {} {
    log::debug "settling."
    server::setdata "stoppedtimestamp" ""
    server::setdata "lastz"            ""
    server::setdata "settled"          false
    while {![server::getdata "settled"]} {
      coroutine::yield
    }
    log::debug "settled."
  }
  
  ######################################################################
  
  
  proc movehardwaresimple {requestedz} {
    variable minz
    variable maxz
    if {$requestedz < $minz} {
      log::warning "moving to minimum position $minz instead of $requestedz."
      set requestedz $minz
    } elseif {$requestedz > $maxz} {
      log::warning "moving to maximum position $maxz instead of $requestedz."
      set requestedz $maxz
    }
    controller::sendcommand [format ":D045%04X;" $requestedz]
    settle
  }

  proc movehardware {requestedz check} {
    set z [server::getdata "z"]
    log::info "moving from raw position $z to $requestedz."
    stopifnotsettled
    variable zdeadzonewidth
    if {abs($requestedz - $z) <= $zdeadzonewidth} {
      log::info "ignoring the requested move as the requested position is within the deadzone."
      return
    }
    variable dztweak
    if {
      ($dztweak < 0 && $requestedz < $z) ||
      ($dztweak > 0 && $requestedz > $z)
    } {
      log::info "moving first to raw position [expr {$requestedz + $dztweak}] to mitigate backlash."
      movehardwaresimple [expr {$requestedz + $dztweak}]
    }
    log::info "moving to raw position $requestedz."
    movehardwaresimple $requestedz
    if {$check} {
      checkzerror "after moving"
    }
  }
  
  ######################################################################
  
  proc stopifnotsettled {} {
    if {![server::getdata "settled"]} {
      controller::flushcommandqueue
      controller::sendcommand ":D01;"
      settle
    }
  }

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    setrequestedz0 ""
    setrequestedz
    stopifnotsettled
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    variable initialz0
    setrequestedz0 $initialz0
    stopifnotsettled
    # The secondary does not always seem to initialize to the same
    # physical position. To attempt to correct this, we initialize once,
    # then move to 1024 units (0x0400), then initialize again.
    controller::sendcommand ":D02;"
    settle
    controller::sendcommand ":D0450400;"
    settle
    controller::sendcommand ":D02;"
    settle
    setrequestedz
    log::info "moving to corrected position [server::getdata "requestedz0"]."
    movehardware [server::getdata "requestedz"] true
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    stopifnotsettled
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    stopifnotsettled
    set end [utcclock::seconds]
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc moveactivitycommand {check} {
    set start [utcclock::seconds]
    log::info "moving."
    log::info "moving to corrected position [server::getdata "requestedz0"]."
    setrequestedz
    movehardware [server::getdata "requestedz"] $check
    set end [utcclock::seconds]
    log::info [format "finished moving after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

  proc start {} {
    server::setactivity "starting"
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "started" secondary::startactivitycommand
  }
  
}

source [file join [directories::prefix] "lib" "tcs" "secondary.tcl"]
