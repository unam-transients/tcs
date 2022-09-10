########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2012, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "utcclock"

package provide "temperatures" 0.0

namespace eval "temperatures" {

  ######################################################################

  variable controllerhost [config::getvalue "temperatures" "controllerhost"]
  variable controllerport [config::getvalue "temperatures" "controllerport"]

  ######################################################################

  set controller::host                       $controllerhost
  set controller::port                       $controllerport
  set controller::statuscommand              "t\n"
  set controller::timeoutmilliseconds        1000
  set controller::intervalmilliseconds       1000
  set controller::updatedata                 temperatures::updatecontrollerdata
  set controller::statusintervalmilliseconds 5000

  set server::datalifeseconds                60

  ######################################################################
  
  proc exponentialfilter {newvalue oldvalue} {
    set halflife 6
    set alpha [expr {1.0 - exp(log(0.5)/$halflife)}]
    return [expr {$alpha * $newvalue + (1.0 - $alpha) * $oldvalue}]
  }

  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    if {[scan $controllerresponse "%f %f %f %f %f %f %f %f %f %f %f %f %f" P1 P2 P3 P4 A1 A2 A3 A4 A5 A6 A7 A8 S] != 13} {
      error "invalid controller response \"$controllerresponse\"."
    }

    
    if {[string equal "ok" [server::getstatus]]} {
      set P1 [exponentialfilter $P1 [server::getdata "P1"]]
      set P2 [exponentialfilter $P2 [server::getdata "P2"]]
      set P3 [exponentialfilter $P3 [server::getdata "P3"]]
      set P4 [exponentialfilter $P4 [server::getdata "P4"]]
      set A1 [exponentialfilter $A1 [server::getdata "A1"]]
      set A2 [exponentialfilter $A2 [server::getdata "A2"]]
      set A3 [exponentialfilter $A3 [server::getdata "A3"]]
      set A4 [exponentialfilter $A4 [server::getdata "A4"]]
      set A5 [exponentialfilter $A5 [server::getdata "A5"]]
      set A6 [exponentialfilter $A6 [server::getdata "A6"]]
      set A7 [exponentialfilter $A7 [server::getdata "A7"]]
      set A8 [exponentialfilter $A8 [server::getdata "A8"]]
      set S  [exponentialfilter $S  [server::getdata "S" ]]
    }

    set P [expr {($P1 + $P2 + $P3 + $P4) / 4}]

    server::setstatus "ok"
    server::setdata "timestamp" $timestamp
    server::setdata "P1"        [format "%+.3f" $P1]
    server::setdata "P2"        [format "%+.3f" $P2]
    server::setdata "P3"        [format "%+.3f" $P3]
    server::setdata "P4"        [format "%+.3f" $P4]
    server::setdata "A1"        [format "%+.3f" $A1]
    server::setdata "A2"        [format "%+.3f" $A2]
    server::setdata "A3"        [format "%+.3f" $A3]
    server::setdata "A4"        [format "%+.3f" $A4]
    server::setdata "A5"        [format "%+.3f" $A5]
    server::setdata "A6"        [format "%+.3f" $A6]
    server::setdata "A7"        [format "%+.3f" $A7]
    server::setdata "A8"        [format "%+.3f" $A8]
    server::setdata "S"         [format "%+.3f" $S ]
    server::setdata "P"         [format "%+.3f" $P ]
    
    log::writedatalog "temperatures" {timestamp P1 P2 P3 P4 P A1 A2 A3 A4 A5 A6 A7 A8 S}

    return true
  }

  ######################################################################
  
  proc startactivitycommand {} {
  }
  
  ######################################################################
  
  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" "idle" temperatures::resumeactivitycommand
  }
  
  ######################################################################

  proc start {} {
    controller::startstatusloop
    controller::startcommandloop
    server::newactivitycommand "starting" "idle" temperatures::startactivitycommand
  }

  ######################################################################

}
