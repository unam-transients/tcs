########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "client"
package require "log"
package require "server"

package provide "fansplc" 0.0

namespace eval "fans" {

  ######################################################################
  
  proc updatedata {} {

    log::debug "updating data."

    set timestamp [utcclock::combinedformat now]
    
    if {[catch {client::update "plc"}]} {
      log::debug "fans: unable to update the plc data."
      return
    }
    
    server::setdata "fans" [client::getdata "plc" "fans"]
    
    server::setstatus "ok"
    server::setdata "timestamp" $timestamp

    return true
  }

  ######################################################################

  proc waitwhileswitching {} {
    log::info "waiting until [server::getdata "requestedfans"]."
    set startingdelay 1000
    set settlingdelay 1000
    coroutine::after $startingdelay
    while {![string equal [server::getdata "fans"] [server::getdata "requestedfans"]]} {
      coroutine::after 1000
    }
    coroutine::after $settlingdelay
    log::info "finished waiting until [server::getdata "requestedfans"]."
  }

  ######################################################################

  proc switchonhardware {} {
    if {[catch {client::request "plc" "switchonfans"}]} {
      log::warning "unable to switch on."
    }
    waitwhileswitching
  }

  proc switchoffhardware  {} {
    if {[catch {client::request "plc" "switchofffans"}]} {
      log::warning "unable to switch off."
    }
    waitwhileswitching
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "fans.tcl"]
