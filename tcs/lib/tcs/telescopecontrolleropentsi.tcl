########################################################################

# This file is part of the UNAM telescope control system.

# $Id: telescopecontrollercoatlioan.tcl 3601 2020-06-11 03:20:53Z Alan $

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
package require "opentsi"
package require "log"
package require "server"

package provide "telescopecontrolleropentsi" 0.0

namespace eval "telescopecontroller" {

  ######################################################################

  server::setdata "timestamp"          [utcclock::combinedformat now]
  server::setdata "ambienttemperature" ""
  server::setdata "ambientpressure"    ""

  set server::datalifeseconds          30

  ######################################################################

  set statuscommand "GET [join {
    TELESCOPE.ENVIRONMENT.TEMPERATURE
    TELESCOPE.ENVIRONMENT.PRESSURE
    AUXILIARY.SENSOR[0].VALUE
    AUXILIARY.SENSOR[1].VALUE
    AUXILIARY.SENSOR[2].VALUE
    AUXILIARY.SENSOR[3].VALUE
    AUXILIARY.SENSOR[4].VALUE
    AUXILIARY.SENSOR[5].VALUE
    AUXILIARY.SENSOR[6].VALUE
    AUXILIARY.SENSOR[7].VALUE
    AUXILIARY.SENSOR[8].VALUE
    AUXILIARY.SENSOR[9].VALUE
    AUXILIARY.SENSOR[10].VALUE
    AUXILIARY.SENSOR[11].VALUE
    AUXILIARY.SENSOR[12].VALUE
    AUXILIARY.SENSOR[13].VALUE
    AUXILIARY.SENSOR[14].VALUE
  } ";"]"

  ######################################################################

  variable ambienttemperature ""
  variable ambientpressure    ""
  variable sensor0            ""
  variable sensor1            ""
  variable sensor2            ""
  variable sensor3            ""
  variable sensor4            ""
  variable sensor5            ""
  variable sensor6            ""
  variable sensor7            ""
  variable sensor8            ""
  variable sensor9            ""
  variable sensor10           ""
  variable sensor11           ""
  variable sensor12           ""
  variable sensor13           ""
  variable sensor14           ""
  
  variable laststate          ""

  proc updatedata {response} {

    variable ambienttemperature
    variable ambientpressure
    variable sensor0
    variable sensor1
    variable sensor2
    variable sensor3
    variable sensor4
    variable sensor5
    variable sensor6
    variable sensor7
    variable sensor8
    variable sensor9
    variable sensor10
    variable sensor11
    variable sensor12
    variable sensor13
    variable sensor14
    
    variable laststate

    if {[scan $response "%*d DATA INLINE TELESCOPE.ENVIRONMENT.TEMPERATURE=%f" value] == 1} {
      set ambienttemperature $value
      return false
    }

    if {[scan $response "%*d DATA INLINE TELESCOPE.ENVIRONMENT.PRESSURE=%f" value] == 1} {
      set ambientpressure $value
      return false
    }

    if {[scan $response "%*d DATA INLINE AUXILIARY.SENSOR\[%d\].VALUE=%s" i value] == 2} {
      if {[string equal $value "FAILED"]} {
        set value ""
      }
      set sensor$i $value
      return false
    }

    if {[regexp {[0-9]+ DATA INLINE } $response] == 1} {
      log::debug "status: ignoring DATA INLINE response."
      return false
    }
    if {[regexp {[0-9]+ COMMAND COMPLETE} $response] != 1} {
      log::warning "unexpected controller response \"$response\"."
      return true
    }

    set timestamp [utcclock::combinedformat "now"]

    set state $opentsi::readystatetext
    if {![string equal $laststate ""] && ![string equal $laststate $state]} {
      log::info "state changed from $laststate to $state."
    }
    set laststate $state

    server::setdata "timestamp"          $timestamp
    server::setdata "state"              $state
    server::setdata "ambienttemperature" $ambienttemperature
    server::setdata "ambientpressure"    $ambientpressure
    server::setdata "sensor0"            $sensor0
    server::setdata "sensor1"            $sensor1
    server::setdata "sensor2"            $sensor2
    server::setdata "sensor3"            $sensor3
    server::setdata "sensor4"            $sensor4
    server::setdata "sensor5"            $sensor5
    server::setdata "sensor6"            $sensor6
    server::setdata "sensor7"            $sensor7
    server::setdata "sensor8"            $sensor8
    server::setdata "sensor9"            $sensor9
    server::setdata "sensor10"           $sensor10
    server::setdata "sensor10"           $sensor11
    server::setdata "sensor12"           $sensor12
    server::setdata "sensor13"           $sensor13
    server::setdata "sensor14"           $sensor14

    foreach i {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14} {
      log::writesensorsfile "opentsi-$i" [set sensor$i] $timestamp
    }

    server::setstatus "ok"

    return true
  }

  ######################################################################
  
  proc switchonhardware {} {
    opentsi::sendcommand "SET TELESCOPE.POWER=1"
    while {$opentsi::readystate != 1.0} {
      coroutine::yield
    }
    set settlingdelay 5
    set settle [utcclock::seconds]
    while {[utcclock::diff now $settle] < $settlingdelay} {
      coroutine::yield
    }
  }
  
  proc switchoffhardware {} {
    opentsi::sendcommand "SET TELESCOPE.POWER=0"
    while {$opentsi::readystate != 0.0} {
      coroutine::yield
    }
  }
  
  proc stophardware {} {
    opentsi::sendcommand "SET TELESCOPE.STOP=1"
  }
  
  proc checkhardware {} {
    if {$opentsi::readystate < 0.0} {
      error "state is \"$opentsi::readystatetext\"."
    }
  }
  
  ######################################################################
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    stophardware
    while {[string equal [server::getstatus] "starting"]} {
      coroutine::yield
    }
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    switchonhardware
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc switchonactivitycommand {} {
    set start [utcclock::seconds]
    log::info "switching on."
    switchonhardware
    set end [utcclock::seconds]
    log::info [format "finished switching on after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc switchoffactivitycommand {} {
    set start [utcclock::seconds]
    log::info "switching off."
    switchoffhardware
    set end [utcclock::seconds]
    log::info [format "finished switching off after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc stopactivitycommand {previousactivity} {
    set start [utcclock::seconds]
    log::info "stopping."
    stophardware
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    checkhardware
    server::newactivitycommand "initializing" "idle" telescopecontroller::initializeactivitycommand
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    checkhardware
    server::newactivitycommand "stopping" [server::getstoppedactivity] "telescopecontroller::stopactivitycommand [server::getactivity]"
  }
  
  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] server::resetactivitycommand
  }

  proc switchon {} {
    server::checkstatus
    server::checkactivityformove
    checkhardware
    server::newactivitycommand "switchingon" "idle" telescopecontroller::switchonactivitycommand
  }

  proc switchoff {} {
    server::checkstatus
    server::checkactivityformove
    checkhardware
    server::newactivitycommand "switchingoff" "idle" telescopecontroller::switchoffactivitycommand
  }

  ######################################################################

  proc start {} {
    server::setstatus "ok"
    opentsi::start $telescopecontroller::statuscommand telescopecontroller::updatedata
    server::newactivitycommand "starting" "started" telescopecontroller::startactivitycommand
  }

  ######################################################################

}
