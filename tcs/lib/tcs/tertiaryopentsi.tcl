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
package require "opentsi"
package require "log"
package require "server"

config::setdefaultvalue "tertiary" "port2name"      "port2"
config::setdefaultvalue "tertiary" "port3name"      "port3"

package provide "tertiaryopentsi" 0.0

namespace eval "tertiary" {

  ######################################################################

  set server::datalifeseconds        30

  server::setdata "requestedport" ""
  server::setdata "port"   ""
  server::setdata "timestamp"        [utcclock::combinedformat now]

  ######################################################################

  set statuscommand "GET [join {
    POINTING.SETUP.USE_PORT
    POSITION.INSTRUMENTAL.PORT_SELECT.CURRPOS
  } ";"]"


  ######################################################################

  variable currentposition ""
  variable port     ""
  variable requestedport   ""

  proc updatedata {response} {

    variable currentposition
    variable port
    variable requestedport

    if {[scan $response "%*d DATA INLINE POSITION.INSTRUMENTAL.PORT_SELECT.CURRPOS=%f" value] == 1} {
      set currentposition $value
      return false
    }
    if {[regexp {[0-9]+ DATA INLINE } $response] == 1} {
      log::debug "status: ignoring DATA INLINE response."
      return false
    }
    if {[regexp {[0-9]+ COMMAND COMPLETE} $response] != 1} {
      log::warning "unexpected controller response \"$response\"."
      return true
    }
    
    if {$currentposition == 2.0} {
      set port "port2"
    } elseif {$currentposition == 4.0} {
      set port "intermediate"
    } elseif {$currentposition == 2.0} {
      set port "port3"
    } else {
      log::warning "unexpected value of current position \"$currentposition\"."
      set port "unknown"
    }

    log::info [format "currentposition is %.0f." $currentposition]
    log::info [format "port is %s." $port]
    log::info [format "requestedport is %s." $requestedport]

    set timestamp [utcclock::combinedformat "now"]

    set lastport [server::getdata "port"]
    if {![string equal $lastport ""] && ![string equal $port $lastport]} {
      log::info "tertiary changed from \"$lastport\" to \"$port\"."
    }
    
    server::setdata "timestamp"     $timestamp
    server::setdata "port"          $port
    server::setdata "requestedport" $requestedport
    
    server::setstatus "ok"

    return true
  }

  ######################################################################
  
  proc checkhardwarefor {action} {
    switch $action {
      "reset" {
      }
      default {
        opentsi::checkreadystate "operational"
      }
    }
  }
  
  proc initializehardware {} {
    setporthardware "port3"
  }
  

  proc setporthardware {newrequestedport} {
    variable requestedport
    switch $newrequestedport {
      "port2" {
        set i 2
      }
      "port3" {
        set i 3
      }
      default {
        error "unknown port \"$newrequestedport\"."
      }
    }
    opentsi::sendcommand [format "SET POINTING.SETUP.USE_PORT=%d" $i]
    set requestedport $newrequestedport
  }
    
  ######################################################################
  
  proc start {} {
    opentsi::start $tertiary::statuscommand tertiary::updatedata
    server::newactivitycommand "starting" "started" tertiary::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "tertiary.tcl"]
