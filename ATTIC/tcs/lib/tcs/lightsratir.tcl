########################################################################

# This file is part of the UNAM telescope control system.

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

package provide "lights" 0.0

namespace eval "lights" {

  ######################################################################

  variable controllerhost [config::getvalue "lights" "controllerhost"]
  variable controllerport [config::getvalue "lights" "controllerport"]

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::statuscommand               "ESTADO;\n"
  set controller::timeoutmilliseconds         500
  set controller::intervalmilliseconds        500
  set controller::updatedata                  lights::updatecontrollerdata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 5

  ######################################################################

  server::setdata "requestedlights"  ""
  server::setdata "lights"           ""
  server::setdata "lastlights"       ""
  server::setdata "timestamp"        ""
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
    
    set lasttimestamp    [server::getdata "timestamp"]
    set lastlights       [server::getdata "lights"]
    set stoppedtimestamp [server::getdata "stoppedtimestamp"]

    if {
      [scan $controllerresponse "%d %d %d %d %d;" switchcontacts uppershutter lowershutter lights other] != 5 &&
      [scan $controllerresponse "%*c%d %d %d %d %d;" switchcontacts uppershutter lowershutter lights other] != 5
    } {
      error "invalid response: \"$controllerresponse\"."
    }

    switch $lights {
      0 { set lights "off" }
      1 { set lights "on" }
    }

    if {![string equal $lights $lastlights]} {
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
    server::setdata "lasttimestamp"    $lasttimestamp
    server::setdata "timestamp"        $timestamp
    server::setdata "lastlights"       $lastlights
    server::setdata "lights"           $lights
    server::setdata "stoppedtimestamp" $stoppedtimestamp
    server::setdata "settled"          $settled

    return true
  }

  proc setrequestedlights {lights} {
    server::setdata "requestedlights" $lights
  }
  
  ######################################################################
  
  proc settle {} {
    log::debug "settling."
    server::setdata "stoppedtimestamp" ""
    server::setdata "lastlights"       ""
    server::setdata "settled"          false
    while {![server::getdata "settled"]} {
      coroutine::yield
    }
    log::debug "settled."
  }
  
  proc startactivitycommand {} {
    settle
    setrequestedlights [server::getdata "lights"]
  }
  
  proc switchonactivitycommand {} {
    setrequestedlights "on"
    controller::sendcommand "ACORTINA LUZ1_ON;\n"
    settle
    if {![string equal [server::getdata "lights"] "on"]} {
      error "the dome lights did not switch on."
    }
  }

  proc switchoffactivitycommand {} {
    setrequestedlights "off"
    controller::sendcommand "ACORTINA LUZ1_OFF;\n"
    settle
    if {![string equal [server::getdata "lights"] "off"]} {
      error "the dome lights did not switch off."
    }
  }

  ######################################################################

  proc switchon {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "switchingon" "idle" lights::switchonactivitycommand
  }

  proc switchoff {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "switchingoff" "idle" lights::switchoffactivitycommand
  }
  
  ######################################################################

  proc start {} {
    setrequestedlights ""
    server::newactivitycommand "starting" "idle" lights::startactivitycommand
    controller::startstatusloop
    controller::startcommandloop
  }

}
