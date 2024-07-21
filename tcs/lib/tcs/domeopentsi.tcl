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
    if {
      ![string equal $shutters $shutterstarget] ||
      (![string equal $lastazimuth ""] && $azimuth != $lastazimuth)
    } {
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
    set startingdelay 10
    set settlingdelay 5
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
  
  proc stopdome {} {
    server::setdata "requestedshutters" ""
    opentsi::sendcommand "SET TELESCOPE.STOP=1"
  }
  
  proc opendome {} {
    server::setdata "requestedshutters" "open"
    opentsi::sendcommand "SET AUXILIARY.DOME.TARGETPOS=1"
    waitwhilemoving
    if {![string equal [server::getdata "shutters"] "open"]} {
      error "the shutters did not open."
    }
  }
  
  proc closedome {} {
    server::setdata "requestedshutters" "closed"
    opentsi::sendcommand "SET AUXILIARY.DOME.TARGETPOS=0"
    waitwhilemoving
    if {![string equal [server::getdata "shutters"] "closed"]} {
      error "the shutters did not close."
    }
  }
  
  proc emergencyclosedome {} {
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
  
  proc movedome {azimuth} {
    set azimuth [astrometry::parseazimuth $azimuth]
    server::setdata "requestedazimuth" $azimuth
    opentsi::sendcommand [format "SET POSITION.INSTRUMENTAL.DOME\[0\].TARGETPOS=%f" [astrometry::radtodeg $azimuth]]
    waitwhilemoving
  }
  
  ######################################################################
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    while {[string equal [server::getstatus] "starting"]} {
      coroutine::yield
    }
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    log::info "closing."
    closedome
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    opendome
    set end [utcclock::seconds]
    log::info [format "finished opening after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    closedome
    set end [utcclock::seconds]
    log::info [format "finished closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc emergencycloseactivitycommand {} {
    set start [utcclock::seconds]
    log::warning "emergency closing."
    emergencyclosedome
    set end [utcclock::seconds]
    log::info [format "finished emergency closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetomoveactivitycommand {} {
    server::setdata requestedazimuth ""
  }
  
  proc moveactivitycommand {azimuth} {
    set start [utcclock::seconds]
    log::info "moving."
    movedome $azimuth
    set end [utcclock::seconds]
    log::info [format "finished moving after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc parkactivitycommand {} {
    set start [utcclock::seconds]
    variable parkazimuth
    log::info "parking."
    movedome $parkazimuth
    set end [utcclock::seconds]
    log::info [format "finished parking after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc stopactivitycommand {previousactivity} {
    set start [utcclock::seconds]
    log::info "stopping."
    stopdome
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

  proc start {} {
    opentsi::start $dome::statuscommand dome::updatedata
    server::newactivitycommand "starting" "started" dome::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "dome.tcl"]
