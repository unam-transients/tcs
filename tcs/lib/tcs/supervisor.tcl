########################################################################

# This file is part of the RATTEL supervisor control system.

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

config::setdefaultvalue "supervisor" "opentoventilateoffsetseconds" 1800
config::setdefaultvalue "supervisor" "openoffsetseconds"       0

namespace eval "supervisor" {

  ######################################################################

  variable withplc                      [config::getvalue "supervisor" "withplc"                ]
  variable internalhumiditysensor       [config::getvalue "supervisor" "internalhumiditysensor" ]
  variable opentoventilateoffsetseconds [config::getvalue "supervisor" "opentoventilateoffsetseconds"]
  variable openoffsetseconds            [config::getvalue "supervisor" "openoffsetseconds"      ]

  ######################################################################

  variable mode                 "disabled"
  variable maybeopen            false
  variable maybeopentoventilate false
  variable why                  "starting"
  variable open                 false
  variable opentoventilate      false
  variable closed               false
  variable accessrequested      false

  ######################################################################
  
  proc updatedata {} {
    variable mode
    variable maybeopen
    variable maybeopentoventilate
    variable open
    variable opentoventilate
    variable closed
    variable why
    server::setdata "mode"            $mode
    server::setdata "maybeopen"       $maybeopen
    server::setdata "maybeopentoventilate" $maybeopentoventilate
    server::setdata "open"            $open
    server::setdata "opentoventilate"      $opentoventilate
    server::setdata "closed"          $closed
    server::setdata "timestamp"       [utcclock::combinedformat now]
    server::setdata "why"             $why
  }
  
  ######################################################################
  
  proc loopreport {} {

    variable reportsun
    variable reportweather
    variable reportsensors
    variable reportplc
    variable internalhumiditysensor

    if {$reportsun} {
      set skystate [client::getdata "sun" "skystate"]
      set observedha [client::getdata "sun" "observedha"]
      if {[string equal "$skystate" "daylight"] || [string equal "$skystate" "night"]} {
        log::summary "sky state is $skystate."
      } elseif {$observedha < 0} {
        log::summary "sky state is morning $skystate."
      } else {
        log::summary "sky state is evening $skystate."
      }      
    }
    if {$reportweather} {
      if {[client::getdata "weather" "mustbeclosed"]} {
        log::summary "weather state is must be closed."
      } else {
        log::summary "weather state is may be open."
      }
    }
    if {$reportplc} {
      if {[client::getdata "plc" "mustbeclosed"]} {
        log::summary "plc state is must be closed."
      } else {
        log::summary "plc state is may be open."
      }
    }
    if {$reportweather} {
      catch {
        log::summary [format "external humidity is %.0f%%." [expr {[client::getdata "weather" "humidity"] * 100}]]
      }
    }
    if {$reportsensors && ![string equal $internalhumiditysensor ""]} {
      log::summary [format "internal humidity is %.0f%%." [expr {[client::getdata "sensors" "$internalhumiditysensor"] * 100}]]
    }
    
  }
  
  proc loop {} {
  
    variable withplc
    variable internalhumiditysensor
 
    variable mode
    variable open
    variable opentoventilate
    variable closed
    variable maybeopen
    variable maybeopentoventilate
    variable why
    
    variable reportsun
    variable reportweather
    variable reportsensors
    variable reportplc

    variable opentoventilateoffsetseconds
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

      set mustdisable false
      
      set reportsun     false
      set reportweather false
      set reportplc     false
      set reportsensors false
      
      set loopstartmode $mode

      if {[string equal $mode "closed"]} {

        set maybeopen false
        set maybeopentoventilate false
        set why "mode is closed"
        
      } elseif {
        ![string equal $mode "open"] &&
        [catch {client::update "weather"} message]
      } {

        log::debug "loop: unable to update weather data: $message"
        set maybeopen false
        set maybeopentoventilate false
        set why "no weather data"

      } elseif {
        ![string equal $mode "open"] &&
        [catch {client::update "sensors"} message]
      } {

        log::debug "loop: unable to update sensors data: $message"
        set maybeopen false
        set maybeopentoventilate false
        set why "no sensors data"

      } elseif {
        ![string equal $mode "open"] &&
        $withplc &&
        [catch {client::update "plc"} message]
      } {

        log::debug "loop: unable to update plc data: $message"
        set maybeopen false
        set maybeopentoventilate false
        set why "no plc data"

      } elseif {[catch {client::update "sun"} message]} {

        log::debug "loop: unable to update sun data: $message"
        set maybeopen false
        set maybeopentoventilate false
        set why "no sun data"

      } else {
      
        set reportsun true
        if {![string equal $mode "open"]} {
          set reportweather true
          set reportsensors true
          set reportplc     $withplc
        }
      
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
        
        # First determine if the Sun allows us to open.

        if {[string equal $skystate "night"] || [string equal $skystate "astronomicaltwilight"]} {

          set maybeopen true
          set maybeopentoventilate true
          set why "$skystate"

        } elseif {$seconds > $endofdayseconds - $openoffsetseconds} {

          set maybeopen true
          set maybeopentoventilate true
          set why "end of day"

        } elseif {$seconds > $endofdayseconds - $opentoventilateoffsetseconds} {

          set maybeopen false
          set maybeopentoventilate true
          set why "end of day"

        } elseif {[string equal $skystate "daylight"]} {

          set maybeopen false
          set maybeopentoventilate false
          set why "$skystate"
          set mustdisable $morning

        } elseif {$morning} {
 
          set maybeopen false
          set maybeopentoventilate false
          set why "morning $skystate"
            
        } else {

          set maybeopen true
          set maybeopentoventilate true
          set why "evening $skystate"

        }
        
        # Now determine if the weather/sensors override the Sun.
        
        if {![string equal $mode "disabled"] && ![string equal $mode "open"] && ($maybeopen || $maybeopentoventilate)} {

          if {
            [client::getdata "weather" "mustbeclosed"]
          } {

            set maybeopen false
            set maybeopentoventilate false
            set why "weather"

          } elseif {
            ($open || $opentoventilate) &&
            ![string equal $internalhumiditysensor ""] &&
            [client::getdata "sensors" "$internalhumiditysensor"] > 0.85
          } {

            # In this and the next clause, if the internal humidity is high, we
            # nevertheless allow the enclosure to open to ventilate if the
            # external humidity is 75% or less, on the basis that interchange
            # with external air will rapidly reduce the internal humidity.

            set maybeopen false
            if {[client::getdata "weather" "humidity"] <= 0.75} {
              set maybeopentoventilate true
            } else {
              set maybeopentoventilate false
            }
            set why "internal humidity"

          } elseif {
            $closed &&
            ![string equal $internalhumiditysensor ""] &&
            [client::getdata "sensors" "$internalhumiditysensor"] > 0.80
          } {
        
            # See the previous comment for an explanation of the check on the
            # external humidity.

            set maybeopen false
            if {[client::getdata "weather" "humidity"] <= 0.75} {
              set maybeopentoventilate true
            } else {
              set maybeopentoventilate false
            }
            set why "internal humidity"
            
          } elseif {
            $withplc &&
            [client::getdata "plc" "mustbeclosed"]
          } {

            set maybeopen false
            set maybeopentoventilate false
            set why "plc"

          }

        }

      }

      if {![string equal $loopstartmode $mode]} {
        set delay 0
        continue
      }

      updatedata
      catch {
        log::debug "loop: external humidity is [client::getdata "weather" "humidity"]."
      }
      catch {
        log::debug "loop: internal humidity is [client::getdata "sensors" "$internalhumiditysensor"]."
      }
      log::debug "loop: open is $open."
      log::debug "loop: opentoventilate is $opentoventilate."
      log::debug "loop: closed is $closed."
      log::debug "loop: maybeopen is $maybeopen."
      log::debug "loop: maybeopentoventilate is $maybeopentoventilate."
      log::debug "loop: why is $why."

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

      if {[catch {client::update "selector"} message]} {
        log::debug "loop: continue: unable to update selector data: $message"
        set delay 1000
        continue
      }
      if {[string equal [client::getdata "selector" "activity"] "starting"]} {
        log::debug "loop: continue: selector is starting."
        set delay 1000
        continue
      } 
      
      if {![string equal $loopstartmode $mode]} {
        set delay 0
        continue
      }

      if {[string equal [client::getdata "executor" "activity"] "started"]} {
        set start [utcclock::seconds]
        log::summary "initializing ($why)."
        server::setrequestedactivity "idle"
        server::setactivity "initializing"
        set open            false
        set opentoventilate false
        set closed          false
        updatedata
        if {![catch {
          client::request "executor" "reset"
          client::wait "executor"
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
      
      if {![string equal $loopstartmode $mode]} {
        set delay 0
        continue
      }

      if {$mustdisable} {

        set start [utcclock::seconds]
        log::summary "disabling ($why)."
        server::setrequestedactivity "idle"
        set mode "disabled"
        updatedata
        log::summary [format "finished disabling after %.1f seconds." [utcclock::diff now $start]]
        log::debug "loop: continue: finished disabling."
        set delay 1000
        continue
      } 
      
      if {![string equal $loopstartmode $mode]} {
        set delay 0
        continue
      }

      if {$maybeopen} {

        if {$open} {
          set delay 1000
          log::debug "loop: continue: already open."
          continue
        }
        loopreport
        set start [utcclock::seconds]
        log::summary "opening ($why)."
        server::setrequestedactivity "idle"
        server::setactivity "opening"
        set open            false
        set opentoventilate false
        set closed          false
        updatedata
        if {![catch {
          client::request "selector" "disable"
          client::wait "selector"
          client::request "executor" "recover"
          client::wait "executor"
          client::request "executor" "open"
          client::wait "executor"
          client::request "selector" "enable"
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

      } elseif {$maybeopentoventilate} {
      
        if {$opentoventilate} {
          log::debug "loop: continue: already open to ventilate."
          set delay 1000
          continue
        }
        loopreport
        set start [utcclock::seconds]
        log::summary "opening to ventilate ($why)."
        server::setrequestedactivity "idle"
        server::setactivity "opening"
        set open            false
        set opentoventilate false
        set closed          false
        updatedata
        if {![catch {
          client::request "selector" "disable"
          client::wait "selector"
          client::request "executor" "recover"
          client::wait "executor"
          client::request "executor" "opentoventilate"
          client::wait "executor"
        } message]} {
          set opentoventilate true
          updatedata
          log::summary [format "finished opening to ventilate after %.1f seconds." [utcclock::diff now $start]]
          log::debug "loop: continue: finished opening to ventilate."
          set delay 1000
          continue
        }
        log::error "unable to open to ventilate: $message"
        set mode "error"
        updatedata
        log::debug "loop: continue: unable to open to ventilate."
        set delay 60000
        continue

      } else {
      
        if {$closed} {
          log::debug "loop: continue: already closed."      
          set delay 1000
          continue
        }
        loopreport
        set start [utcclock::seconds]
        log::summary "closing ($why)."
        server::setrequestedactivity "idle"
        server::setactivity "closing"
        set open            false
        set opentoventilate false
        set closed          false
        updatedata
        if {![catch {
          client::request "selector" "disable"
          client::wait "selector"
          client::request "executor" "recover"
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
  
  proc plcaccessloop {} {
  
    while {true} {
    
      if {[catch {

        while {true} {
    
          coroutine::after 1000
      
          log::debug "plcaccessloop: updating plc data."
          client::update "plc"
        
          log::debug "plcaccessloop: checking if access has been requested."
          variable accessrequested
          if {
            ![client::getdata "plc" "accessrequested"] && 
            !$accessrequested
          } {
            log::debug "plcaccessloop: access has not been requested."
            continue
          }

          if {[client::getdata "plc" "accessrequested"]} {
            log::summary "access requested by the plc."
          }

          if {$accessrequested} {
            log::summary "access requested by the supervisor."
              set accessrequested false
          }

          set start [utcclock::seconds]
          log::summary "responding for request to access."

          log::summary "disabling supervisor."
          variable mode
          set mode "disabled"
          updatedata

          log::summary "disabling selector."
          if {[catch {
            client::request "selector" "disable" 
            client::wait "selector"
          } message]} {
            log::error "unable to disable selector: $message"
            log::error "unable to grant access."
            continue
          }

          log::summary "stopping executor."
          if {[catch {
            client::request "executor" "stop" 
            client::wait "executor"
          } message]} {
            log::error "unable to stop executor: $message"
            log::error "unable to grant access."
            continue
          }

          if {[client::getdata "plc" "accessrequested"]} {
            log::summary "granting access."
            if {[catch {
              client::request "plc" "grantaccess"
              client::wait "plc"
            } message]} {
              log::error "unable to grant access: $message"
              continue
            }
          }

          log::summary [format "finished responding for request to access after %.1f seconds." [utcclock::diff now $start]]
          
        }
      
      } message]} {
        log::warning "plcaccessloop: error: $message"
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
    catch { client::request "selector" "disable" }
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
  
  proc requestaccess {} {
    set start [utcclock::seconds]
    log::summary "requesting access."
    variable accessrequested
    set accessrequested true
    log::summary [format "finished requesting access after %.1f seconds." [utcclock::diff now $start]]
    return
  }

  proc emergencyclose {} {
    server::newactivitycommand "closing" "idle" \
      "supervisor::emergencycloseactivitycommand" 900e3
  }

  ######################################################################

  set server::datalifeseconds 0

  proc start {} {
    server::setactivity "starting"
    server::setrequestedactivity "idle"
    updatedata
    server::setstatus "ok"
    variable withplc
    if {$withplc} {
      after idle {
        coroutine ::supervisor::plcaccesscoroutine supervisor::plcaccessloop
      }
    }
    after idle {
      coroutine ::supervisor::loopcoroutine supervisor::loop
    }
  }

}

######################################################################
