########################################################################

# This file is part of the UNAM telescope control system.

# $Id: secondarycoatlioan.tcl 3601 2020-06-11 03:20:53Z Alan $

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

  proc isignoredresponse {response} {
    expr {
      [regexp {TPL2 .*} $response] == 1 ||
      [regexp {AUTH OK .*} $response] == 1 ||
      [regexp {^[0-9]+ COMMAND OK}  $response] == 1 ||
      [regexp {^[0-9]+ DATA OK}     $response] == 1 ||
      [regexp {^[0-9]+ EVENT INFO } $response] == 1
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
  variable completedcurrentcommand

  proc sendcommand {command} {
    variable currentcommandidentifier
    variable nextcommandidentifier
    variable completedcurrentcommand
    variable firstnormalcommandidentifier
    variable lastnormalcommandidentifier
    set currentcommandidentifier $nextcommandidentifier
    if {$nextcommandidentifier == $lastnormalcommandidentifier} {
      set nextcommandidentifier $firstnormalcommandidentifier
    } else {
      set nextcommandidentifier [expr {$nextcommandidentifier + 1}]
    }
    log::debug "sending controller command: \"$currentcommandidentifier $command\"."
    controller::pushcommand "$currentcommandidentifier $command\n"
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

  proc updatedata {response} {
  
    variable readystate
    variable readystatetext

    variable communicationfailure

    set response [string trim $response]
    set response [string trim $response "\0"]
    
    if {[scan $response "%*d DATA INLINE TELESCOPE.READY_STATE=%f" value] == 1} {
      set readystate $value
      if {$value == -3.0} {
        set readystatetext "local"
      } elseif {$value == -2.0} {
        set readystatetext "emergencystop"
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
    
    if {[opentsi::isignoredresponse $response]} {
      return false
    }

    if {[opentsi::iserrorresponse $response]
    } {
      log::warning "controller error: \"$response\"."
      return false
    }

    if {![scan $response "%d " commandidentifier] == 1} {
      log::warning "unexpected controller response \"$response\"."
      return true
    }

    variable statuscommandidentifier
    variable emergencystopcommandidentifier
    variable completedcommandidentifier

    if {$commandidentifier == $emergencystopcommandidentifier} {
      log::debug "controller response \"$response\"."
      if {[regexp {^[0-9]+ COMMAND COMPLETE} $response] == 1} {
        log::warning "finished emergency stop."
        return false
      }
    }

    if {$commandidentifier != $statuscommandidentifier} {
      variable currentcommandidentifier
      variable completedcurrentcommand
      log::debug "controller response \"$response\"."
      if {[regexp {^[0-9]+ COMMAND COMPLETE} $response] == 1} {
        log::debug [format "controller command %d completed." $commandidentifier]
        if {$commandidentifier == $currentcommandidentifier} {
          log::debug "current controller command completed."
          set completedcurrentcommand true
        }
      }
      return false
    }
    

    
    if {[scan $response "%*d DATA INLINE TELESCOPE.READY_STATE=%f" value] == 1} {
      set readystate $value
      if {$value == -3.0} {
        set readystatetext "local"
      } elseif {$value == -2.0} {
        set readystatetext "emergencystop"
      } elseif {$value == -1.0} {
        set readystatetext "blocked"
      } elseif {$value == 0.0} {
        set readystatetext "off"
      } elseif {$value == 1.0} {
        set readystatetext "operational"
      } else {
        set readystatetext "intermediate"
      }
      return false
    }

    variable higherupdatedata
    return [$higherupdatedata $response]

  }

  ######################################################################

  proc start {statuscommand updatedata} {
    variable statuscommandidentifier
    set controller::statuscommand "$statuscommandidentifier $statuscommand;TELESCOPE.READY_STATE\n"
    set controller::updatedata    "opentsi::updatedata"
    variable higherupdatedata
    set higherupdatedata "$updatedata"
    controller::startcommandloop "AUTH PLAIN \"admin\" \"admin\"\n"
    controller::startstatusloop
  }

  ######################################################################

}
