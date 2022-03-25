########################################################################

# This file is part of the UNAM telescope control system.

# $Id: coverscoatlioan.tcl 3601 2020-06-11 03:20:53Z Alan $

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

  variable svnid {$Id}

  ######################################################################

  variable controllerhost [config::getvalue "opentsi" "controllerhost"]
  variable controllerport [config::getvalue "opentsi" "controllerport"]

  ######################################################################

  server::setdata "timestamp"        [utcclock::combinedformat now]
  server::setdata "readystate"       ""
  server::setdata "referencestate"   ""
  server::setdata "errorstate"       ""

  variable settledelayseconds 5

  ######################################################################

  # We use command identifiers 1 for status command, 2 for emergency
  # stop, and 3-99 for normal commands,

  variable statuscommandidentifier        1
  variable emergencystopcommandidentifier 2
  variable firstnormalcommandidentifier   3
  variable lastnormalcommandidentifier    99

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::connectiontype              "persistent"
  set controller::statuscommand "$statuscommandidentifier GET [join {
    TELESCOPE.READY_STATE
  } ";"]\n"
  set controller::timeoutmilliseconds         10000
  set controller::intervalmilliseconds        50
  set controller::updatedata                  opentsi::updatecontrollerdata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 30

  ######################################################################

  proc isignoredcontrollerresponse {controllerresponse} {
    expr {
      [regexp {TPL2 .*} $controllerresponse] == 1 ||
      [regexp {AUTH OK .*} $controllerresponse] == 1 ||
      [regexp {^[0-9]+ COMMAND OK}  $controllerresponse] == 1 ||
      [regexp {^[0-9]+ DATA OK}     $controllerresponse] == 1 ||
      [regexp {^[0-9]+ EVENT INFO } $controllerresponse] == 1
    }
  }

  variable readystate

  proc updatecontrollerdata {controllerresponse} {

    variable readystate

    set controllerresponse [string trim $controllerresponse]
    set controllerresponse [string trim $controllerresponse "\0"]
    
    if {[isignoredcontrollerresponse $controllerresponse]} {
      return false
    }

    if {
      [regexp {^[0-9]+ EVENT ERROR } $controllerresponse] == 1 ||
      [regexp {^[0-9]+ DATA ERROR } $controllerresponse] == 1
    } {
      log::warning "controller error: \"$controllerresponse\"."
      return false
    }

    if {![scan $controllerresponse "%d " commandidentifier] == 1} {
      log::warning "unexpected controller response \"$controllerresponse\"."
      return true
    }

    variable statuscommandidentifier
    variable emergencystopcommandidentifier
    variable completedcommandidentifier

    if {$commandidentifier != $statuscommandidentifier} {
      variable currentcommandidentifier
      variable completedcurrentcommand
      log::debug "controller response \"$controllerresponse\"."
      if {[regexp {^[0-9]+ COMMAND COMPLETE} $controllerresponse] == 1} {
        log::debug [format "controller command %d completed." $commandidentifier]
        if {$commandidentifier == $currentcommandidentifier} {
          log::debug "current controller command completed."
          set completedcurrentcommand true
        }
      }
      return false
    }

    if {[scan $controllerresponse "%*d DATA INLINE TELESCOPE.READY_STATE=%f" value] == 1} {
      set readystate $value
      return false
    }

    if {[regexp {[0-9]+ DATA INLINE } $controllerresponse] == 1} {
      log::debug "status: ignoring DATA INLINE response."
      return false
    }
    if {[regexp {[0-9]+ COMMAND COMPLETE} $controllerresponse] != 1} {
      log::warning "unexpected controller response \"$controllerresponse\"."
      return true
    }

    set timestamp [utcclock::combinedformat "now"]

    set lasttimestamp      [server::getdata "timestamp"]
    set lastreadystate     [server::getdata "readystate"]
    
    if {![string equal $lastreadystate ""] && ![string equal $readystate $lastreadystate]} {
      log::info "ready state changed from $lastreadystate to $readystate."
    }

    server::setdata "timestamp"        $timestamp
    server::setdata "readystate"       $readystate

    server::setstatus "ok"

    return true
  }

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
    log::debug "sending controller command $currentcommandidentifier: \"$command\"."
    controller::pushcommand "$currentcommandidentifier $command\n"
  }

  proc switchon {} {
    variable readystate
    sendcommand "SET TELESCOPE.POWER=1"
    while {$readystate != 1.0} {
      coroutine::yield
    }
  }
  
  proc switchoff {} {
    variable readystate
    sendcommand "SET TELESCOPE.POWER=0"
    while {$readystate != 0.0} {
      coroutine::yield
    }
  }
  
  proc stop {} {
    sendcommand "SET TELESCOPE.STOP=1"
  }
  
  ######################################################################
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    switchon
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    switchon
    set end [utcclock::seconds]
    log::info [format "finished opening after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    switchoff
    set end [utcclock::seconds]
    log::info [format "finished closing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc stopactivitycommand {previousactivity} {
    set start [utcclock::seconds]
    log::info "stopping."
    stop
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" covers::initializeactivitycommand
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] "covers::stopactivitycommand [server::getactivity]"
  }
  
  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] covers::stopactivitycommand
  }

  proc open {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "opening" "idle" covers::openactivitycommand
  }

  proc close {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "closing" "idle" covers::closeactivitycommand
  }

  ######################################################################

  proc start {} {
    server::setstatus "ok"
    controller::startcommandloop "AUTH PLAIN \"admin\" \"admin\"\n"
    controller::startstatusloop
    server::newactivitycommand "starting" "started" opentsi::startactivitycommand
  }

  ######################################################################

}
