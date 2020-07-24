########################################################################

# This file is part of the UNAM telescope control system.

# $Id: lightsgpio.tcl 3601 2020-06-11 03:20:53Z Alan $

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

package require "config"
package require "gpio"
package require "log"
package require "server"

package provide "lightsgpio" 0.0

namespace eval "lights" {

  variable svnid {$Id}
  
  ######################################################################

  variable gpiopath [config::getvalue "lights" "gpiopath"]

  ######################################################################

  proc updatedata {} {

    log::debug "updating data."

    set timestamp [utcclock::combinedformat now]
    
    variable gpiopath
    set lights [gpio::get $gpiopath]
    log::debug "lights = \"$lights\"."

    server::setstatus "ok"
    server::setdata "timestamp" $timestamp
    server::setdata "lights"    $lights

    return true
  }

  ######################################################################

  proc switchrequested {} {
    # Don't know why, but gpio::set sometimes fails, so loop until it succeeds.
    variable gpiopath
    set requestedlights [server::getdata "requestedlights"]
    while {![string equal [gpio::get $gpiopath] $requestedlights]} {
      gpio::set $gpiopath $requestedlights
      coroutine::after 100
    }
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "lights.tcl"]
