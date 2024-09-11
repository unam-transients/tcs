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

# This package implements the low-level communication with an Optec
# TCF-S focuser. This type of focuser is used to focus the secondary of
# the COATLI 50-cm telescope.

package require "config"
package require "controller"
package require "client"
package require "log"
package require "coroutine"
package require "server"

package provide "secondaryoptec" 0.0

namespace eval "secondary" {

  ######################################################################

  variable controllerhost    [config::getvalue "secondary" "controllerhost"   ]
  variable controllerport    [config::getvalue "secondary" "controllerport"   ]
  
  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::connectiontype              "persistent"
  set controller::statuscommand               "FPOSRO"
  set controller::timeoutmilliseconds         5000
  set controller::intervalmilliseconds        500
  set controller::updatedata                  secondary::updatecontrollerdata
  set controller::statusintervalmilliseconds  500
  
  set server::datalifeseconds                 30

  # The focuser does not respond while it is moving. To avoid time outs,
  # we move in steps of at most dzsetp. The speed is about 100 steps per
  # second.

  variable dzstep [expr {int($controller::intervalmilliseconds * 0.1)}]

  ######################################################################

  variable moving true
  
  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    if {
      [string equal $controllerresponse "!"] ||
      [string equal $controllerresponse "*"] ||
      [string equal $controllerresponse ""] ||
      [string match "=*" $controllerresponse]
    } {
      return false
    }

    if {[scan $controllerresponse "P=%d" z] != 1} {
      error "invalid controller response \"$controllerresponse\"."
    }

    # We don't have limit switches.
    set zlowerlimit false
    set zupperlimit false

    if {[catch {
      expr {$z - [server::getdata "requestedz"]}
    } zerror]} {
      set zerror ""
    }

    # The focuser only returns a position when it has stopped moving.
    variable moving
    set moving false
    
    server::setstatus "ok"
    server::setdata "timestamp"        $timestamp
    server::setdata "z"                $z
    server::setdata "zlowerlimit"      $zlowerlimit
    server::setdata "zupperlimit"      $zupperlimit
    server::setdata "zerror"           $zerror

    return true
  }
  
  proc setmoving {} {
    variable moving
    set moving true
  }

  proc waituntilnotmoving {} {
    variable moving
    while {$moving} {
      coroutine::yield
    }
  }
  
  ######################################################################
    
  proc starthardware {} {
    controller::flushcommandqueue
    controller::sendcommand "FMMODE"
    waituntilnotmoving
    setmoving
    controller::sendcommand "FI0000"
    waituntilnotmoving
    setmoving
    controller::sendcommand "FI0000"
    waituntilnotmoving
  }

  proc stophardware {} {
    controller::flushcommandqueue
    setmoving
    controller::sendcommand "FI0000"
    waituntilnotmoving
  }
  
  proc movehardwaresimple {requestedz} {
    controller::flushcommandqueue
    waituntilnotmoving
    variable minz
    variable maxz
    if {$requestedz < $minz} {
      log::warning "moving to minimum position $minz instead of $requestedz."
      set requestedz $minz
    } elseif {$requestedz > $maxz} {
      log::warning "moving to maximum position $maxz instead of $requestedz."
      set requestedz $maxz
    }
    variable dzstep
    set z [server::getdata "z"]
    while {$z != $requestedz} {
      setmoving
      set dz [expr {$requestedz - $z}]
      if {$dz < -$dzstep} {
        controller::sendcommand [format "FI%04d" $dzstep]
      } elseif {$dz < 0} {
        controller::sendcommand [format "FI%04d" [expr {-$dz}]]
      } elseif {$dz < $dzstep} {
        controller::sendcommand [format "FO%04d" $dz]
      } else {
        controller::sendcommand [format "FO%04d" $dzstep]
      }
      coroutine::after 1000
      waituntilnotmoving
      set z [server::getdata "z"]
    }
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
  
  proc checkhardwarefor {action} {
    # Always available.
    return
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

  proc stopactivitycommand {previousactivity} {
    set start [utcclock::seconds]
    log::info "stopping."
    if {
      [string equal $previousactivity "initializing"] ||
      [string equal $previousactivity "moving"]
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
    server::setactivity "starting"
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "started" secondary::startactivitycommand
  }

}

source [file join [directories::prefix] "lib" "tcs" "secondary.tcl"]
