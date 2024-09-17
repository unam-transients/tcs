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
    AUXILIARY.DOME.TARGETPOS
    AUXILIARY.DOME.REALPOS
  } ";"]"


  ######################################################################

  variable azimiuth ""
  variable moving

  proc updatedata {response} {

    variable azimuth
    variable shutters
    variable shutterstarget
    variable moving

    if {[scan $response "%*d DATA INLINE POSITION.INSTRUMENTAL.DOME\[0\].REALPOS=%f" value] == 1} {
      set azimuth [astrometry::degtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE AUXILIARY.DOME.REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set shutters "closed"
      } elseif {$value == 1.0} {
        set shutters "open"
      } else {
        set shutters "intermediate"
      }
      return false
    }
    if {[scan $response "%*d DATA INLINE AUXILIARY.DOME.TARGETPOS=%f" value] == 1} {
      if {$value == 0} {
        set shutterstarget "closed"
      } else {
        set shutterstarget "open"
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

    set lastazimuth [server::getdata "azimuth"]
    if {![string equal $lastazimuth ""] && $azimuth != $lastazimuth} {
      set moving true
    } else {
      set moving false
    }
    
    set timestamp [utcclock::combinedformat "now"]
    
    server::setdata "timestamp"        $timestamp
    server::setdata "azimuth"          $azimuth
    server::setdata "shutters"         $shutters

    server::setstatus "ok"

    return true
  }

  proc waitwhilemoving {} {
    log::info "waiting while moving."
    variable moving
    set startingdelay 2
    set settlingdelay 1
    set start [utcclock::seconds]
    while {[utcclock::diff now $start] < $startingdelay} {
      coroutine::yield
    }
    while {$moving} {
      coroutine::yield
    }
    set settle [utcclock::seconds]
    while {[utcclock::diff now $settle] < $settlingdelay} {
      coroutine::yield
    }
    log::info "finished waiting while moving."
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
    opentsi::sendcommand "SET POINTING.SETUP.DOME.SYNCMODE=0"
  }
      
  proc stophardware {} {
    if {[opentsi::isoperational]} {
      opentsi::sendcommand "SET TELESCOPE.STOP=1"
    }
  }
  
  proc openhardware {} {
    server::setdata "requestedshutters" "open"
    opentsi::sendcommand "SET AUXILIARY.DOME.TARGETPOS=1"
    while {![string equal [server::getdata "shutters"] "open"]} {
      coroutine::yield
    }
  }
  
  proc closehardware {} {
    server::setdata "requestedshutters" "closed"
    opentsi::sendcommand "SET AUXILIARY.DOME.TARGETPOS=0"
    while {![string equal [server::getdata "shutters"] "closed"]} {
      coroutine::yield
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
    opentsi::sendcommand "SET AUXILIARY.DOME.TARGETPOS=0"
    waitwhilemoving
    if {![string equal [server::getdata "shutters"] "closed"]} {
      error "the shutters did not close."
    }
  }
  
  proc movehardware {azimuth} {
    set azimuth [astrometry::parseazimuth $azimuth]
    server::setdata "requestedazimuth" $azimuth
    opentsi::sendcommand [format "SET POSITION.INSTRUMENTAL.DOME\[0\].TARGETPOS=%f" [astrometry::radtodeg $azimuth]]
    waitwhilemoving
  }
  
  
  ######################################################################

  proc start {} {
    opentsi::start $dome::statuscommand dome::updatedata
    server::newactivitycommand "starting" "started" dome::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "dome.tcl"]
