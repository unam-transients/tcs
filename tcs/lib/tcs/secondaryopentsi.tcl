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

config::setdefaultvalue "secondary" "controllerport" "65432"
config::setdefaultvalue "secondary" "controllerhost" "opentsi"

package provide "secondaryopentsi" 0.0

namespace eval "secondary" {

  variable svnid {$Id}

  ######################################################################

  variable controllerhost [config::getvalue "secondary" "controllerhost"]
  variable controllerport [config::getvalue "secondary" "controllerport"]

  ######################################################################

  server::setstatus "ok"
  server::setdata "z"                ""
  server::setdata "zlowerlimit"      ""
  server::setdata "zupperlimit"      ""
  server::setdata "zerror"           ""
  server::setdata "timestamp"        [utcclock::combinedformat now]

  variable settledelayseconds 1

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
    POSITION.INSTRUMENTAL.FOCUS.LIMIT_STATE
    POSITION.INSTRUMENTAL.FOCUS.MOTION_STATE
    POSITION.INSTRUMENTAL.FOCUS.OFFSET
    POSITION.INSTRUMENTAL.FOCUS.TARGETDISTANCE
  } ";"]\n"
  set controller::timeoutmilliseconds         10000
  set controller::intervalmilliseconds        50
  set controller::updatedata                  secondary::updatecontrollerdata
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

  variable moving

  variable pendingmode
  variable pendingz
  variable pendingzerror
  variable pendingzlowerlimit
  variable pendingzupperlimit

  proc updatecontrollerdata {controllerresponse} {
  
    variable moving

    variable pendingmode
    variable pendingz
    variable pendingzerror
    variable pendingzlowerlimit
    variable pendingzupperlimit

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

    if {$commandidentifier == $emergencystopcommandidentifier} {
      log::debug "controller response \"$controllerresponse\"."
      if {[regexp {^[0-9]+ COMMAND COMPLETE} $controllerresponse] == 1} {
        finishemergencystop
        return false
      }
    }

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

    #log::debug "status: controller response \"$controllerresponse\"."
    if {[scan $controllerresponse "%*d DATA INLINE TELESCOPE.READY_STATE=%f" value] == 1} {
      if {$value == -3.0} {
        set pendingmode "local"
      } elseif {$value == -2.0} {
        set pendingmode "emergencystop"
      } elseif {$value == -1.0} {
        set pendingmode "blocked"
      } elseif {$value == 0.0} {
        set pendingmode "off"
      } elseif {$value == 1.0} {
        set pendingmode "on"
      } else {
        set pendingmode "intermediate"
      }
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE POSITION.INSTRUMENTAL.FOCUS.OFFSET=%f" value] == 1} {
      set pendingz [format "%.3f" $value]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE POSITION.INSTRUMENTAL.FOCUS.TARGETDISTANCE=%f" value] == 1} {
      set pendingzerror [format "%+.3f" $value]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE POSITION.INSTRUMENTAL.FOCUS.MOTION_STATE=%d" value] == 1} {
      if {$value & (1 << 0)} {
        set moving true
      } else {
        set moving false
      }
      log::debug "moving is $moving."
    }
    if {[scan $controllerresponse "%*d DATA INLINE POSITION.INSTRUMENTAL.FOCUS.LIMIT_STATE=%d" value] == 1} {
      if {$value & (1 << 0 | 1 << 8)} {
        set pendingzlowerlimit true
      } else {
        set pendingzlowerlimit false
      }
      if {$value & (1 << 1 | 1 << 9)} {
        set pendingzupperlimit true
      } else {
        set pendingzupperlimit false
      }
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
    
    set mode        $pendingmode
    set z           $pendingz
    set zerror      $pendingzerror
    set zlowerlimit $pendingzlowerlimit
    set zupperlimit $pendingzupperlimit

    set timestamp   [utcclock::combinedformat "now"]

    server::setdata "timestamp"   $timestamp
    server::setdata "mode"        $mode
    server::setdata "z"           $z
    server::setdata "zerror"      $zerror
    server::setdata "zlowerlimit" $zlowerlimit
    server::setdata "zupperlimit" $zupperlimit

    server::setstatus "ok"

    return true
  }

  proc setmoving {} {
    variable moving
    set moving true
  }

  proc waituntilnotmoving {} {
    variable moving
    log::info "waiting until not moving."
    while {$moving} {
      log::info "moving was $moving"
      coroutine::after 100
    }
    log::info "finished waiting until not moving."
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

  ######################################################################

  proc starthardware {} {
    controller::flushcommandqueue
#    setmoving
log::info "sending SET POINTING.INSTRUMENTAL.FOCUS.OFFSET=0"
#    controller::sendcommand "SET POINTING.INSTRUMENTAL.FOCUS.OFFSET=0"
log::info "sending SET POINTING.SETUP.FOCUS.SYNCMODE=1"
#    controller::sendcommand "SET POINTING.SETUP.FOCUS.SYNCMODE=1"
log::info "done"
#    waituntilnotmoving
  }

  proc stophardware {} {
    controller::flushcommandqueue
    setmoving
    controller::sendcommand "SET TELESCOPE.STOP=1"
    waituntilnotmoving
  }
  
  proc movehardwaresimple {requestedz} {
    log::info "movehardwaresimple: starting."
#    controller::flushcommandqueue
#    waituntilnotmoving
    variable minz
    variable maxz
    if {$requestedz < $minz} {
      log::warning "moving to minimum position $minz instead of $requestedz."
      set requestedz $minz
    } elseif {$requestedz > $maxz} {
      log::warning "moving to maximum position $maxz instead of $requestedz."
      set requestedz $maxz
    }
    set z [server::getdata "z"]
    if {$z != $requestedz} {
      log::info "movehardwaresimple: sending commands."
      setmoving
      controller::sendcommand "SET POINTING.SETUP.FOCUS.SYNCMODE=1"
      controller::sendcommand "SET POINTING.SETUP.FOCUS.POSITION=$z"
      controller::sendcommand "SET POINTING.TRACK=4"
      coroutine::after 1000
      waituntilnotmoving
    }
    log::info "movehardwaresimple: done."
  }

  proc movehardware {requestedz check} {
    set z [server::getdata "z"]
    log::info "moving from raw position $z to $requestedz."
    variable zdeadzonewidth
    if {abs($requestedz - $z) <= $zdeadzonewidth} {
      log::info "ignoring the requested move as the requested position is within the deadzone."
      return
    }
    variable dztweak
    if {
      ($dztweak < 0 && $requestedz < $z) ||
      ($dztweak > 0 && $requestedz > $z)
    } {
      log::info "moving first to raw position [expr {$requestedz + $dztweak}] to mitigate backlash."
      movehardwaresimple [expr {$requestedz + $dztweak}]
    }
    log::info "moving to raw position $requestedz."
    movehardwaresimple $requestedz
    if {$check} {
      checkzerror "after moving"
    }
  }
  
  ######################################################################

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    setrequestedz0 ""
    setrequestedz
    starthardware
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]    
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    variable initialz0
    setrequestedz0 $initialz0
    setrequestedz
    log::info "moving to corrected position [server::getdata "requestedz0"]."
    movehardware [server::getdata "requestedz"] true 
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]    
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    set activity [server::getdata "activity"]
    if {
      [string equal $activity "initializing"] ||
      [string equal $activity "moving"]
    } {
      stophardware
    }
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]    
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    stophardware
    set end [utcclock::seconds]
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff $end $start]]    
  }

  proc moveactivitycommand {check} {
    set start [utcclock::seconds]
    log::info "moving."
    log::info "moving to corrected position [server::getdata "requestedz0"]."
    setrequestedz
    movehardware [server::getdata "requestedz"] true 
    set end [utcclock::seconds]
    log::info [format "finished moving after %.1f seconds." [utcclock::diff $end $start]]    
  }

  ######################################################################

  proc start {} {
    server::setstatus "starting"
    controller::startcommandloop "AUTH PLAIN \"admin\" \"admin\"\n"
    controller::startstatusloop
    server::newactivitycommand "starting" "started" secondary::startactivitycommand
  }

  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "secondary.tcl"]
