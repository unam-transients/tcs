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
  
  variable mode ""
  variable unsafe ""
  variable alertbits ""
  variable weatherresponse ""
  variable generalresponse ""
  variable lastweatherresponse ""
  variable lastgeneralresponse ""
  
  proc updatedata {response} {

    variable mode
    variable unsafe
    variable alertbits
    variable weatherresponse
    variable generalresponce
    variable lastweatherresponse
    variable lastgeneralresponse

    set timestamp [utcclock::combinedformat now]

    set response [string trim $response]
    if {[isignoredresponseresponse $response]} {
      return false
    }

    log::debug "length is [string length $response]."
    if {[string length $response] != 85} {
      set weatherresponse $response
      return false
    }

    if {[string equal $weatherresponse ""]} {
      return false
    }

    set generalresponse $response

    set lastmode $mode
    switch -- "[string index $generalresponse 21][string index $generalresponse 20]" {
      "00" { set mode "off"    }
      "01" { set mode "local"  }
      "10" { set mode "remote" }
      "11" { set mode "error"  }
    }
    if {[string equal $lastmode ""]} {
      log::info "the mode is \"$mode\"."
    } elseif {![string equal $mode $lastmode]} {
      log::warning "the mode has changed from \"$lastmode\" to \"$mode\"."
    }
    
    set lastalertbits $alertbits
    set alertbits "[string index $generalresponse 50][string index $generalresponse 49][string index $generalresponse 46][string reverse [string range $generalresponse 30 37]]"
    if {[string equal $lastalertbits ""]} {
      log::info "the alert bits are \"$alertbits\"."
    } elseif {![string equal $alertbits $lastalertbits]} {
      log::warning "the alert bits have changed from \"$lastalertbits\" to \"$alertbits\"."
    }

    set lastunsafe $unsafe
    switch -- "[string index $generalresponse 29]" {
      "0" { set unsafe false }
      "1" { set unsafe true  }
    }
    if {[string equal $lastunsafe ""]} {
      log::info "the unsafe flag is \"$unsafe\"."
    } elseif {![string equal $unsafe $lastunsafe]} {
      log::warning "the unsafe flag has changed from \"$lastunsafe\" to \"$unsafe\"."
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
    server::setdata "unsafe"            $unsafe

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

  proc start {} {
    set controller::connectiontype "persistent"
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "idle" plc::startactivitycommand
  }

}
