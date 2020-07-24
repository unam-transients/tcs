########################################################################

# This file is part of the UNAM telescope control system.

# $Id: pirani.tcl 3588 2020-05-26 23:41:05Z Alan $

########################################################################

# Copyright © 2013, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "log"
package require "utcclock"

package provide "pirani" 0.0

namespace eval "pirani" {

  variable svnid {$Id}

  ######################################################################

  set server::datalifeseconds 120

  ######################################################################
  
  variable maxsafepressure 5e-3
  variable alarmdelay      300
  
  ######################################################################
  
  server::setdata "alarm"    "ok"
  
  ######################################################################
  
  proc formatpressure {pressure} {
    if {[string is double -strict $pressure]} {
      return [format "%.1e Torr" $pressure]
    } else {
      return $pressure
    }
  }
  
  proc trend {value lastvalue lasttrend} {
    if {[string equal $lastvalue "unknown"]} {
      return "unknown"
    } elseif {$lastvalue < $value} {
      return "rising"
    } elseif {$lastvalue > $value} {
      return "falling"
    } else {
      return $lasttrend
    }
  }

  ######################################################################

  proc updatedata {} {
  
    log::debug "updating data."
  
    variable maxsafepressure
    variable alarmdelay
    
    set pressure                 "unknown"
    set lastpressure             "unknown"
    set pressuretrend            "unknown"

    set channel [open "/usr/local/var/ratir/cryostat.log" "r"]

    while {true} {

      set line [coroutine::gets $channel]
      if {[eof $channel]} {
        break
      }

      if {[scan $line "PRESS %s UTC () %f" timestamp pressure] == 2} {
        set timestampseconds [utcclock::scan $timestamp]
        set timestamp        [utcclock::combinedformat $timestampseconds]
        set pressuretrend    [trend $pressure $lastpressure $pressuretrend]
        set lastpressure     $pressure        
      }

    }
    
    close $channel
    
    if {[string equal $pressure "unknown"] || [utcclock::diff now $timestamp] > $alarmdelay} {
      set alarm "warning"
      set log log::warning
    } elseif {$pressure > $maxsafepressure} {
      set alarm "critical"
      set log log::error
    } else {
      set alarm "ok"
      set log log::info
    }
    set lastalarm [server::getdata "alarm"]
    if {![string equal $alarm $lastalarm]} {
      $log "the pressure is [formatpressure $pressure] and $pressuretrend."
    }

    server::setdata "timestamp"     $timestamp
    server::setdata "alarm"         $alarm
    server::setdata "pressure"      $pressure
    server::setdata "pressuretrend" $pressuretrend
    
    log::writedatalog "pirani" {
      timestamp
      alarm
      pressure pressuretrend
    }

  }

  ######################################################################

  variable updatedatapollseconds 15

  proc updatedataloop {} {
    variable updatedatapollseconds
    while {true} {
      if {[catch {updatedata} message]} {
        log::debug "while updating data: $message"
      } else {
        server::setstatus  "ok"
      }
      set updatedatapollmilliseconds [expr {$updatedatapollseconds * 1000}]
      coroutine::after $updatedatapollmilliseconds
    }
  }

  ######################################################################

  proc start {} {
    after idle {
      server::setrequestedactivity "idle"
      server::setactivity          "idle"
      coroutine pirani::updatedataloopcoroutine pirani::updatedataloop
    }
  }

}
