########################################################################

# This file is part of the UNAM telescope control system.

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

package provide "plcsatino" 0.0

namespace eval "plc" {

  ######################################################################

  variable controllerhost [config::getvalue "plc" "controllerhost"]
  variable controllerport [config::getvalue "plc" "controllerport"]  
  
  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::statuscommand               "GeneralStatus\nWeatherStatus\n"
  set controller::timeoutmilliseconds         5000
  set controller::intervalmilliseconds        500
  set controller::updatedata                  plc::updatecontrollerdata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 30

  ######################################################################

  server::setdata "lights"            ""
  server::setdata "lastlights"        ""
  server::setdata "timestamp"         ""
  server::setdata "stoppedtimestamp"  ""

  variable settledelayseconds 5

  proc isignoredcontrollerresponseresponse {response} {
    switch -- $response {
      default {
        return false
      }
    }
  }
  
  variable controllerresponseindex 0
  variable controllerresponseresync false
  variable controllerresponse0
  variable controllerresponse1
  variable controllerresponse2

  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    set controllerresponse [string trim $controllerresponse]
    if {[isignoredcontrollerresponseresponse $controllerresponse]} {
      return false
    }
    
    variable controllerresponseindex
    variable controllerresponseresync
    variable controllerresponse0
    variable controllerresponse1
    variable controllerresponse2
    
    log::debug [format "controller response $controllerresponseindex = %s" $controllerresponse]

    if {$controllerresponseindex == 0} {
      set controllerresponse0 $controllerresponse
      set controllerresponseindex 1
      return false
    } elseif {$controllerresponseindex == 1} {
      set controllerresponse1 $controllerresponse
      set controllerresponseindex 2
      return false
    } else {
      set controllerresponse2 $controllerresponse
      set controllerresponseindex 0
    }
    

if {false} {
    if {$controllerresponseresync} {
      set controllerresponseresync false
      return false
    }
    
    switch -- [expr {($controllerresponse2 >> (32 - 1)) & 1}] {
      0 { set mode "local" }
      1 { set mode "remote"  }
    }
    switch -- [expr {($controllerresponse0 >> (32 - 11)) & 1}] {
      0 { set alarm false }
      1 { set alarm true  }
    }
    switch -- [expr {($controllerresponse0 >> (32 - 20)) & 3}] {
      0 { set roof "intermediate" }
      1 { set roof "closed" }
      2 { set roof "open" }
      3 { set roof "error" }
    }
    switch -- [expr {($controllerresponse0 >> (32 - 18)) & 3}] {
      0 { set door "intermediate" }
      1 { set door "closed" }
      2 { set door "open" }
      3 { set door "error" }
    }
    switch -- [expr {($controllerresponse0 >> (32 - 28)) & 1}] {
      0 { set lights "off" }
      1 { set lights "on"  }
    }
    switch -- [expr {($controllerresponse0 >> (32 - 28)) & 1}] {
      0 { set lights "off" }
      1 { set lights "on"  }
    }

    switch -- [expr {($controllerresponse0 >> (32 - 25)) & 1}] {
      0 { set rainalarm0 false }
      1 { set rainalarm0 true  }
    }
    switch -- [expr {($controllerresponse0 >> (32 - 26)) & 1}] {
      0 { set aagalarm false }
      1 { set aagalarm true  }
    }
    switch -- [expr {($controllerresponse2 >> (32 - 11)) & 1}] {
      0 { set upsalarm false }
      1 { set upsalarm true  }
    }
    switch -- [expr {($controllerresponse2 >> (32 - 12)) & 1}] {
      0 { set rainalarm1 false }
      1 { set rainalarm1 true  }
    }
    switch -- [expr {($controllerresponse2 >> (32 - 13)) & 1}] {
      0 { set windalarm false }
      1 { set windalarm true  }
    }
    switch -- [expr {($controllerresponse2 >> (32 - 14)) & 1}] {
      0 { set humidityalarm false }
      1 { set humidityalarm true  }
    }
    switch -- [expr {($controllerresponse2 >> (32 - 15)) & 1}] {
      0 { set watchdogalarm false }
      1 { set watchdogalarm true  }
    }
    if {$rainalarm0 || $rainalarm1} {
      set rainalarm true
    } else {
      set rainalarm false
    }
    
    set lastmode [server::getdata "mode"]
    if {[string equal $lastmode ""]} {
      log::summary "the mode is $mode."
    } elseif {![string equal $mode $lastmode]} {
      log::summary "the mode changed from $lastmode to $mode."
    }
    
    logalarm $aagalarm      [server::getdata "aagalarm"]      "AAG alarm"
    logalarm $rainalarm     [server::getdata "rainalarm"]     "rain alarm"
    logalarm $windalarm     [server::getdata "windalarm"]     "wind alarm"
    logalarm $humidityalarm [server::getdata "humidityalarm"] "humidity alarm"
    logalarm $watchdogalarm [server::getdata "watchdogalarm"] "watchdog alarm"
    logalarm $upsalarm      [server::getdata "upsalarm"]      "UPS alarm"
    logalarm $alarm         [server::getdata "alarm"]         "alarm"

    set lasttimestamp    [server::getdata "timestamp"]
    set lastroof         [server::getdata "roof"]
    set lastdoor         [server::getdata "door"]
    set stoppedtimestamp [server::getdata "stoppedtimestamp"]
    
    if {![string equal $door $lastdoor]} {
      log::info "the door is $door."
    }
    if {![string equal $roof $lastroof]} {
      log::info "the roof is $roof."
    }

    if {
      ![string equal $roof $lastroof] || 
      [string equal $roof "intermediate"] ||
      ![string equal $door $lastdoor] || 
      [string equal $door "intermediate"]
    } {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $lasttimestamp
    }
    variable settledelayseconds
    if {![string equal $stoppedtimestamp ""] &&
        [utcclock::diff $timestamp $stoppedtimestamp] >= $settledelayseconds} {
      set settled true
    } else {
      set settled false
    }
    
    set lastmustbeclosed [server::getdata "mustbeclosed"]
    set mustbeclosed $alarm
    if {![string equal $mustbeclosed $lastmustbeclosed]} {
      if {$mustbeclosed} {
        log::summary "the enclosure must be closed."
      } else {
        log::summary "the enclosure may be open."
      }
    }
}
    
    server::setstatus "ok"

    server::setdata "timestamp"         $timestamp
if {false} {
    server::setdata "lasttimestamp"     $lasttimestamp
    server::setdata "roof"              $roof
    server::setdata "lastroof"          $lastroof
    server::setdata "door"              $door
    server::setdata "lastdoor"          $lastdoor
    server::setdata "lights"            $lights
    server::setdata "mode"              $mode
    server::setdata "mustbeclosed"      $mustbeclosed
    server::setdata "stoppedtimestamp"  $stoppedtimestamp
    server::setdata "settled"           $settled
    server::setdata "alarm"             $alarm
    server::setdata "rainalarm"         $rainalarm
    server::setdata "aagalarm"          $aagalarm
    server::setdata "windalarm"         $windalarm
    server::setdata "humidityalarm"     $humidityalarm
    server::setdata "upsalarm"          $upsalarm
    server::setdata "watchdogalarm"     $watchdogalarm
}    
    return true
  }
  
  proc logalarm {value lastvalue name} {
    if {[string equal $lastvalue ""]} {
      if {$value} {
        log::summary "the $name is on."
      } else {
        log::summary "the $name is off."
      }
    } elseif {![string equal $lastvalue $value]} {
      if {$value} {
        log::summary "the $name has changed from off to on."
      } else {
        log::summary "the $name has changed from on to off."
      }
    }
  }

  ######################################################################
  
  proc setrequestedroofanddoor {roof} {
    server::setdata "requestedroofanddoor" $roof
  }
  
  proc checkroofanddoor {} {
    if {![string equal [server::getdata "roof"] [server::getdata "requestedroofanddoor"]]} {
      if {[string equal [server::getdata "requestedroofanddoor"] "open"]} {
        error "the roof did not open."
      } else {
        error "the roof did not close."
      }
    }
    if {![string equal [server::getdata "door"] [server::getdata "requestedroofanddoor"]]} {
      if {[string equal [server::getdata "requestedroofanddoor"] "open"]} {
        error "the door did not open."
      } else {
        error "the door did not close."
      }
    }
  }
  
  proc settle {} {
    log::debug "settling."
    server::setdata "stoppedtimestamp" ""
    server::setdata "lastroof"         ""
    server::setdata "lastdoor"         ""
    server::setdata "settled"          false
    while {![server::getdata "settled"]} {
      coroutine::yield
    }
    log::debug "settled."
  }
  
  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
#    controller::sendcommand "CA1@\n"
#    setrequestedroofanddoor ""
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    settle
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    log::info "opening."
    setrequestedroofanddoor "open"
    controller::sendcommand "ROO@\n"
    settle
    checkroofanddoor
    if {[server::getdata "mustbeclosed"]} {
      error "while opening: the enclosure must be closed."
    }
    log::info [format "finished opening after %.1f seconds." [utcclock::diff now $start]]
  }

  proc closeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "closing."
    setrequestedroofanddoor "closed"
    controller::sendcommand "ROC@\n"
    settle
    checkroofanddoor
    log::info [format "finished closing after %.1f seconds." [utcclock::diff now $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    setrequestedroofanddoor ""
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
      setrequestedroofanddoor ""
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
    checkformove
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

  proc switchlightson {} {
    server::checkstatus
    log::info "switching lights on."
    controller::pushcommand "BL1@\r"
    return
  }

  proc switchlightsoff {} {
    server::checkstatus
    log::info "switching lights off."
    controller::pushcommand "BL0@\r"
    return
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
