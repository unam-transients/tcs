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
package require "controller"
package require "log"
package require "server"

config::setdefaultvalue "opentsi" "controllerport" "65432"
config::setdefaultvalue "opentsi" "controllerhost" "opentsi"

package provide "opentsi" 0.0

namespace eval "opentsi" {

  variable controllerhost [config::getvalue "opentsi" "controllerhost"]
  variable controllerport [config::getvalue "opentsi" "controllerport"]

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::connectiontype              "persistent"
  set controller::timeoutmilliseconds         10000
  set controller::intervalmilliseconds        50
  set controller::statusintervalmilliseconds  1000

  ######################################################################

  proc isauthenticationresponse {response} {
    expr {
      [regexp {TPL2 .*} $response] == 1 ||
      [regexp {AUTH OK .*} $response] == 1
    }
  }
  
  proc iseventresponse {response} {
    expr {
      [regexp {^[0-9]+ EVENT INFO } $response] == 1 ||
      [regexp {^[0-9]+ EVENT ERROR [^:]+:[0-9]+ No data available\.$} $response] == 1
    }
  }

  proc isignoredresponse {response} {
    expr {
      [regexp {^[0-9]+ DATA OK} $response] == 1 ||
      [regexp {^[0-9]+ EVENT ERROR .* No data available\.$} $response] == 1
    }
  }
  
  proc iserrorresponse {response} {
    expr {
      [regexp {^[0-9]+ EVENT ERROR } $response] == 1 ||
      [regexp {^[0-9]+ DATA ERROR } $response] == 1
    }
  }

  ######################################################################
  
  # We use command identifiers 1 for status command, 2 for emergency
  # stop, and 3-99 for normal commands,

  variable statuscommandidentifier        1
  variable emergencystopcommandidentifier 2
  variable firstnormalcommandidentifier   3
  variable lastnormalcommandidentifier    99
  
  ######################################################################

  variable currentcommandidentifier 0
  variable nextcommandidentifier $firstnormalcommandidentifier
  variable acceptedcurrentcommand
  variable completedcurrentcommand

  proc sendcommand {command} {
    variable currentcommandidentifier
    variable nextcommandidentifier
    variable acceptedcurrentcommand
    variable completedcurrentcommand
    variable firstnormalcommandidentifier
    variable lastnormalcommandidentifier
    set start [utcclock::seconds]
    set currentcommandidentifier $nextcommandidentifier
    if {$nextcommandidentifier == $lastnormalcommandidentifier} {
      set nextcommandidentifier $firstnormalcommandidentifier
    } else {
      set nextcommandidentifier [expr {$nextcommandidentifier + 1}]
    }
    set acceptedcurrentcommand false
    log::info "sending controller command: \"$currentcommandidentifier $command\"."
    controller::pushcommand "$currentcommandidentifier $command\n"
    coroutine::yield
    while {!$acceptedcurrentcommand} {
      coroutine::yield
    }
    set end [utcclock::seconds]
    log::debug [format "accepted controller command $currentcommandidentifier after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc sendcommandandwait {command} {
    variable currentcommandidentifier
    variable completedcurrentcommand
    set start [utcclock::seconds]
    set completedcurrentcommand false
    sendcommand $command
    coroutine::yield
    while {!$completedcurrentcommand} {
      coroutine::yield
    }
    set end [utcclock::seconds]
    log::debug [format "completed controller command $currentcommandidentifier after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################
  
  variable readystate     ""
  variable readystatetext ""
  
  variable communicationfailure false
  variable showevents           false

  proc updatedata {response} {
  
    variable readystate
    variable readystatetext

    variable communicationfailure

    set response [string trim $response]
    set response [string trim $response "\0"]
    
    if {[scan $response "%*d DATA INLINE TELESCOPE.READY_STATE=%f" value] == 1} {
      set readystate $value
      if {$value == -3.0} {
        set readystatetext "local or off"
      } elseif {$value == -2.0} {
        set readystatetext "emergency stop"
      } elseif {$value == -1.0} {
        set readystatetext "blocked"
      } elseif {$value == 0.0} {
        set readystatetext "off"
      } elseif {$value == 1.0} {
        set readystatetext "operational"
      } else {
        set readystatetext "intermediate"
      }
      if {[string equal [server::getstatus] "error"]} {
        server::setstatus "starting"
      }
      set communicationfailure false
      return false
    }

    if {$communicationfailure} {
      return true
    }

    if {
      [regexp {^[0-9]+ EVENT ERROR .* Data from telescope is not valid\.} $response] == 1 ||
      [regexp {^[0-9]+ EVENT ERROR .* does not exist\.} $response] == 1
    } {
      log::error "unable to communicate with the opentsi controller."
      server::setstatus "error"
      set communicationfailure true
      return true
    }
    
    if {[opentsi::isauthenticationresponse $response]} {
      log::info "received controller authentication response: \"$response\"."
      return false
    }
    
    variable statuscommandidentifier
    variable emergencystopcommandidentifier
    variable completedcommandidentifier

    if {[scan $response "%d " commandidentifier] != 1} {
      log::warning "received invalid controller response: \"$response\"."
      return true
    }

    if {[opentsi::isignoredresponse $response]} {
      if {$commandidentifier != $statuscommandidentifier} {
        log::debug "received controller response: \"$response\"."
      }
      return false
    }

    if {[opentsi::iserrorresponse $response]} {
      log::warning "received controller error response: \"$response\"."
      return false
    }

    if {$commandidentifier == $emergencystopcommandidentifier} {
      log::info "received controller response: \"$response\"."
      if {[regexp {^[0-9]+ COMMAND COMPLETE} $response] == 1} {
        log::warning "finished emergency stop."
        return false
      }
    }

    variable showevents

    if {[opentsi::iseventresponse $response]} {
      if {$showevents} {
        log::info "received controller event response: \"$response\"."
      } else {
        log::debug "received controller event response: \"$response\"."
      }
      return false
    }

    variable currentcommandidentifier
    variable acceptedcurrentcommand
    variable completedcurrentcommand

    if {[regexp {^[0-9]+ COMMAND OK} $response] == 1} {
      if {$commandidentifier != $statuscommandidentifier} {
        log::info "received controller response: \"$response\"."
        if {$commandidentifier == $currentcommandidentifier} {
          log::info "current controller command accepted."
          set acceptedcurrentcommand true
        }
      }
      return false
    }
    
    if {[regexp {^[0-9]+ COMMAND COMPLETE} $response] == 1} {
      if {$commandidentifier != $statuscommandidentifier} {
        log::info "received controller response: \"$response\"."
        if {$commandidentifier == $currentcommandidentifier} {
          log::info "current controller command completed."
          set completedcurrentcommand true
        }
        return false
      }
    }

    variable higherupdatedata
    return [$higherupdatedata $response]

  }

  ######################################################################
  
  proc readystate {} {
    variable readystatetext
    return $readystatetext
  }
  
  proc isoperational {} {
    variable readystatetext
    if {[string equal $readystatetext "operational"]} {
      return true
    } else {
      return false
    }
  }
  
  ######################################################################
  
  proc checkreadystate {requiredreadystatetext} {
    variable readystatetext
    if {![string equal $readystatetext $requiredreadystatetext]} {
      error "the telescope controller state is not $requiredreadystatetext."
    }
  }
  
  ######################################################################

  proc start {statuscommand updatedata {showeventsarg false}} {
    variable statuscommandidentifier
    set controller::statuscommand "$statuscommandidentifier $statuscommand;TELESCOPE.READY_STATE\n"
    set controller::updatedata    "opentsi::updatedata"
    variable higherupdatedata
    set higherupdatedata "$updatedata"
    variable showevents
    set showevents $showeventsarg
    controller::startcommandloop "AUTH PLAIN \"admin\" \"admin\"\n"
    controller::startstatusloop
  }

  ######################################################################

}
