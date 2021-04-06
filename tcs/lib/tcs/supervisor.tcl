########################################################################

# This file is part of the RATTEL supervisor control system.

# $Id: supervisor.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2014, 2015, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "client"
package require "server"
package require "utcclock"

package provide "supervisor" 0.0

config::setdefaultvalue "supervisor" "opentocooloffsetseconds" 1800
config::setdefaultvalue "supervisor" "openoffsetseconds"       0

namespace eval "supervisor" {

  variable svnid {$Id}

  ######################################################################

  variable withplc                 [config::getvalue "supervisor" "withplc"                ]
  variable internalhumiditysensor  [config::getvalue "supervisor" "internalhumiditysensor" ]
  variable opentocooloffsetseconds [config::getvalue "supervisor" "opentocooloffsetseconds"]
  variable openoffsetseconds       [config::getvalue "supervisor" "openoffsetseconds"      ]

  ######################################################################

  variable mode            "disabled"
  variable maybeopen       false
  variable maybeopentocool false
  variable why             "starting"
  variable open            false
  variable opentocool      false
  variable closed          false

  ######################################################################
  
  proc updatedata {} {
    variable mode
    variable maybeopen
    variable maybeopentocool
    variable open
    variable opentocool
    variable closed
    variable why
    server::setdata "mode"            $mode
    server::setdata "maybeopen"       $maybeopen
    server::setdata "maybeopentocool" $maybeopentocool
    server::setdata "open"            $open
    server::setdata "opentocool"      $opentocool
    server::setdata "closed"          $closed
    server::setdata "timestamp"       [utcclock::combinedformat now]
    server::setdata "why"             $why
  }
  
  ######################################################################
  
  proc loop {} {
  
    variable withplc
    variable internalhumiditysensor
 
    variable mode
    variable open
    variable opentocool
    variable closed
    variable maybeopen
    variable maybeopentocool
    variable why

    variable opentocooloffsetseconds
    variable openoffsetseconds

    log::debug "loop: starting."
    
    set delay 0

    while {true} {
        
      server::setactivity "idle"
      if {$delay != 0} {
        log::debug "loop: waiting for ${delay}ms."
        coroutine::after $delay
      }      
      
      log::debug "loop: mode is $mode."

      if {[string equal $mode "disabled"]} {

        log::debug "loop: continue: mode is disabled."
        set delay 1000
        continue

      }
            
      if {[string equal $mode "error"]} {

        log::debug "loop: continue: mode is error."
        set delay 1000
        continue

      }
            
      set mustdisable false

      if {[string equal $mode "closed"]} {

        set maybeopen false
        set maybeopentocool false
        set why "closed"
        
      } elseif {
        ![string equal $mode "open"] &&
        [catch {client::update "weather"} message]
      } {

        log::debug "loop: unable to update weather data: $message"
        set maybeopen false
        set maybeopentocool false
        set why "no weather data"

      } elseif {
        [catch {client::update "sensors"} message]
      } {

        log::debug "loop: unable to update sensors data: $message"
        set maybeopen false
        set maybeopentocool false
        set why "no sensors data"

      } elseif {
        ![string equal $mode "open"] &&
        $withplc &&
        [catch {client::update "plc"} message]
      } {

        log::debug "loop: unable to update plc data: $message"
        set maybeopen false
        set maybeopentocool false
        set why "no plc data"

      } elseif {[catch {client::update "sun"} message]} {

        log::debug "loop: unable to update sun data: $message"
        set maybeopen false
        set maybeopentocool false
        set why "no sun data"

      } else {
      
        set skystate [client::getdata "sun" "skystate"]
        set observedha [client::getdata "sun" "observedha"]
        if {$observedha < 0} {
          set morning true
        } else {
          set morning false
        }
        set seconds         [utcclock::seconds]
        set endofdayseconds [utcclock::scan [client::getdata "sun" "endofday"]]
        
        log::debug "loop: skystate is $skystate." 
        log::debug "loop: morning is $morning." 
        log::debug "loop: end of day in [format "%.0f" [expr {$endofdayseconds - $seconds}]] seconds." 

        if {
          ![string equal $mode "open"] &&
          [client::getdata "weather" "mustbeclosed"]
        } {

          set maybeopen false
          set maybeopentocool false
          set why "weather"

        } elseif {
          $open &&
          ![string equal $internalhumiditysensor ""] &&
          [client::getdata "sensors" "$internalhumiditysensor"] > 0.85
        } {

          set maybeopen false
          set maybeopentocool false
          set why "internal humidity"

        } elseif {
          $closed &&
          ![string equal $internalhumiditysensor ""] &&
          [client::getdata "sensors" "$internalhumiditysensor"] > 0.80
        } {

          set maybeopen false
          set maybeopentocool false
          set why "internal humidity"

        } elseif {
          ![string equal $mode "open"] &&
          $withplc &&
          [client::getdata "plc" "mustbeclosed"]
        } {

          set maybeopen false
          set maybeopentocool false
          set why "plc"

        } elseif {[string equal $skystate "night"] || [string equal $skystate "astronomicaltwilight"]} {

          set maybeopen true
          set maybeopentocool true
          set why "$skystate"

        } elseif {$seconds > $endofdayseconds - $opentocooloffsetseconds} {

          set maybeopen false
          set maybeopentocool true
          set why "end of day"

        } elseif {$seconds > $endofdayseconds - $openoffsetseconds} {

          set maybeopen true
          set maybeopentocool true
          set why "end of day"

        } elseif {[string equal $skystate "daylight"]} {

          set maybeopen false
          set maybeopentocool false
          set why "$skystate"
          set mustdisable $morning

        } elseif {$morning} {
 
          set maybeopen false
          set maybeopentocool false
          set why "morning $skystate"
            
        } else {

          set maybeopen true
          set maybeopentocool true
          set why "evening $skystate"

        }

      }

      updatedata
      log::debug "loop: open is $open."
      log::debug "loop: opentocool is $opentocool."
      log::debug "loop: closed is $closed."
      log::debug "loop: maybeopen is $maybeopen."
      log::debug "loop: maybeopentocool is $maybeopentocool."
      log::debug "loop: why is $why."

      if {[catch {client::update "executor"} message]} {
        log::debug "loop: continue: unable to update executor data: $message"
        set delay 1000
        continue
      }
      if {[string equal [client::getdata "executor" "activity"] "starting"]} {
        log::debug "loop: continue: executor is starting."
        set delay 1000
        continue
      } 

      if {[catch {client::update "scheduler"} message]} {
        log::debug "loop: continue: unable to update scheduler data: $message"
        set delay 1000
        continue
      }
      if {[string equal [client::getdata "scheduler" "activity"] "starting"]} {
        log::debug "loop: continue: scheduler is starting."
        set delay 1000
        continue
      } 
      
      if {[string equal [client::getdata "executor" "activity"] "started"]} {
        set start [utcclock::seconds]
        log::summary "initializing."
        server::setrequestedactivity "idle"
        server::setactivity "initializing"
        set open       false
        set opentocool false
        set closed     false
        updatedata
        if {![catch {
          client::request "executor" "reset"
          client::wait "executor"
          client::request "executor" "initialize"
          client::wait "executor"
        } message]} {
          set closed true
          updatedata          
          log::summary [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]  
          log::debug "loop: continue: finished initializing."      
          set delay 1000
          continue
        }
        log::error "unable to initialize: $message"
        set mode "error"
        updatedata
        log::debug "loop: continue: unable to initialize: $message"
        set delay 60000
        continue
      } 
      
      if {$mustdisable} {

        set start [utcclock::seconds]
        log::summary "disabling."
        server::setrequestedactivity "idle"
        set mode "disabled"
        updatedata
        log::summary [format "finished disabling after %.1f seconds." [utcclock::diff now $start]]
        log::debug "loop: continue: finished disabling."
        set delay 1000
        continue
      } 
      
      if {$maybeopen} {

        if {$open} {
          set delay 1000
          log::debug "loop: continue: already open."
          continue
        }
        set start [utcclock::seconds]
        log::summary "opening."
        server::setrequestedactivity "idle"
        server::setactivity "opening"
        set open        false
        set opentoclose false
        set closed      false
        updatedata
        if {![catch {
          client::request "scheduler" "disable"
          client::wait "scheduler"
          client::request "executor" "reset"
          client::wait "executor"
          client::request "executor" "open"
          client::wait "executor"
          client::request "scheduler" "enable"
        } message]} {
          set open true
          updatedata
          log::summary [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
          log::debug "loop: continue: finished opening."
          set delay 1000
          continue
        }
        log::error "unable to open: $message"
        set mode "error"
        updatedata
        log::debug "loop: continue: unable to open."
        set delay 60000
        continue

      } elseif {$maybeopentocool} {
      
        if {$opentocool} {
          log::debug "loop: continue: already open to cool."
          set delay 1000
          continue
        }
        set start [utcclock::seconds]
        log::summary "opening to cool."
        server::setrequestedactivity "idle"
        server::setactivity "opening"
        set open        false
        set opentoclose false
        set closed      false
        updatedata
        if {![catch {
          client::request "scheduler" "disable"
          client::wait "scheduler"
          client::request "executor" "reset"
          client::wait "executor"
          client::request "executor" "opentocool"
          client::wait "executor"
        } message]} {
          set opentocool true
          updatedata
          log::summary [format "finished opening to cool after %.1f seconds." [utcclock::diff now $start]]
          log::debug "loop: continue: finished opening to cool."
          set delay 1000
          continue
        }
        log::error "unable to open to cool: $message"
        set mode "error"
        updatedata
        log::debug "loop: continue: unable to open to cool."
        set delay 60000
        continue

      } else {
      
        if {$closed} {
          log::debug "loop: continue: already closed."      
          set delay 1000
          continue
        }
        set start [utcclock::seconds]
        log::summary "closing."
        server::setrequestedactivity "idle"
        server::setactivity "closing"
        set open       false
        set opentocool false
        set closed     false
        updatedata
        if {![catch {
          client::request "scheduler" "disable"
          client::wait "scheduler"
          client::request "executor" "reset"
          client::wait "executor"
          client::request "executor" "close"
          client::wait "executor"
        } message]} {
          log::summary [format "finished closing after %.1f seconds." [utcclock::diff now $start]]
          set closed true
          updatedata
          log::debug "loop: continue: finished closing."      
          set delay 1000
          continue
        }
        log::error "unable to close: $message"
        log::summary "emergency closing."
        catch {
          client::request "executor" "emergencyclose"
          client::wait "executor"
        }
        set mode "error"
        updatedata
        log::debug "loop: continue: after emergency close."      
        set delay 60000
        continue
        
      }
      
    }

  }
  
  ######################################################################

  proc emergencycloseactivitycommand {} {
    set start [utcclock::seconds]
    log::summary "emergency closing."
    variable mode
    set mode "error"
    updatedata
    if {![catch {
      client::waituntilstarted "executor"
      client::request "executor" "emergencyclose"
      client::wait "executor"
    } message]} {
      log::summary [format "finished emergency closing after %.1f seconds." [utcclock::diff now $start]]
      set closed true
      updatedata
    } else {
      log::error "unable to emergency close: $message"
    }
  }

  ######################################################################
    
  proc enable {} {
    set start [utcclock::seconds]
    log::summary "setting mode to \"enabled\"."
    variable mode
    set mode "enabled"
    updatedata
    log::summary [format "finished setting mode to \"enabled\" after %.1f seconds." [utcclock::diff now $start]]
    return
  }

  proc disable {} {
    set start [utcclock::seconds]
    log::summary "setting mode to \"disabled\"."
    variable mode
    set mode "disabled"
    updatedata
    log::summary [format "finished setting mode to \"disabled\" after %.1f seconds." [utcclock::diff now $start]]
    return
  }

  proc open {} {
    set start [utcclock::seconds]
    log::summary "setting mode to \"open\"."
    variable mode
    set mode "open"
    updatedata
    log::summary [format "finished setting mode to \"open\" after %.1f seconds." [utcclock::diff now $start]]
    return
  }

  proc close {} {
    set start [utcclock::seconds]
    log::summary "setting mode to \"closed\"."
    variable mode
    set mode "closed"
    updatedata
    log::summary [format "finished setting mode to \"closed\" after %.1f seconds." [utcclock::diff now $start]]
    return
  }

  proc emergencyclose {} {
    server::newactivitycommand "closing" "idle" \
      "supervisor::emergencycloseactivitycommand" 900e3
  }

  ######################################################################

  set server::datalifeseconds 0

  proc start {} {
    server::setstatus "starting"
    server::setactivity "starting"
    server::setrequestedactivity "idle"
    updatedata
    server::setstatus "ok"
    after idle {
      coroutine ::supervisor::loopcoroutine supervisor::loop
    }
  }

}

######################################################################
