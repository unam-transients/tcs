########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "gpio"
package require "log"
package require "server"
package require "client"

package provide "heater" 0.0

namespace eval "heater" {

  ######################################################################

  variable gpiopath [config::getvalue "heater" "gpiopath"]

  ######################################################################

  set server::datalifeseconds 30

  ######################################################################

  server::setdata "requestedheater"  ""
  server::setdata "heater"           ""
  server::setdata "timestamp"        ""

  proc updatedata {} {

    log::debug "updating data."

    set timestamp [utcclock::combinedformat now]
    
    variable gpiopath
    set heater [gpio::get $gpiopath]
    log::debug "heater = \"$heater\"."

    server::setstatus "ok"
    server::setdata "timestamp" $timestamp
    server::setdata "heater"    $heater

    return true
  }

  ######################################################################
  
  proc switchheater {state} {
    # Don't know why, but gpio::set sometimes fails, so loop until it succeeds.
    variable gpiopath
    while {![string equal [gpio::get $gpiopath] $state]} {
      gpio::set $gpiopath $state
      coroutine::after 100
    }
  }
  
  ######################################################################

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    server::setdata "requestedheater" "automatic"
    updatedata
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc switchactivitycommand {} {
    set start [utcclock::seconds]
    set requestedheater [server::getdata "requestedheater"]
    log::info "switching $requestedheater."
    switchheater $requestedheater
    updatedata
    if {![string equal [server::getdata "heater"] $requestedheater]} {
      error "the heater did not switch $requestedheater."
    }
    log::info [format "finished switching $requestedheater after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  variable autoloopseconds 15

  proc autoloop {} {
    variable autoloopseconds
    log::debug "autoloop: starting."
    while {true} {
      set autoloopmilliseconds [expr {$autoloopseconds * 1000}]
      coroutine::after $autoloopmilliseconds
      log::debug "autoloop: requestedheater = [server::getdata "requestedheater"]."
      if {![string equal [server::getdata "requestedheater"] "automatic"]} {
        continue
      }
      log::debug "autoloop: updating enclosure data."
      if {[catch {client::update "enclosure"} message]} {
        log::debug "while updating enclosure data: $message"
        continue
      }
      log::debug "autoloop: updating sensors data."
      if {[catch {client::update "sensors"} message]} {
        log::debug "while updating sensors data: $message"
        continue
      }
      if {
        [string equal [client::getdata "enclosure" "enclosure"] "closed"] &&
        [client::getdata "sensors" "enclosure-humidity"] > 0.80
      } {
        set shouldbeon true
      } else {
        set shouldbeon false
      }
      log::debug "autoloop: heater = [server::getdata "heater"]."
      log::debug "autoloop: shouldbeon = $shouldbeon."
      if {
        [string equal [server::getdata "heater"] "off"] && $shouldbeon
      } {
        log::info "switching on automatically."
        switchheater "on"
      } elseif {
        [string equal [server::getdata "heater"] "on"] && !$shouldbeon
      } {
        log::info "switching off automatically."
        switchheater "off"
      }
    }
  }

  ######################################################################

  proc switchon {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "requestedheater" "on"
    server::newactivitycommand "switching" "idle" heater::switchactivitycommand
  }

  proc switchoff {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "requestedheater" "off"
    server::newactivitycommand "switching" "idle" heater::switchactivitycommand
  }
  
  proc switchautomatically {} {
    log::info [format "switching automatically."]
    server::checkstatus
    server::checkactivityformove
    server::setdata "requestedheater" "automatic"
    return
  }
  
  ######################################################################

  proc start {} {
    coroutine::every 1000 heater::updatedata
    server::newactivitycommand "starting" "idle" heater::startactivitycommand
    after idle {
      coroutine::create heater::autoloop
    }
  }

}
