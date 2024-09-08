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

package provide "louvers" 0.0

namespace eval "louvers" {

  variable internaltemperaturesensor [config::getvalue "louvers" "internaltemperaturesensor"]

  ######################################################################

  set server::datalifeseconds 30

  ######################################################################

  server::setdata "requestedlouvers"  ""
  server::setdata "louvers"           ""
  server::setdata "mode"              ""
  server::setdata "timestamp"         ""

  ######################################################################
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    updatedata
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    server::setdata "requestedlouvers" "closed"
    log::info "closing louvers."
    closehardware
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc openactivitycommand {} {
    set start [utcclock::seconds]
    server::setdata "requestedlouvers" "open"
    log::info "opening louvers."
    openhardware
    log::info [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    server::setdata "requestedlouvers" "closed"
    log::info "closing louvers."
    closehardware
    log::info [format "finished closing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc emergencycloseactivitycommand {} {
    set start [utcclock::seconds]
    server::setdata "requestedlouvers" "closed"
    log::info "emergency closing louvers."
    closehardware
    log::info [format "finished emergency closing after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

  variable coolloopseconds 10

  server::setdata "mustbeclosed"        ""
  server::setdata "externaltemperature" ""
  server::setdata "internaltemperature" ""

  proc coolloop {} {

    variable internaltemperaturesensor
    variable coolloopseconds

    log::debug "coolloop: starting."

    while {true} {

      set coolloopmilliseconds [expr {$coolloopseconds * 1000}]
      coroutine::after $coolloopmilliseconds

      log::debug "coolloop: updating sensors data."
      if {[catch {client::update "sensors"} message]} {
        log::debug "while updating sensors data: $message"
        set mustbeclosedsensors true
        set internaltemperature ""
      } else {
        set mustbeclosedsensors false
        set internaltemperature [client::getdata "sensors" $internaltemperaturesensor]
      }

      log::debug "coolloop: updating weather data."
      if {[catch {client::update "weather"} message]} {
        log::debug "while updating weather data: $message"
        set mustbeclosedweather true
        set externaltemperature ""
      } else {
        set mustbeclosedweather [client::getdata "weather" "mustbeclosed"]
        set externaltemperature [client::getdata "weather" "temperature"]
      }
        
      if {$mustbeclosedsensors || $mustbeclosedweather} {
        set mustbeclosed true
      } else {
        set mustbeclosed false
      }

      server::setdata "mustbeclosed"        $mustbeclosed
      server::setdata "externaltemperature" $externaltemperature
      server::setdata "internaltemperature" $internaltemperature

      log::debug [format "coolloop: mode is %s." [server::getdata "mode"]]
      if {![string equal [server::getdata "mode"] "cool"]} {
        continue
      }
      
      set louvers [server::getdata "louvers"]

      if {$mustbeclosed} {
        if {![string equal $louvers "closed"]} {
          log::info "louvers must be closed."
          set requestedlouvers "closed"
        }
      } elseif {
        $externaltemperature > $internaltemperature + 0.1
      } {
        if {![string equal $louvers "closed"]} {
          log::info "automatically closing to avoid heating."
          set requestedlouvers "closed"
        }
      } elseif {
        $externaltemperature < $internaltemperature - 0.1
      } {
        if {![string equal $louvers "open"]} {
          log::info "automatically opening to allow cooling."
          set requestedlouvers "open"
        }
      } else {
        set requestedlouvers $louvers
      }
      
      if {![string equal $requestedlouvers $louvers]} {
        server::setdata "requestedlouvers" $requestedlouvers
        if {[catch {
          if {[string equal $requestedlouvers "open"]} {
            openhardware
          } else {
            closehardware
          }
        } message]} {
          log::error $message
        }
      }

    }
  }

  ######################################################################

  proc cool {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "mode" "cool"
    return
  }

  proc open {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "mode" "open"
    server::newactivitycommand "opening" "idle" louvers::openactivitycommand
  }

  proc close {} {
    server::checkstatus
    server::checkactivityformove
    server::setdata "mode" "closed"
    server::newactivitycommand "closing" "idle" louvers::closeactivitycommand
  }
  
  proc emergencyclose {} {
    server::setdata "mode" "closed"
    server::newactivitycommand "closing" [server::getstoppedactivity] louvers::emergencycloseactivitycommand
  }
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::setdata "mode" "closed"
    server::newactivitycommand "initializing" "idle" louvers::initializeactivitycommand
  }
  
  ######################################################################

  proc start {} {
    coroutine::every 1000 louvers::updatedata
    server::newactivitycommand "starting" "started" louvers::startactivitycommand
    server::setdata "mode" "started"
    after idle {
      coroutine::create louvers::coolloop
    }
  }

}
