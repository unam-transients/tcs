########################################################################

# This file is part of the UNAM telescope control system.

# $Id: plc.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "plccolibri" 0.0

namespace eval "plc" {

  variable svnid {$Id}

  ######################################################################

  variable controllerhost [config::getvalue "plc" "controllerhost"]
  variable controllerport [config::getvalue "plc" "controllerport"]  
  
  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::statuscommand               "GeneralStatus\nWeatherStatus\n"
  set controller::timeoutmilliseconds         5000
  set controller::intervalmilliseconds        500
  set controller::updatedata                  plc::updatedata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 30

  ######################################################################

  server::setdata "lights"            ""
  server::setdata "lastlights"        ""
  server::setdata "timestamp"         ""
  server::setdata "stoppedtimestamp"  ""

  variable settledelayseconds 5

  proc isignoredresponseresponse {response} {
    switch -- $response {
      "" {
        return true
      }
      default {
        return false
      }
    }
  }
  
  variable weatherresponse ""
  variable generalresponse ""
  
  proc updatedata {response} {

    variable weatherresponse
    variable generalresponce

    set timestamp [utcclock::combinedformat now]

    set response [string trim $response]
    if {[isignoredresponseresponse $response]} {
      return false
    }

    if {[string length $response] != 76} {
      set weatherresponse $response
      return false
    }

    if {[string equal $weatherresponse ""]} {
      return false
    }

    set generalresponse $response

    switch -- [string index $generalresponse 21] {
      0 { set mode "local" }
      1 { set mode "remote"  }
    }
    
    set weatherfield [string map {" " ""} $weatherresponse]
    set weatherfield [split $weatherfield ";"]
    set weatherfield [lrange $weatherfield 1 end]
    log::debug "weatherfield = $weatherfield"
    
    server::setdata "plccabinettemperature" [lindex $weatherfield 30]
    server::setdata "riocabinettemperature" [lindex $weatherfield 31]
    server::setdata "comet1temperature"     [lindex $weatherfield 32]
    server::setdata "comet2temperature"     [lindex $weatherfield 34]
    server::setdata "comet1humidity"        [expr {[lindex $weatherfield 33] * 0.01}]
    server::setdata "comet2humidity"        [expr {[lindex $weatherfield 35] * 0.01}]
    
    server::setdata "timestamp"         $timestamp
    server::setdata "mode"              $mode

    server::setstatus "ok"

    log::writedatalog "plc" {
      timestamp
      plccabinettemperature
      riocabinettemperature
      comet1temperature
      comet2temperature
      comet1humidity
      comet2humidity
    }

    foreach {sensorname dataname} {
      plc-cabinet-temperature       plccabinettemperature 
      rio-cabinet-temperature       riocabinettemperature 
      comet1-temperature            comet1temperature
      comet2-temperature            comet2temperature
      comet1-humidity               comet1humidity
      comet2-humidity               comet2humidity
    } {
      log::writesensorsfile "plc-$sensorname" [server::getdata $dataname] [server::getdata "timestamp"]
    }

    set weatherresponse ""
    set generalresponse ""
    
    return true
  }
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    log::info [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    log::info [format "finished closing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    controller::flushcommandqueue
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff now $start]]
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    set activity [server::getactivity]
    if {
      [string equal $activity "initializing"] || 
      [string equal $activity "opening"] || 
      [string equal $activity "closing"]
    } {
      controller::flushcommandqueue
    }
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################
  
  proc checkremote {} {
    if {![string equal [server::getdata "mode"] "remote"]} {
      error "the PLC is not in remote mode."
    }
  }

  proc checkrainsensor {} {
  }
  
  proc checkformove {} {
  }

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    checkremote
    server::newactivitycommand "initializing" "idle" plc::initializeactivitycommand
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    checkremote
    server::newactivitycommand "stopping" [server::getstoppedactivity] plc::stopactivitycommand
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    checkremote
    server::newactivitycommand "resetting" [server::getstoppedactivity] plc::resetactivitycommand
  }

  proc open {} {
    server::checkstatus
    server::checkactivityformove
    checkremote
    checkrainsensor
    checkformove
    server::newactivitycommand "opening" "idle" "plc::openactivitycommand"
  }

  proc close {} {
    server::checkstatus
    server::checkactivityformove
    checkremote
    checkformove
    server::newactivitycommand "closing" "idle" plc::closeactivitycommand
  }
  
  ######################################################################

  proc start {} {
    set controller::connectiontype "persistent"
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "idle" plc::startactivitycommand
  }

}