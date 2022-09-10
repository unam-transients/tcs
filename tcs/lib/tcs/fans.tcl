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
package require "gpio"
package require "log"
package require "server"

package provide "fans" 0.0

namespace eval "fans" {

  ######################################################################

  variable gpiopath [config::getvalue "fans" "gpiopath"]

  ######################################################################

  set server::datalifeseconds 30

  ######################################################################

  server::setdata "requestedfans"  ""
  server::setdata "fans"           ""
  server::setdata "timestamp"        ""

  proc updatedata {} {

    log::debug "updating data."

    set timestamp [utcclock::combinedformat now]
    
    variable gpiopath
    set fans [gpio::get $gpiopath]
    log::debug "fans = \"$fans\"."

    server::setstatus "ok"
    server::setdata "timestamp" $timestamp
    server::setdata "fans"    $fans

    return true
  }

  ######################################################################
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    server::setdata "requestedfans" ""
    updatedata
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    set requestedfans [server::getdata "requestedfans"]
    log::info "switching $requestedfans."
    variable gpiopath
    gpio::set $gpiopath $requestedfans
    updatedata
    if {![string equal [server::getdata "fans"] $requestedfans]} {
      error "the fans did not switch $requestedfans."
    }
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc switchactivitycommand {} {
    set start [utcclock::seconds]
    set requestedfans [server::getdata "requestedfans"]
    log::info "switching $requestedfans."
    variable gpiopath
    gpio::set $gpiopath $requestedfans
    updatedata
    if {![string equal [server::getdata "fans"] $requestedfans]} {
      error "the fans did not switch $requestedfans."
    }
    log::info [format "finished switching $requestedfans after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  proc switchon {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "requestedfans" "on"
    server::newactivitycommand "switching" "idle" fans::switchactivitycommand
  }

  proc switchoff {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "requestedfans" "off"
    server::newactivitycommand "switching" "idle" fans::switchactivitycommand
  }
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::setdata "requestedfans" "off"
    server::newactivitycommand "initializing" "idle" fans::initializeactivitycommand
  }
  
  ######################################################################

  proc start {} {
    coroutine::every 1000 fans::updatedata
    server::newactivitycommand "starting" "idle" fans::startactivitycommand
  }

}
