########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "log"
package require "server"

package provide "fans" 0.0

namespace eval "fans" {

  ######################################################################

  set server::datalifeseconds 30

  ######################################################################

  server::setdata "requestedfans"  ""
  server::setdata "fans"           ""
  server::setdata "mode"           ""
  server::setdata "timestamp"      ""

  ######################################################################
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    updatedata
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    server::setdata "requestedfans" "off"
    switchoffhardware
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc switchonactivitycommand {} {
    set start [utcclock::seconds]
    log::info "switching on."
    server::setdata "requestedfans" "on"
    switchonhardware
    log::info [format "finished switching on after %.1f seconds." [utcclock::diff now $start]]
  }

  proc switchoffactivitycommand {} {
    set start [utcclock::seconds]
    log::info "switching off."
    server::setdata "requestedfans" "off"
    switchoffhardware
    log::info [format "finished switching off after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  server::setdata "mustbeoff"        ""

  proc switchautomaticallyloop {} {

    set loopseconds 10

    log::debug "switchautomaticallyloop: starting."

    while {true} {

      set loopmilliseconds [expr {$loopseconds * 1000}]
      coroutine::after $loopmilliseconds

      log::debug "switchautomaticallyloop: updating weather data."
      if {[catch {client::update "weather"} message]} {
        log::debug "while updating weather data: $message"
        set mustbeoff true
      } else {
        set mustbeoff [client::getdata "weather" "mustbeclosed"]
      }
        
      server::setdata "mustbeoff" $mustbeoff

      log::debug [format "switchautomaticallyloop: mode is %s." [server::getdata "mode"]]
      if {![string equal [server::getdata "mode"] "automatic"]} {
        continue
      }
      
      set fans [server::getdata "fans"]
      set requestedfans $fans

      if {$mustbeoff} {
        if {![string equal $fans "off"]} {
          log::info "automatically switching off."
          set requestedfans "off"
        }
      } else {
        if {![string equal $fans "on"]} {
          log::info "automatically switching on."
          set requestedfans "on"
        }
      }
      
      if {![string equal $requestedfans $fans]} {
        server::setdata "requestedfans" $requestedfans
        if {[catch {
          if {[string equal $requestedfans "on"]} {
            switchonhardware
          } else {
            switchoffhardware
          }
        } message]} {
          log::error $message
        }
      }

    }
  }

  ######################################################################

  proc switchautomatically {} {
    server::checkstatus
    server::checkactivityformove
    log::info "switching automatically."
    server::setdata "mode" "automatic"
    return
  }

  proc switchon {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "mode" "manual"
    server::newactivitycommand "switching" "idle" fans::switchonactivitycommand
  }

  proc switchoff {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "mode" "manual"
    server::newactivitycommand "switching" "idle" fans::switchoffactivitycommand
  }
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::setdata "mode" "manual"
    server::newactivitycommand "initializing" "idle" fans::initializeactivitycommand
  }
  
  ######################################################################

  proc start {} {
    coroutine::every 1000 fans::updatedata
    server::newactivitycommand "starting" "started" fans::startactivitycommand
    server::setdata "mode" "started"
    after idle {
      coroutine::create fans::switchautomaticallyloop
    }
  }

}
