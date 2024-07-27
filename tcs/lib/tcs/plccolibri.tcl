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

package provide "plccolibri" 0.0

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
  set controller::updatedata                  plc::updatedata
  set controller::statusintervalmilliseconds  1000

  set server::datalifeseconds                 30

  ######################################################################

  server::setdata "lights"            ""
  server::setdata "timestamp"         ""
  server::setdata "stoppedtimestamp"  ""

  variable settledelayseconds 5

  proc isignoredresponseresponse {response} {
    if {
      [regexp {[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]:[0-9][0-9]:[0-9][0-9] - OK} $response] == 1 ||
      [string equal "" $response]
    } {
      return true
    } else {
      return false
    }
  }
  
  variable lights ""
  variable mode ""
  variable keyswitch ""
  variable localconfirmation ""
  variable emergencystopbuttons ""
  variable intrusionsensor ""
  variable louvers ""
  variable weatheralarmdisabled ""
  variable daylightalarmdisabled ""
  variable alarm ""
  variable alarmbits ""
  variable rainalarm ""
  variable windalarm ""
  variable cloudalarm ""
  variable lightlevelalarm ""
  variable humidityalarm ""
  variable tcsalarm ""
  variable upsalarm ""
  variable rioalarm ""
  variable boltwoodalarm ""
  variable vaisalaalarm ""
  variable weatherresponse ""
  variable generalresponse ""
  variable lastweatherresponse ""
  variable lastgeneralresponse ""
  
  variable assertedalarmvalue ""

  proc updatedata {response} {

    variable lights
    variable mode
    variable keyswitch
    variable localconfirmation
    variable emergencystopbuttons
    variable intrusionsensor
    variable louvers
    variable weatheralarmdisabled
    variable daylightalarmdisabled
    variable alarm
    variable alarmbits
    variable rainalarm
    variable windalarm
    variable cloudalarm
    variable lightlevelalarm
    variable humidityalarm
    variable tcsalarm
    variable upsalarm
    variable rioalarm
    variable boltwoodalarm
    variable vaisalaalarm
    variable weatherresponse
    variable generalresponse
    variable lastweatherresponse
    variable lastgeneralresponse

    set timestamp [utcclock::combinedformat now]

    set response [string trim $response]
    if {[isignoredresponseresponse $response]} {
      return false
    }

    log::info "response is \"$response\"."
    log::info "length is [string length $response]."
    if {[string length $response] == 94} {
      log::info "got general response."
      set generalresponse $response
      return false
    } elseif {[string length $response] > 0} {
      log::info "got weather response."
      set weatherresponse $response
    } else {
      log::warning "unexpected response \"$response\"."
      return false
    }

    log::info "processing responses."

    set weatherfield [string map {" " ""} $weatherresponse]
    set weatherfield [split $weatherfield ";"]
    set weatherfield [lrange $weatherfield 1 end]
    log::debug "weatherfield = $weatherfield"

    set lastlights $lights
    if {[string index $generalresponse 74] == "0"} {
      set lights "off"
    } else {
      set lights "on"
    }
    if {[string equal $lastlights ""]} {
      log::info "the lights are $lights."
    } elseif {![string equal $lights $lastlights]} {
      log::info "the lights have changed from $lastlights to $lights."
    }
    
    set lastkeyswitch $keyswitch
    switch -- "[string index $generalresponse 21][string index $generalresponse 20]" {
      "00" { set keyswitch "off"    }
      "01" { set keyswitch "local"  }
      "10" { set keyswitch "remote" }
      "11" { set keyswitch "error"  }
    }
    if {[string equal $lastkeyswitch ""]} {
      log::info "the key switch is \"$keyswitch\"."
    } elseif {![string equal $keyswitch $lastkeyswitch]} {
      log::summary "the key switch has changed from \"$lastkeyswitch\" to \"$keyswitch\"."
    }
    
    set lastlocalconfirmation $localconfirmation
    switch -- "[string index $generalresponse 37]" {
      "0" { set localconfirmation "pending"   }
      "1" { set localconfirmation "confirmed" }
    }
    if {[string equal $lastlocalconfirmation ""]} {
      log::info "the local confirmation is \"$localconfirmation\"."
    } elseif {![string equal $localconfirmation $lastlocalconfirmation]} {
      log::warning "the local confirmation has changed from \"$lastlocalconfirmation\" to \"$localconfirmation\"."
    }
    
    set lastemergencystopbuttons $emergencystopbuttons
    set emergencystopbuttons [boolean [expr {![string index $generalresponse 39]}]]
    if {[string equal $lastemergencystopbuttons ""]} {
      if {$emergencystopbuttons} {
        log::error "the emergency stop buttons are activated."
      } else {
        log::info "the emergency stop buttons are deactivated."
      }
    } elseif {![string equal $lastemergencystopbuttons $emergencystopbuttons]} {
      if {$emergencystopbuttons} {
        log::error "the emergency stop buttons have been activated."
        log::error "deactivate the buttons and clear the error on the telescope cabinet."
      } else {
        log::warning "the emergency stop buttons have been deactivated."
        log::warning "clear the error on the telescope cabinet."
      }
    }

    set lastintrusionsensor $intrusionsensor
    set intrusionsensor [boolean [expr {[string index $generalresponse 41]}]]
    if {[string equal $lastintrusionsensor ""]} {
      if {$intrusionsensor} {
        log::error "the intrusion sensor is activated."
      } else {
        log::info "the intrusion sensor is not activated."
      }
    } elseif {![string equal $lastintrusionsensor $intrusionsensor]} {
      if {$intrusionsensor} {
        log::error "the intrusion sensor has been activated."
      } else {
        log::warning "the intrusion sensor has been deactivated."
      }
    }
    
    set lastlouvers    $louvers
    set louversopen    true
    set louversclosed  true
    set louverserror   false 
    foreach i { 58 59 60 61 62 63 64 65 66 67 68 69 } {
      switch [string index $generalresponse $i] {
        0 { set louversopen     false }
        1 { set louversclosed   false }
        2 { set louversanyerror true  }
      }
    }
    if {$louverserror} {
      set louvers "error"
    } elseif {$louversclosed} {
      set louvers "closed"
    } elseif {$louversopen} {
      set louvers "open"
    } else {
      set louvers "intermediate"
    }
    log::info "louvers are \"$louvers\"."
    if {[string equal $lastlouvers ""]} {
      log::info "the louvers are $louvers."
    } elseif {![string equal $louvers $lastlouvers]} {
      log::info "the louvers have changed from $lastlouvers to $louvers."
    }
 
    set lastmode $mode
    set rawmode [lindex $weatherfield 50]
    switch $rawmode {
      "MANU"           { set mode "local" }
      "OFF"            { set mode "off"   }
      "WAIT_ACK"       { set mode "remote but waiting for local confirmation"}
      "AUTO"           { set mode "remote and may be open" }
      "AUTO_PARK"      { set mode "remote but must be closed" }
      "AUTO_INTRUSION" { set mode "remote but intrusion detected"}
      "ESTOP"          { set mode "emergency stop activated"}
      "WAIT_MANU"      { set mode "local but waiting for telescope to be switched" }
      "WAIT_OFF"       { set mode "off but waiting for telescope to be switched"}
      "WAIT_AUTO"      { set mode "remote but waiting for telescope to be switched" }
      default          { set mode "error: $rawmode"}
    }
    if {[string equal $lastmode ""]} {
      log::info "the mode is \"$mode\" ($rawmode)."
    } elseif {![string equal $mode $lastmode]} {
      log::warning "the mode has changed from \"$lastmode\" to \"$mode\" ($rawmode)."
    }

    set lastweatheralarmdisabled $weatheralarmdisabled
    set weatheralarmdisabled [boolean [string index $generalresponse 45]]
    logalarm $weatheralarmdisabled $lastweatheralarmdisabled "weather alarm disabled"    

    set lastdaylightalarmdisabled $daylightalarmdisabled
    set daylightalarmdisabled [boolean [string index $generalresponse 85]]
    logalarm $daylightalarmdisabled $lastdaylightalarmdisabled "daylight alarm disabled"    

    set alarmtimer [lindex $weatherfield 51]

    set lastalarmbits $alarmbits
    set alarmbits "[string index $generalresponse 50][string index $generalresponse 49][string index $generalresponse 46][string reverse [string range $generalresponse 30 36]]"
    if {[string equal $lastalarmbits ""]} {
      log::info "the alarm bits are $alarmbits."
    } elseif {![string equal $alarmbits $lastalarmbits]} {
      log::info "the alarm bits have changed from $lastalarmbits to $alarmbits."
    }
    
    set lastrainalarm $rainalarm
    set rainalarm [boolean [string index $generalresponse 30]]
    logalarm $rainalarm $lastrainalarm "rain alarm"    
    
    set lastwindalarm $windalarm
    set windalarm [boolean [string index $generalresponse 31]]
    logalarm $windalarm $lastwindalarm "wind alarm"    
    
    set lastcloudalarm $cloudalarm
    set cloudalarm [boolean [string index $generalresponse 32]]
    logalarm $cloudalarm $lastcloudalarm "cloud alarm"    
    
    set lastlightlevelalarm $lightlevelalarm
    set lightlevelalarm [boolean [string index $generalresponse 33]]
    logalarm $lightlevelalarm $lastlightlevelalarm "light-level alarm"    
    
    set lasthumidityalarm $humidityalarm
    set humidityalarm [boolean [string index $generalresponse 34]]
    logalarm $humidityalarm $lasthumidityalarm "humidity alarm"    
    
    set lasttcsalarm $tcsalarm
    set tcsalarm [boolean [string index $generalresponse 35]]
    logalarm $tcsalarm $lasttcsalarm "tcs alarm"    
    
    set lastupsalarm $upsalarm
    set upsalarm [boolean [string index $generalresponse 36]]
    logalarm $upsalarm $lastupsalarm "ups alarm"    
    
    set lastrioalarm $rioalarm
    set rioalarm [boolean [string index $generalresponse 46]]
    logalarm $rioalarm $lastrioalarm "rio alarm"    
    
    set lastboltwoodalarm $boltwoodalarm
    set boltwoodalarm [boolean [string index $generalresponse 49]]
    logalarm $boltwoodalarm $lastboltwoodalarm "boltwood alarm"    
    
    set lastvaisalaalarm $vaisalaalarm
    set vaisalaalarm [boolean [string index $generalresponse 50]]
    logalarm $vaisalaalarm $lastvaisalaalarm "vaisala alarm"    
    
    set lastalarm $alarm
    set alarm [boolean [string index $generalresponse 29]]
    logalarm $alarm $lastalarm "alarm"    
    
    server::setdata "plccabinettemperature" [lindex $weatherfield 30]
    server::setdata "riocabinettemperature" [lindex $weatherfield 31]
    server::setdata "comet1temperature"     [lindex $weatherfield 32]
    server::setdata "comet2temperature"     [lindex $weatherfield 34]
    server::setdata "comet1humidity"        [expr {[lindex $weatherfield 33] * 0.01}]
    server::setdata "comet2humidity"        [expr {[lindex $weatherfield 35] * 0.01}]
    
    server::setdata "lights"               $lights
    server::setdata "mode"                 $mode
    server::setdata "keyswitch"            $keyswitch
    server::setdata "localconfirmation"    $localconfirmation
    server::setdata "emergencystopbuttons" $emergencystopbuttons
    server::setdata "intrusionsensor"      $intrusionsensor
    server::setdata "louvers"              $louvers
    
    server::setdata "weatheralarmdisabled"  $weatheralarmdisabled
    server::setdata "daylightalarmdisabled" $daylightalarmdisabled

    server::setdata "alarm"               $alarm
    server::setdata "alarmtimer"          $alarmtimer
    server::setdata "alarmbits"           $alarmbits    
    server::setdata "rainalarm"           $rainalarm
    server::setdata "windalarm"           $windalarm
    server::setdata "cloudalarm"          $cloudalarm
    server::setdata "lightlevelalarm"     $lightlevelalarm
    server::setdata "humidityalarm"       $humidityalarm
    server::setdata "tcsalarm"            $tcsalarm
    server::setdata "upsalarm"            $upsalarm
    server::setdata "rioalarm"            $rioalarm
    server::setdata "boltwoodalarm"       $boltwoodalarm
    server::setdata "vaisalaalarm"        $vaisalaalarm

    server::setdata "timestamp"           $timestamp

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

    set lastweatherresponse $weatherresponse
    set lastgeneralresponse $generalresponse
    set weatherresponse ""
    set generalresponse ""
    
    log::info "finished processing responses."
    
    return true
  }

  proc logalarm {value lastvalue name} {
    if {[string equal $lastvalue ""]} {
      if {$value} {
        log::info "the $name is on."
      } else {
        log::info "the $name is off."
      }
    } elseif {![string equal $lastvalue $value]} {
      if {$value} {
        log::warning "the $name has changed from off to on."
      } else {
        log::summary "the $name has changed from on to off."
      }
    }
  }

  proc boolean {x} {
    if {$x} {
      return "true"
    } else {
      return "false"
    }
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
    if {![string equal [server::getdata "keyswitch"] "remote"]} {
      error "the PLC is not in remote keyswitch."
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
  
  proc updateweather {} {
    server::checkstatus
    variable lastweatherresponse
    variable lastgeneralresponse
    if {
      [string equal "" $lastweatherresponse] ||
      [string equal "" $lastgeneralresponse]
    } {
      log::warning "unable to update weather: no data."
      return
    }
    set timestamp  [server::getdata "timestamp"]
    set date        [utcclock::formatdate $timestamp]
    set time        [utcclock::formattime $timestamp]
    set compactdate [utcclock::formatdate $timestamp false]
    set weather [join [split $lastweatherresponse ";"] " "]
    set generaldate [lindex [split $lastgeneralresponse ";"] 0]
    set generaldata [join [split [lindex [split $lastgeneralresponse ";"] 1] ""] " "]
    set line "b.0 $date $time $weather $generaldate $generaldata"
    set line [string map {";" " "} $line]
    set directorypath [file join [directories::var] "weather"]
    if {[catch {
      file mkdir $directorypath
      set filepath [file join $directorypath "$date.txt"]
      set channel [::open $filepath "a"]
      puts $channel $line
      ::close $channel      
    }]} {
      log::warning "unable to update weather: cannot write to file."
    }
    return
  }
  
  ######################################################################

  proc enableweatheralarmactivitycommand {} {
    set start [utcclock::seconds]
    log::info "enabling the weather alarm."
    controller::sendcommand "ByPassWeather\{OFF\}\n"
    log::info [format "finished enabling the weather alarm after %.1f seconds." [utcclock::diff now $start]]
  }

  proc disableweatheralarmactivitycommand {} {
    set start [utcclock::seconds]
    log::info "disabling the weather alarm."
    controller::sendcommand "ByPassWeather\{ON\}\n"
    log::info [format "finished disabling the weather alarm after %.1f seconds." [utcclock::diff now $start]]
  }

  proc enabledaylightalarmactivitycommand {} {
    set start [utcclock::seconds]
    log::info "enabling the daylight alarm."
    controller::sendcommand "DayLightThreshold\{ON\}\n"
    log::info [format "finished enabling the daylight alarm after %.1f seconds." [utcclock::diff now $start]]
  }

  proc disabledaylightalarmactivitycommand {} {
    set start [utcclock::seconds]
    log::info "disabling the daylight alarm."
    controller::sendcommand "DayLightThreshold\{OFF\}\n"
    log::info [format "finished disabling the daylight alarm after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################
  
  proc enableweatheralarm {} {
    server::newactivitycommand "enablingalarm" "idle" plc::enableweatheralarmactivitycommand
  }

  proc disableweatheralarm {} {
    server::newactivitycommand "disablingalarm" "idle" plc::disableweatheralarmactivitycommand
  }

  proc enabledaylightalarm {} {
    server::newactivitycommand "enablingalarm" "idle" plc::enabledaylightalarmactivitycommand
  }

  proc disabledaylightalarm {} {
    server::newactivitycommand "disablingalarm" "idle" plc::disabledaylightalarmactivitycommand
  }

  ######################################################################

  proc switchlightson {} {
    server::checkstatus
    log::info "switching lights on."
    controller::pushcommand "ObsRoomLight{ON}\n"
    return
  }

  proc switchlightsoff {} {
    server::checkstatus
    log::info "switching lights off."
    controller::pushcommand "ObsRoomLight{OFF}\n"
    return
  }

  ######################################################################

  proc start {} {
    set controller::connectiontype "persistent"
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "idle" plc::startactivitycommand
  }

}
