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

package provide "coversopentsi" 0.0

namespace eval "covers" {

  variable ports [config::getvalue "covers" "ports"]

  ######################################################################

  set server::datalifeseconds        30

  server::setdata "state"            ""
  server::setdata "covers"           ""
  server::setdata "requestedcovers"  ""
  server::setdata "primarycover"     ""
  foreach portname [dict keys $ports] {
    server::setdata ${portname}cover ""
  }
  server::setdata "portnames"        [dict keys $ports]
  server::setdata "timestamp"        [utcclock::combinedformat now]

  ######################################################################
  
  set statuscommandlist "AUXILIARY.COVER.REALPOS"
  foreach portindex [dict values $ports] {
    lappend statuscommandlist [format "AUXILIARY.PORT_COVER\[%d\].REALPOS" $portindex]
  }
  set statuscommand "GET [join $statuscommandlist ";"]"

  ######################################################################

  variable covers ""
  variable requestedcovers ""
  variable primarycover ""
  variable portcovers []
  
  proc coverstate {value} {
    if {$value == 0} {
      return "closed"
    } elseif {$value == 1.0} {
      return "open"
    } else {
      return "intermediate"
    }
  }

  proc updatedata {response} {

    variable covers
    variable primarycover
    variable portcovers
    variable ports

    if {[scan $response "%*d DATA INLINE AUXILIARY.COVER.REALPOS=%f" value] == 1} {
      set primarycover [coverstate $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE AUXILIARY.PORT_COVER\[%d\].REALPOS=%f" index value] == 2} {
      foreach portname [dict keys $ports] {
        if {$index == [dict get $ports $portname]} {
          dict set portcovers $portname [coverstate $value]
          return false
        }
      }
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

    set lastcover [server::getdata "primarycover"]    
    set cover [set primarycover]
    if {![string equal $lastcover ""] && ![string equal $lastcover $cover]} {
      log::info "primary cover changed from \"$lastcover\" to \"$cover\"."
    }
    foreach portname [dict keys $ports] {
      set lastcover [server::getdata "${portname}cover"]
      set cover [dict get $portcovers $portname]
      if {![string equal $lastcover ""] && ![string equal $lastcover $cover]} {
        log::info "$portname cover changed from \"$lastcover\" to \"$cover\"."
      }
    }

    set covers $primarycover
    foreach portname {ogse} {
      if {![string equal $covers [dict get $portcovers $portname]]} {
        set covers "intermediate"
      }
    }
    
    server::setdata "timestamp"        $timestamp
    server::setdata "covers"           $covers
    server::setdata "primarycover"     $primarycover
    foreach portname [dict keys $ports] {
      server::setdata "${portname}cover" [dict get $portcovers $portname]
    }

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
    variable ports
    foreach portindex [dict values $ports] {
      opentsi::sendcommand [format "SET AUXILIARY.PORT_COVER\[%d\].TARGETPOS=1" $portindex]
    }
  }
  
  proc closehardware {} {
    server::setdata "requestedcovers" "closed"
    opentsi::sendcommand [format "SET AUXILIARY.COVER.TARGETPOS=0"]
    # Port 3 is failing, so we do not close the ports.
    return
    variable ports
    foreach portindex [dict values $ports] {
      opentsi::sendcommand [format "SET AUXILIARY.PORT_COVER\[%d\].TARGETPOS=0" $portindex]
    }
  }
  
  ######################################################################
  
  proc start {} {
    opentsi::start $covers::statuscommand covers::updatedata
    server::newactivitycommand "starting" "started" covers::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "covers.tcl"]
