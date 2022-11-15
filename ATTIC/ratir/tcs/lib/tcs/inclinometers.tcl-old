########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "controller"
package require "log"
package require "server"
package require "utcclock"

package provide "inclinometers" 0.0

config::setdefaultvalue "inclinometers" "controllerhost" "inclinometers"
config::setdefaultvalue "inclinometers" "controllerport" "4545"

namespace eval "inclinometers" {

  ######################################################################

  variable controllerhost [config::getvalue "inclinometers" "controllerhost"]
  variable controllerport [config::getvalue "inclinometers" "controllerport"]

  ######################################################################

  set controller::host                       $controllerhost
  set controller::port                       $controllerport
  set controller::statuscommand              ":?SW;\n:P;\n"
  set controller::timeoutmilliseconds        500
  set controller::intervalmilliseconds       200
  set controller::updatedata                 inclinometers::updatecontrollerdata
  set controller::statusintervalmilliseconds 500

  set server::datalifeseconds                 5

  ######################################################################

  variable Xz [astrometry::degtorad -1.9]
  variable Yz [astrometry::degtorad +0.2]

  proc onoroff {i} {
    if {$i == 0} {
      return "off"
    } else {
      return "on"
    }
  }
  
  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    if {[scan $controllerresponse ":%d %d %*d %*d" haswitch deltaswitch] == 2} {
      
      server::setdata "pendinghaswitch"    [onoroff $haswitch]
      server::setdata "pendingdeltaswitch" [onoroff $deltaswitch]
      
      return false
    
    } 
    
    if {[scan $controllerresponse ":%f %f" X Y] == 2} {

      set X [astrometry::degtorad $X]
      set Y [astrometry::degtorad $Y]
      variable Xz
      variable Yz
      set x [expr {$X - $Xz}]
      set y [expr {$Y - $Yz}]
      set h [expr {asin(-sin($y)/cos([astrometry::latitude]))}]
      set z [expr {asin(sqrt(pow(sin($x), 2) + pow(sin($y), 2)))}]
      set P [expr {sqrt(pow(sin([astrometry::latitude]), 2) + pow(cos([astrometry::latitude]) * cos($h), 2))}]
      set Q [expr {atan(tan([astrometry::latitude])/cos($h))}]
      if {$x == 0 || cos($z)/$P >= 1.0} {
        set delta $Q
      } elseif {$x > 0} {
        set delta [expr {$Q-acos(cos($z)/$P)}]
      } else {
        set delta [expr {$Q+acos(cos($z)/$P)}]
      }
      set A [astrometry::equatorialtoazimuth $h $delta]

      server::setstatus "ok"
      server::setdata "timestamp"      $timestamp
      server::setdata "X"              $X
      server::setdata "Y"              $Y
      server::setdata "x"              $x
      server::setdata "y"              $y
      server::setdata "ha"             $h
      server::setdata "delta"          $delta
      server::setdata "azimuth"        $A
      server::setdata "zenithdistance" $z
      server::setdata "haswitch"       [server::getdata "pendinghaswitch"]
      server::setdata "deltaswitch"    [server::getdata "pendingdeltaswitch"]

      return true
      
    }

    error "invalid controller response \"$controllerresponse\"."
  }

  ######################################################################
  
  proc startactivitycommand {} {
  }
  
  proc suspendactivitycommand {} {
    controller::suspendstatusloop
  }
  
  proc resumeactivitycommand {} {
    controller::resumestatusloop
    coroutine::yield
  }
  
  ######################################################################
  
  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" "idle" inclinometers::resumeactivitycommand
  }
  
  proc suspend {} {
    server::checkstatus
    server::checkactivitynot "starting" "error"
    server::newactivitycommand "suspending" "suspended" inclinometers::suspendactivitycommand
  }
  
  proc resume {} {
    server::checkstatus
    server::checkactivitynot "starting" "error"
    server::newactivitycommand "resuming" "idle" inclinometers::resumeactivitycommand
  }
  
  ######################################################################

  proc start {} {
    controller::startstatusloop
    controller::startcommandloop
    server::newactivitycommand "starting" "idle" inclinometers::startactivitycommand
  }

  ######################################################################

}
