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
package require "directories"
package require "log"
package require "server"

config::setdefaultvalue "covers" "controllerhost" "covers"
config::setdefaultvalue "covers" "controllerport" "4545"

package provide "coversratiroan" 0.0

namespace eval "covers" {

  ######################################################################

  variable controllerhost [config::getvalue "covers" "controllerhost"]
  variable controllerport [config::getvalue "covers" "controllerport"]

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::statuscommand               ""
  set controller::timeoutmilliseconds         500
  set controller::intervalmilliseconds        500
  set controller::updatedata                  covers::updatecontrollerdata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 0

  ######################################################################

  server::setdata "requestedcovers"  ""
  server::setdata "covers"           ""
  server::setdata "mode"             ""
  server::setdata "timestamp"        [utcclock::combinedformat now]
  server::setdata "settled"          false
  server::setdata "settledtimestamp" [utcclock::combinedformat now]

  variable settledelayseconds 60

  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    if {
      ![string equal $controllerresponse ":abriendo tapas y buscador;"] &&
      ![string equal $controllerresponse ":cerrando buscador y tapas;"]
    } {
      error "invalid controller response \"$controllerresponse\"."
    }

    server::setstatus "ok"
    server::setdata "timestamp" $timestamp
    server::setdata "mode"      "local/remote"
    
    return true
  }

  ######################################################################

  proc settle {} {
    server::setdata "settled"          false
    server::setdata "settledtimestamp" [utcclock::combinedformat now]
    variable settledelayseconds
    set timestamp [utcclock::combinedformat now]
    while {[utcclock::diff now $timestamp] < $settledelayseconds} {
      coroutine::yield
    }
    server::setdata "settled"          true
    server::setdata "settledtimestamp" [utcclock::combinedformat now]
    log::debug "settled."
  }
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    settle
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    server::setdata "requestedcovers" "closed"
    server::setdata "covers" ""
    settle
    controller::sendcommand ":CERRAR;\n"
    settle
    server::setdata "covers" "closed"    
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    server::setdata "requestedcovers" "open"
    server::setdata "covers" ""
    settle
    controller::sendcommand ":ABRIR;\n"
    settle
    server::setdata "covers" "open"    
    set end [utcclock::seconds]
    log::info [format "finished opening after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    server::setdata "requestedcovers" "closed"
    server::setdata "covers" ""
    settle
    controller::sendcommand ":CERRAR;\n"
    settle
    server::setdata "covers" "closed"    
    set end [utcclock::seconds]
    log::info [format "finished closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc stopactivitycommand {previousactivity} {
    set start [utcclock::seconds]
    log::info "stopping"
    server::setdata "requestedcovers" ""
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

  proc start {} {
    server::setstatus "ok"
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "started" covers::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "covers.tcl"]
