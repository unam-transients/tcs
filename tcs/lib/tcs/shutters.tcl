########################################################################

# This file is part of the UNAM telescope control system.

# $Id: shutters.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "log"
package require "server"

package provide "shutters" 0.0

config::setdefaultvalue "shutters" "controllerhost" "shutters"
config::setdefaultvalue "shutters" "controllerport" "3333"

namespace eval "shutters" {

  variable svnid {$Id}

  ######################################################################

  variable controllerhost [config::getvalue "shutters" "controllerhost"]
  variable controllerport [config::getvalue "shutters" "controllerport"]

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::statuscommand               "ESTADO;\n"
  set controller::timeoutmilliseconds         500
  set controller::intervalmilliseconds        500
  set controller::updatedata                  shutters::updatecontrollerdata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 5

  ######################################################################

  server::setdata "uppershutter" ""
  server::setdata "lowershutter" ""
  server::setdata "lastuppershutter" ""
  server::setdata "lastlowershutter" ""
  server::setdata "timestamp"    ""
  server::setdata "stoppedtimestamp" ""

  variable settledelayseconds 3

  proc isignoredcontrollerresponseresponse {response} {
    switch -- $response {
      "OK;" -
      "NO POSICION;" {
        return true
      }
      default {
        return false
      }
    }
  }

  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    set controllerresponse [string trim $controllerresponse]
    if {[isignoredcontrollerresponseresponse $controllerresponse]} {
      return false
    }

    if {
      [scan $controllerresponse "%d %d %d %d %d;" powercontacts uppershutter lowershutter lights other] != 5 &&
      [scan $controllerresponse "%*c%d %d %d %d %d;" powercontacts uppershutter lowershutter lights other] != 5
    } {
      error "invalid response: \"$controllerresponse\"."
    }

    switch -- $powercontacts {
      0 { set powercontacts "open" }
      1 { set powercontacts "closed" }
    }

    switch -- $uppershutter {
      0 { set uppershutter "closed" }
      1 { set uppershutter "intermediate" }
      2 { set uppershutter "open" }
      3 { set uppershutter "error" }
    }

    switch -- $lowershutter {
      0 { set lowershutter "closed" }
      1 { set lowershutter "intermediate" }
      2 { set lowershutter "open" }
      3 { set lowershutter "error" }
    }
    
    set lasttimestamp    [server::getdata "timestamp"]
    set lastuppershutter [server::getdata "uppershutter"]
    set lastlowershutter [server::getdata "lowershutter"]
    set stoppedtimestamp [server::getdata "stoppedtimestamp"]

    if {![string equal $uppershutter $lastuppershutter] || [string equal $uppershutter "intermediate"]} {
      set stoppedtimestamp ""
    } elseif {![string equal $lowershutter $lastlowershutter] || [string equal $lowershutter "intermediate"]} {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $lasttimestamp
    }
    variable settledelayseconds
    if {![string equal $stoppedtimestamp ""] &&
        [utcclock::diff $timestamp $stoppedtimestamp] >= $settledelayseconds} {
      set settled true
    } else {
      set settled false
    }

    server::setstatus "ok"
    server::setdata "timestamp"        $timestamp
    server::setdata "lasttimestamp"    $lasttimestamp
    server::setdata "powercontacts"    $powercontacts
    server::setdata "uppershutter"     $uppershutter
    server::setdata "lastuppershutter" $lastuppershutter
    server::setdata "lowershutter"     $lowershutter
    server::setdata "lastlowershutter" $lastlowershutter
    server::setdata "stoppedtimestamp" $stoppedtimestamp
    server::setdata "settled"          $settled
    
    return true
  }

  ######################################################################
  
  proc setrequestedshutters {shutters} {
    server::setdata "requestedshutters" $shutters
  }
  
  proc checkshutters {} {
    if {![string equal [server::getdata "lowershutter"] [server::getdata "requestedshutters"]]} {
      if {[string equal [server::getdata "requestedshutters"] "open"]} {
        error "the lower shutter did not open."
      } else {
        error "the lower shutter did not close."
      }
    }
    if {![string equal [server::getdata "uppershutter"] [server::getdata "requestedshutters"]]} {
      if {[string equal [server::getdata "requestedshutters"] "open"]} {
        error "the upper shutter did not open."
      } else {
        error "the upper shutter did not close."
      }
    }
  }
  
  proc settle {} {
    log::debug "settling."
    server::setdata "stoppedtimestamp" ""
    server::setdata "lastuppershutter" ""
    server::setdata "lastlowershutter" ""
    server::setdata "settled"          false
    while {![server::getdata "settled"]} {
      coroutine::yield
    }
    log::debug "settled."
  }
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    setrequestedshutters ""
    controller::sendcommand "STOP;\n"
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    setrequestedshutters "closed"
    controller::sendcommand "ACORTINA CIERRA_TODO;\n"
    settle
    checkshutters
    log::info [format "finished initialzing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    setrequestedshutters ""
    if {![catch {checkpowercontacts}]} {
      controller::flushcommandqueue
      controller::sendcommand "STOP;\n"
    }
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff now $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    setrequestedshutters ""
    if {![catch {checkpowercontacts}]} {
      controller::flushcommandqueue
      controller::sendcommand "STOP;\n"
    }
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff now $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    setrequestedshutters "open"
    controller::sendcommand "ACORTINA ABRE_TODO;\n"
    settle
    checkshutters
    log::info [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    setrequestedshutters "closed"
    controller::sendcommand "ACORTINA CIERRA_TODO;\n"
    settle
    checkshutters
    log::info [format "finished closing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc emergencycloseactivitycommand {} {
    set start [utcclock::seconds]
    log::warning "emergency closing."
    setrequestedshutters "closed"
    controller::sendcommand "ACORTINA CIERRA_TODO;\n"
    settle
    checkshutters
    log::warning [format "finished emergency closing after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################
  
  proc checkpowercontacts {} {
    if {![string equal [server::getdata "powercontacts"] "closed"]} {
      error "the power contacts are not closed."
    }
  }

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    checkpowercontacts
    server::newactivitycommand "initializing" "idle" shutters::initializeactivitycommand
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] shutters::stopactivitycommand
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] shutters::resetactivitycommand
  }

  proc open {} {
    server::checkstatus
    server::checkactivityformove
    checkpowercontacts
    server::newactivitycommand "opening" "idle" shutters::openactivitycommand
  }

  proc close {} {
    server::checkstatus
    server::checkactivityformove
    checkpowercontacts
    server::newactivitycommand "closing" "idle" shutters::closeactivitycommand
  }

  proc emergencyclose {} {
    server::newactivitycommand "closing" [server::getstoppedactivity] shutters::emergencycloseactivitycommand
  }

  ######################################################################

  proc start {} {
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "started" shutters::startactivitycommand
  }

}
