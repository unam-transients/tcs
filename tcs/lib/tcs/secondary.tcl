########################################################################

# This file is part of the UNAM telescope control system.

# $Id: secondary.tcl 3601 2020-06-11 03:20:53Z Alan $

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

config::setdefaultvalue "secondary" "dzdzenithdistance" 0
config::setdefaultvalue "secondary" "dzdha"             0
config::setdefaultvalue "secondary" "dzddelta"          0
config::setdefaultvalue "secondary" "dzdT"              0
config::setdefaultvalue "secondary" "temperaturesensor" ""
config::setdefaultvalue "secondary" "dzfilter"          {}

namespace eval "secondary" {

  variable svnid {$Id}

  ######################################################################

  variable initialz0         [config::getvalue "secondary" "initialz0"        ]
  variable dzdzenithdistance [config::getvalue "secondary" "dzdzenithdistance"]
  variable dzdha             [config::getvalue "secondary" "dzdha"            ]
  variable dzddelta          [config::getvalue "secondary" "dzddelta"         ]
  variable dzdT              [config::getvalue "secondary" "dzdT"             ]
  variable temperaturesensor [config::getvalue "secondary" "temperaturesensor"]
  variable dztweak           [config::getvalue "secondary" "dztweak"          ]
  variable allowedzerror     [config::getvalue "secondary" "allowedzerror"    ]
  variable zdeadzonewidth    [config::getvalue "secondary" "zdeadzonewidth"   ]
  variable minz              [config::getvalue "secondary" "minz"             ]
  variable maxz              [config::getvalue "secondary" "maxz"             ]
  
  variable dzfilterdict      [config::getvalue "secondary" "dzfilter"]
  
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
  
  proc dzT {} {
    variable dzdT
    variable T
    getsensorsdata
    if {[string is double -strict "$T"]} {
      set dzT [expr {$dzdT * $T}]
      set dzT [expr {int(round($dzT))}]
    } else {
      set dzT 0
    }
    return $dzT
  }
  
  proc dzP {} {
    variable dzdzenithdistance
    variable dzdha
    variable dzddelta
    while {[catch {client::update "target"} message]} {
      log::warning "unable to determine the target data: $message"
    }
    set zenithdistance [client::getdata "target" "observedzenithdistance"]
    set ha             [client::getdata "target" "observedha"]
    set delta          [client::getdata "target" "observeddelta"]
    set dzP [expr {
      $dzdzenithdistance * (1 - cos($zenithdistance)) + 
      $dzdha             * $ha + 
      $dzddelta          * ($delta - [astrometry::latitude])
    }]
    set dzP [expr {int(round($dzP))}]
    log::debug [format "zenithdistance = %.1fd; ha = %+.1fd; delta = %.1fd; dzP = %+d." \
      [astrometry::radtodeg $zenithdistance] \
      [astrometry::radtodeg $ha] \
      [astrometry::radtodeg $delta] \
      $dzP \
    ]
    return $dzP
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
      set dzT ""
      set dzP ""
      set z   ""
    } else {
      set dzT [dzT]
      set dzP [dzP]
      set z   [expr {$z0 + $dzfilter + $dzT + $dzP + $dzoffset}]
    }
    server::setdata "dzT"         $dzT
    server::setdata "dzP"         $dzP
    server::setdata "requestedz"  $z
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
    server::newactivitycommand "initializing" "idle" secondary::initializeactivitycommand 600000
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] secondary::stopactivitycommand
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] secondary::resetactivitycommand
  }

  proc movewithoutcheck {z0} {
    server::checkstatus
    server::checkactivityformove
    set z0 [normalizez0 $z0]
    setrequestedz0 $z0
    server::newactivitycommand "moving" "idle" "secondary::moveactivitycommand false"
  }

  proc move {z0 setasinitial} {
    server::checkstatus
    server::checkactivityformove
    set z0 [normalizez0 $z0]
    if {$setasinitial} {
      config::setvarvalue "secondary" "initialz0" $z0
    }
    setrequestedz0 $z0
    server::newactivitycommand "moving" "idle" "secondary::moveactivitycommand true"
  }
  
  proc moveforfilter {filter} {
    server::checkstatus
    server::checkactivityformove
    variable dzfilter
    variable dzfilterdict
    if {[llength $dzfilterdict] == 0} {
      set dzfilter 0
    } elseif {![dict exists $dzfilterdict $filter]} {
      error "invalid filter \"$filter\"."
    } else {
      set dzfilter [dict get $dzfilterdict $filter]
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
    if {![string is integer -strict $dzoffset]} {
      error "invalid offset \"$dzoffset\"."
    }
    server::setdata "dzoffset" $dzoffset
    return
  }

  ######################################################################

}
