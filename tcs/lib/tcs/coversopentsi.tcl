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

config::setdefaultvalue "covers" "port2name"      "port2"
config::setdefaultvalue "covers" "port3name"      "port3"

package provide "coversopentsi" 0.0

namespace eval "covers" {

  ######################################################################

  set server::datalifeseconds        30

  server::setdata "state"            ""
  server::setdata "covers"           ""
  server::setdata "requestedcovers"  ""
  server::setdata "primarycover"     ""
  server::setdata "port2cover"       ""
  server::setdata "port3cover"       ""
  server::setdata "port2name"        [config::getvalue "covers" "port2name"]
  server::setdata "port3name"        [config::getvalue "covers" "port3name"]
  server::setdata "timestamp"        [utcclock::combinedformat now]

  ######################################################################

  set statuscommand "GET [join {
    AUXILIARY.COVER.REALPOS
    AUXILIARY.PORT_COVER[2].REALPOS
    AUXILIARY.PORT_COVER[3].REALPOS
  } ";"]"


  ######################################################################

  variable covers ""
  variable requestedcovers ""
  variable primarycover ""
  variable port2cover ""
  variable port3cover ""

  proc updatedata {response} {

    variable covers
    variable primarycover
    variable port2cover
    variable port3cover
    variable port2covertarget
    variable port3covertarget

    if {[scan $response "%*d DATA INLINE AUXILIARY.COVER.REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set primarycover "closed"
      } elseif {$value == 1.0} {
        set primarycover "open"
      } else {
        set primarycover "intermediate"
      }
      return false
    }
    if {[scan $response "%*d DATA INLINE AUXILIARY.PORT_COVER\[2\].REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set port2cover "closed"
      } elseif {$value == 1.0} {
        set port2cover "open"
      } else {
        set port2cover "intermediate"
      }
      return false
    }
    if {[scan $response "%*d DATA INLINE AUXILIARY.PORT_COVER\[3\].REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set port3cover "closed"
      } elseif {$value == 1.0} {
        set port3cover "open"
      } else {
        set port3cover "intermediate"
      }
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

    set timestamp [utcclock::combinedformat "now"]

    set lastcovers         [server::getdata "covers"]
    set lastprimarycover   [server::getdata "primarycover"]
    set lastport2cover     [server::getdata "port2cover"]
    set lastport3cover     [server::getdata "port3cover"]
    
    if {![string equal $lastprimarycover ""] && ![string equal $primarycover $lastprimarycover]} {
      log::info "primary cover changed from \"$lastprimarycover\" to \"$primarycover\"."
    }
    if {![string equal $lastport2cover ""] && ![string equal $port2cover $lastport2cover]} {
      log::info "port 2 cover changed from \"$lastport2cover\" to \"$port2cover\"."
    }
    if {![string equal $lastport3cover ""] && ![string equal $port3cover $lastport3cover]} {
      log::info "port 3 cover changed from \"$lastport3cover\" to \"$port3cover\"."
    }

    if {![string equal $lastcovers ""] && ![string equal $covers $lastcovers]} {
      log::info "covers changed from \"$lastcovers\" to \"$covers\"."
    }

    set covers $primarycover
    if {![string equal $covers $port2cover]} {
      set covers "intermediate"
    }
    if {![string equal $covers $port3cover]} {
      set covers "intermediate"
    }
    
    server::setdata "timestamp"        $timestamp
    server::setdata "covers"           $covers
    server::setdata "primarycover"     $primarycover
    server::setdata "port2cover"       $port2cover
    server::setdata "port3cover"       $port3cover

    server::setstatus "ok"

    return true
  }

  ######################################################################
  
  proc checkhardwarefor {action} {
    switch $action {
      "reset" -
      "stop" {
      }
      default {
        opentsi::checkreadystate "operational"
      }
    }
  }
  
  proc initializehardware {} {
    closehardware
  }
  
  proc stophardware {} {
    server::setdata "requestedcovers" ""
    if {[opentsi::isoperational]} {
      opentsi::sendcommandandwait "SET TELESCOPE.STOP=1"
    }
  }
  
  proc openhardware {} {
    server::setdata "requestedcovers" "open"
    opentsi::sendcommand [format "SET AUXILIARY.COVER.TARGETPOS=1"]
    opentsi::sendcommand [format "SET AUXILIARY.PORT_COVER\[2\].TARGETPOS=1"]
    opentsi::sendcommand [format "SET AUXILIARY.PORT_COVER\[3\].TARGETPOS=1"]
  }
  
  proc closehardware {} {
    server::setdata "requestedcovers" "closed"
    opentsi::sendcommand [format "SET AUXILIARY.COVER.TARGETPOS=0"]
    opentsi::sendcommand [format "SET AUXILIARY.PORT_COVER\[2\].TARGETPOS=0"]
    opentsi::sendcommand [format "SET AUXILIARY.PORT_COVER\[3\].TARGETPOS=0"]
  }
  
  ######################################################################
  
  proc start {} {
    opentsi::start $covers::statuscommand covers::updatedata
    server::newactivitycommand "starting" "started" covers::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "covers.tcl"]
