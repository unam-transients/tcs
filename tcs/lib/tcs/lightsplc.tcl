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

package provide "lightsplc" 0.0

namespace eval "lights" {

  ######################################################################

  proc updatedata {} {

    log::debug "updating data."

    set timestamp [utcclock::combinedformat now]
    
    if {[catch {client::update "plc"}]} {
      log::debug "lights: unable to update the plc data."
      set lights ""
    } else {
      set lights [client::getdata "plc" "lights"]
    }
    log::debug "lights = \"$lights\"."

    server::setstatus "ok"
    server::setdata "timestamp" $timestamp
    server::setdata "lights"    $lights

    return true
  }

  ######################################################################

  proc switchrequested {} {
    log::debug "switchrequested: start"
    set requestedlights [server::getdata "requestedlights"]
    switch $requestedlights {
      "on" {
        if {[catch {client::request "plc" "switchlightson"}]} {
          log::warning "unable to switch lights on."
        }
      }
      "off" {
        if {[catch {client::request "plc" "switchlightsoff"}]} {
          log::warning "unable to switch lights off."
        }
      }
      default {
        error "invalid requested state: $requestedlights"
      }
    }
    log::debug "switchrequested: end"
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "lights.tcl"]
