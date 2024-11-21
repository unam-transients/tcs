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

package require "astrometry"
package require "config"
package require "opentsi"
package require "log"
package require "server"

package provide "domeopentsi" 0.0

namespace eval "dome" {

  ######################################################################

  set server::datalifeseconds          30

  server::setdata "state"              ""
  server::setdata "azimuth"            ""
  server::setdata "requestedazimuth"   ""
  server::setdata "azimutherror"       ""
  server::setdata "maxabsazimutherror" ""
  server::setdata "shutters"           ""
  server::setdata "requestedshutters"  ""
  server::setdata "timestamp"          [utcclock::combinedformat now]

  ######################################################################

  set statuscommand "GET [join {
    POSITION.INSTRUMENTAL.DOME[0].REALPOS
    AUXILIARY.DOME.REALPOS
  } ";"]"

  ######################################################################

  variable pendingazimuth  ""
  variable pendingshutters ""

  proc updatedata {response} {

    variable pendingazimuth
    variable pendingshutters

    if {[scan $response "%*d DATA INLINE POSITION.INSTRUMENTAL.DOME\[0\].REALPOS=%f" value] == 1} {
      set pendingazimuth [astrometry::degtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE AUXILIARY.DOME.REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set pendingshutters "closed"
      } elseif {$value == 1.0} {
        set pendingshutters "open"
      } else {
        set pendingshutters "intermediate"
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

    set requestedazimuth [server::getdata "requestedazimuth"]
    if {[string equal $requestedazimuth ""]} {
        set pendingazimutherror ""
    } else {
        set pendingazimutherror [astrometry::foldradsymmetric [expr {$pendingazimuth - $requestedazimuth}]]
    }
    
    set timestamp [utcclock::combinedformat "now"]
    
    server::setdata "timestamp"        $timestamp
    server::setdata "azimuth"          $pendingazimuth
    server::setdata "azimutherror"     $pendingazimutherror
    server::setdata "shutters"         $pendingshutters
    
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
    opentsi::sendcommandandwait "SET POINTING.SETUP.DOME.SYNCMODE=0"
  }
      
  proc stophardware {} {
    server::setdata "requestedshutters" ""
    if {[opentsi::isoperational]} {
      opentsi::sendcommandandwait "SET TELESCOPE.STOP=1"
    }
  }
  
  # We sometimes close before opening to work around a bug in OpenTSI
  # that causes a request to open the shutters to be ignored if the
  # shutters were interrupted while opening. (And the converse with
  # closing.)

  proc openhardware {} {
    server::setdata "requestedshutters" "open"
    if {[string equal [server::getdata "shutters"] "intermediate"]} {
      opentsi::sendcommandandwait "SET AUXILIARY.DOME.TARGETPOS=0"
    }
    if {![string equal [server::getdata "shutters"] "open"]} {
      opentsi::sendcommandandwait "SET AUXILIARY.DOME.TARGETPOS=1"
    }
  }
  
  proc closehardware {} {
    server::setdata "requestedshutters" "closed"
    if {[string equal [server::getdata "shutters"] "intermediate"]} {
      opentsi::sendcommandandwait "SET AUXILIARY.DOME.TARGETPOS=1"
    }
    if {![string equal [server::getdata "shutters"] "closed"]} {
      opentsi::sendcommandandwait "SET AUXILIARY.DOME.TARGETPOS=0"
    }
  }
  
  proc emergencyclosehardware {} {
    server::setdata "requestedshutters" "closed"
    # Switch the telescope on. We shouldn't have to do this here, but this
    # is an emergency.
    opentsi::sendcommand "SET TELESCOPE.POWER=1"
    while {$opentsi::readystate != 1.0} {
      coroutine::yield
    }
    set settlingdelay 5
    set settle [utcclock::seconds]
    while {[utcclock::diff now $settle] < $settlingdelay} {
      coroutine::yield
    }
    # Now close the dome.
    opentsi::sendcommandandwait "SET AUXILIARY.DOME.TARGETPOS=0"
  }
  
  proc movehardware {azimuth} {
    set azimuth [astrometry::parseazimuth $azimuth]
    server::setdata "requestedazimuth" $azimuth
    server::setdata "azimutherror"     ""
    opentsi::sendcommandandwait [format "SET POSITION.INSTRUMENTAL.DOME\[0\].TARGETPOS=%f" [astrometry::radtodeg $azimuth]]
  }
  
  
  ######################################################################

  proc start {} {
    opentsi::start $dome::statuscommand dome::updatedata
    server::newactivitycommand "starting" "started" dome::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "dome.tcl"]
