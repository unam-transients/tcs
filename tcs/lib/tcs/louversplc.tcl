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

package provide "louversplc" 0.0

namespace eval "louvers" {

  variable activelouvers [config::getvalue "louvers" "activelouvers"]

  ######################################################################
  
  proc updatedata {} {

    log::debug "updating data."

    set timestamp [utcclock::combinedformat now]
    
    if {[catch {client::update "plc"}]} {
      log::debug "louvers: unable to update the plc data."
      return
    }
    
    variable activelouvers
    server::setdata "activelouvers" $activelouvers

    foreach i $activelouvers {
      server::setdata "louver$i" [client::getdata "plc" "louver$i"]
      logchange "louver$i" "louver $i"
    }
    
    set louvers ""
    foreach i $activelouvers {
      if {[string equal [server::getdata "louver$i"] "error"]} {
        set louvers "error"
        break
      }
      if {[string equal $louvers ""]} {
        set louvers [server::getdata "louver$i"]
      } elseif {![string equal $louvers [server::getdata "louver$i"]]} {
        set louvers "intermediate"
        break
      }
      logchange "louver$i" "louver$i"
    }
    server::setdata "louvers" $louvers
    logchange "louvers" "louvers"
    
    server::setstatus "ok"
    server::setdata "timestamp" $timestamp

    return true
  }

  ######################################################################

  variable lastvalue {}
  
  proc logchange {name prettyname} {
    variable lastvalue
    set value [server::getdata $name]
    if {![dict exists $lastvalue $name]} {
      log::info [format "%s is %s." $prettyname $value]
    } elseif {![string equal [dict get $lastvalue $name] $value]} {
      log::info [format "%s has changed from %s to %s." $prettyname [dict get $lastvalue $name] $value]
    }
    dict set lastvalue $name $value
  }

  ######################################################################

  proc openhardware {} {
    if {[catch {client::request "plc" "special openlouvers"}]} {
      log::error "unable to open."
      return
    }
    set start [utcclock::seconds]
    while {![string equal [server::getdata "louvers"] [server::getdata "requestedlouvers"]] && [utcclock::diff now $start] < 30} {
      coroutine::after 1000
    }
    if {![string equal [server::getdata "louvers"] [server::getdata "requestedlouvers"]]} {
      log::error "unable to open."
    }
  }

  proc closehardware {} {
    if {[catch {client::request "plc" "special closelouvers"}]} {
      error "unable to close."
      return
    }
    set start [utcclock::seconds]
    while {![string equal [server::getdata "louvers"] [server::getdata "requestedlouvers"]] && [utcclock::diff now $start] < 30} {
      coroutine::after 1000
    }
    if {![string equal [server::getdata "louvers"] [server::getdata "requestedlouvers"]]} {
      error "unable to close."
    }
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "louvers.tcl"]
