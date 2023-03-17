########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "astrometry"
package require "config"
package require "client"
package require "log"
package require "coroutine"
package require "server"

config::setdefaultvalue "secondary" "dzdT"              0
config::setdefaultvalue "secondary" "temperaturesensor" ""
config::setdefaultvalue "secondary" "dzfilter"          {}

namespace eval "secondary" {

  ######################################################################

  variable initialz0         [config::getvalue "secondary" "initialz0"        ]
  variable temperaturesensor [config::getvalue "secondary" "temperaturesensor"]
  variable dztweak           [config::getvalue "secondary" "dztweak"          ]
  variable allowedzerror     [config::getvalue "secondary" "allowedzerror"    ]
  variable zdeadzonewidth    [config::getvalue "secondary" "zdeadzonewidth"   ]
  variable minz              [config::getvalue "secondary" "minz"             ]
  variable maxz              [config::getvalue "secondary" "maxz"             ]
  variable dzmodel           [config::getvalue "secondary" "dzmodel"]
  
  ######################################################################

  server::setdata "z"                 ""
  server::setdata "lastz"             ""
  server::setdata "minz"              $minz
  server::setdata "maxz"              $maxz
  server::setdata "requestedz0"       ""
  server::setdata "dzfilter"          0
  server::setdata "dzoffset"          0
  server::setdata "T"                 ""
  server::setdata "timestamp"         ""
  server::setdata "stoppedtimestamp"  ""
  server::setdata "settled"           false
  server::setdata "settledtimestamp"  [utcclock::combinedformat now]

  ######################################################################
  
  variable T 0.0
  
  proc getsensorsdata {} {
    variable T
    variable temperaturesensor
    if {[string equal $temperaturesensor ""]} {
      log::debug "getsensorsdata: no temperature sensor configured."
    } else {
      log::debug "getsensorsdata: determining T from temperature sensor \"$temperaturesensor\"."
      if {
        [catch {client::update "sensors"}] ||
        [catch {set newT [client::getdata "sensors" "$temperaturesensor"]}] || 
        [string equal $newT "unknown"]
      } {
        log::warning "getsensorsdata: unable to determine the sensors data."
      } else {
        set T $newT
        server::setdata "T" $newT
      }
      log::debug "getsensorsdata: T is \"$T\"."
    }
  }
  
  proc dztemperature {} {
    variable dzmodel
    variable T
    getsensorsdata
    log::debug "dztemperature: dzmodel is $dzmodel."
    if {[string is double -strict "$T"] && [dict exists $dzmodel "temperature" "dzdT"]} {
      log::debug "dztemperature: dzdT is [dict get $dzmodel "temperature" "dzdT"]."
      set dztemperature [expr {$T * [dict get $dzmodel "temperature" "dzdT"]}]
      set dztemperature [expr {int(round($dztemperature))}]
    } else {
      set dztemperature 0
    }
    log::debug "dztemperature: dztemperature is $dztemperature."
    return $dztemperature
  }
  
  proc dzposition {} {
    variable dzmodel
    while {[catch {client::update "target"} message]} {
      log::warning "unable to determine the target data: $message"
    }
    set zenithdistance [client::getdata "target" "observedzenithdistance"]
    set ha             [client::getdata "target" "observedha"]
    set delta          [client::getdata "target" "observeddelta"]
    set dzposition 0
    if {[dict exists $dzmodel "position" "dzdcoszenithdistance"]} {
      set dzposition [expr {$dzposition + (cos($zenithdistance) - 1) * [dict get "position" "dzdcoszenithdistance"]}]
    }
    if {[dict exists $dzmodel "position" "dzdha"]} {
      set dzposition [expr {$dzposition + $ha * [dict get "position" "dzdha"]}]
    }
    if {[dict exists $dzmodel "position" "dzddelta"]} {
      set dzposition [expr {$dzposition + ($delta - [astrometry::latitude]) * [dict get "position" "dzddelta"]}]
    }
    set dzposition [expr {int(round($dzposition))}]
    log::debug [format "dzposition: zenithdistance = %.1fd; ha = %+.1fd; delta = %.1fd; dzposition = %+d." \
      [astrometry::radtodeg $zenithdistance] \
      [astrometry::radtodeg $ha] \
      [astrometry::radtodeg $delta] \
      $dzposition \
    ]
    return $dzposition
  }

  ######################################################################
  
  proc setrequestedz0 {z0} {
    server::setdata "requestedz0" $z0
  }
 
  proc setrequestedz {} {
    set z0 [server::getdata "requestedz0"]
    set dzfilter [server::getdata "dzfilter"]
    set dzoffset [server::getdata "dzoffset"]
    if {[string equal $z0 ""]} {
      set dztemperature ""
      set dzposition ""
      set z   ""
    } else {
      set dztemperature [dztemperature]
      set dzposition    [dzposition]
      set z [expr {$z0 + $dzfilter + $dztemperature + $dzposition + $dzoffset}]
    }
    server::setdata "dztemperature" $dztemperature
    server::setdata "dzposition"    $dzposition
    server::setdata "requestedz"    $z
  }
  
  proc checkzerror {when} {
    set zerror [server::getdata "zerror"]
    variable allowedzerror
    if {abs($zerror) > $allowedzerror} {
      log::warning [format "z error is %+d $when." $zerror]
    }
  }
  
  proc settle {} {
    log::debug "settling."
    server::setdata "stoppedtimestamp" ""
    server::setdata "lastz"            ""
    server::setdata "settled"          false
    while {![server::getdata "settled"]} {
      coroutine::yield
    }
    log::debug "settled."
  }
  
  ######################################################################

  proc normalizez0 {z0} {
    if {[string is integer -strict $z0]} {
      return $z0
    } elseif {[string equal $z0 "initialz0"]} {
      variable initialz0
      return $initialz0
    } elseif {[string equal $z0 "z0"]} {
      return [server::getdata "requestedz0"]
    } else {
      error "invalid z0 \"$z0\"."   
    }
  }

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    checkhardware "initialize"
    server::newactivitycommand "initializing" "idle" secondary::initializeactivitycommand 600000
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    checkhardware "stop"
    set previousactivity [server::getdata "activity"]
    server::newactivitycommand "stopping" [server::getstoppedactivity] "secondary::stopactivitycommand $previousactivity"
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    checkhardware "reset"
    server::newactivitycommand "resetting" [server::getstoppedactivity] secondary::resetactivitycommand
  }

  proc movewithoutcheck {z0} {
    server::checkstatus
    server::checkactivityformove
    checkhardware "movewithoutcheck"
    set z0 [normalizez0 $z0]
    setrequestedz0 $z0
    server::newactivitycommand "moving" "idle" "secondary::moveactivitycommand false"
  }

  proc move {z0 setasinitial} {
    server::checkstatus
    server::checkactivityformove
    checkhardware "move"
    set z0 [normalizez0 $z0]
    if {$setasinitial} {
      variable initialz0
      set initialz0 $z0    
      config::setvarvalue "secondary" "initialz0" $z0
    }
    setrequestedz0 $z0
    server::newactivitycommand "moving" "idle" "secondary::moveactivitycommand true"
  }
  
  proc moveforfilter {filter} {
    server::checkstatus
    server::checkactivityformove
    checkhardware "moveforfilter"
    variable dzfilter
    variable dzmodel
    if {[dict exists $dzmodel "filter" $filter]} {
      set dzfilter [dict get $dzmodel "filter" $filter]
    } else {
      set dzfilter 0
    }
    set lastdzfilter [server::getdata "dzfilter"]
    server::setdata "dzfilter" $dzfilter
    if {$dzfilter != $lastdzfilter} {
      move z0 false
    }
    return
  }

  proc setoffset {dzoffset} {
    server::checkstatus
    checkhardware "setoffset"
    if {![string is integer -strict $dzoffset]} {
      error "invalid offset \"$dzoffset\"."
    }
    server::setdata "dzoffset" $dzoffset
    return
  }

  ######################################################################

}
