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
  server::setdata "requestedcovers"  ""
  server::setdata "covers"           ""
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
    AUXILIARY.COVER.TARGETPOS
    AUXILIARY.PORT_COVER[2].TARGETPOS
    AUXILIARY.PORT_COVER[3].TARGETPOS
  } ";"]"


  ######################################################################

  variable covers ""
  variable port2cover ""
  variable port3cover ""
  variable coverstarget ""
  variable port2covertarget ""
  variable port3covertarget ""
  variable moving

  proc updatedata {response} {

    variable covers
    variable port2cover
    variable port3cover
    variable coverstarget
    variable port2covertarget
    variable port3covertarget
    variable moving

    if {[scan $response "%*d DATA INLINE AUXILIARY.COVER.REALPOS=%f" value] == 1} {
      if {$value == 0} {
        set covers "closed"
      } elseif {$value == 1.0} {
        set covers "open"
      } else {
        set covers "intermediate"
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
    if {[scan $response "%*d DATA INLINE AUXILIARY.COVER.TARGETPOS=%f" value] == 1} {
      if {$value == 0} {
        set coverstarget "closed"
      } else {
        set coverstarget "open"
      }
      return false
    }
    if {[scan $response "%*d DATA INLINE AUXILIARY.PORT_COVER\[2\].TARGETPOS=%f" value] == 1} {
      if {$value == 0} {
        set port2covertarget "closed"
      } else {
        set port2covertarget "open"
      }
      return false
    }
    if {[scan $response "%*d DATA INLINE AUXILIARY.PORT_COVER\[3\].TARGETPOS=%f" value] == 1} {
      if {$value == 0} {
        set port3covertarget "closed"
      } elseif {$value == 1.0} {
        set port3covertarget "open"
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
    set lastport2cover     [server::getdata "port2cover"]
    set lastport3cover     [server::getdata "port3cover"]
    
    if {![string equal $lastcovers ""] && ![string equal $covers $lastcovers]} {
      log::info "covers changed from \"$lastcovers\" to \"$covers\"."
    }
    if {![string equal $lastport2cover ""] && ![string equal $port2cover $lastport2cover]} {
      log::info "port 2 cover changed from \"$lastport2cover\" to \"$port2cover\"."
    }
    if {![string equal $lastport3cover ""] && ![string equal $port3cover $lastport3cover]} {
      log::info "port 3 cover changed from \"$lastport3cover\" to \"$port3cover\"."
    }

    if {
      ![string equal $covers     $coverstarget    ] ||
      ![string equal $port2cover $port2covertarget] ||
      ![string equal $port3cover $port3covertarget]
    } {
      set moving true
    } else {
      set moving false
    }
    
    server::setdata "timestamp"        $timestamp
    server::setdata "covers"           $covers
    server::setdata "port2cover"       $port2cover
    server::setdata "port3cover"       $port3cover

    server::setstatus "ok"

    return true
  }

  proc waitwhilemoving {} {
    log::info "waiting while moving."
    variable moving
    set startingdelay 1
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
  
  proc stopcovers {} {
    server::setdata "requestedcovers" ""
    opentsi::sendcommand "SET TELESCOPE.STOP=1"
  }
  
  proc opencovers {} {
    server::setdata "requestedcovers" "open"
#    opentsi::sendcommand "SET AUXILIARY.COVER.TARGETPOS=1"
#    opentsi::sendcommand "SET AUXILIARY.PORT_COVER\[2\].TARGETPOS=1"
#    opentsi::sendcommand "SET AUXILIARY.PORT_COVER\[3\].TARGETPOS=1"
    waitwhilemoving
#    if {![string equal [server::getdata "covers"] "open"]} {
#      error "the covers did not open."
#    }
  }
  
  proc closecovers {} {
    server::setdata "requestedcovers" "closed"
#    opentsi::sendcommand "SET AUXILIARY.COVER.TARGETPOS=0"
#    opentsi::sendcommand "SET AUXILIARY.PORT_COVER\[2\].TARGETPOS=0"
#    opentsi::sendcommand "SET AUXILIARY.PORT_COVER\[3\].TARGETPOS=0"
    waitwhilemoving
#    if {![string equal [server::getdata "covers"] "closed"]} {
#      error "the covers did not close."
#   }
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
    closecovers
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    opencovers
    set end [utcclock::seconds]
    log::info [format "finished opening after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    closecovers
    set end [utcclock::seconds]
    log::info [format "finished closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc stopactivitycommand {previousactivity} {
    set start [utcclock::seconds]
    log::info "stopping."
    stopcovers
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

  proc start {} {
    opentsi::start $covers::statuscommand covers::updatedata
    server::newactivitycommand "starting" "started" covers::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "covers.tcl"]
