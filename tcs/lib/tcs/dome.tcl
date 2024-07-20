########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2017, 2019, 2021 Alan M. Watson <alan@astro.unam.mx>
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
package require "controller"
package require "config"
package require "client"
package require "log"
package require "server"

package provide "dome" 0.0

config::setdefaultvalue "dome" "controllerhost"        "dome"
config::setdefaultvalue "dome" "controllerport"       "4545"
config::setdefaultvalue "dome" "sx"                   "-0.087"
config::setdefaultvalue "dome" "sy"                   "-0.001"
config::setdefaultvalue "dome" "sz"                   "+0.000"
config::setdefaultvalue "dome" "parkedazimuth"        "0d"
config::setdefaultvalue "dome" "contactsazimuth"      "64d"
config::setdefaultvalue "dome" "allowedazimutherror"  "3d"
config::setdefaultvalue "dome" "trackinganticipation" "1d"

namespace eval "dome" {

  variable pi [expr {4.0 * atan(1.0)}]

  ######################################################################
  
  variable controllerhost       [config::getvalue "dome" "controllerhost"]
  variable controllerport       [config::getvalue "dome" "controllerport"]
  variable sx                   [config::getvalue "dome" "sx"]
  variable sy                   [config::getvalue "dome" "sy"]
  variable sz                   [config::getvalue "dome" "sz"]
  variable parkedazimuth        [astrometry::parseangle [config::getvalue "dome" "parkedazimuth"]]
  variable contactsazimuth      [astrometry::parseangle [config::getvalue "dome" "contactsazimuth"]]
  variable allowedazimutherror  [astrometry::parseangle [config::getvalue "dome" "allowedazimutherror"]]
  variable trackinganticipation [astrometry::parseangle [config::getvalue "dome" "trackinganticipation"]]
  
  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::statuscommand               ":G;\n"    
  set controller::connectiontype              "persistent"
  set controller::timeoutmilliseconds         2000
  set controller::intervalmilliseconds        1000
  set controller::updatedata                  dome::updatecontrollerdata
  set controller::statusintervalmilliseconds  2000

  set server::datalifeseconds                 5

  set trackingintervalmilliseconds            10000

  ######################################################################

  server::setdata "azimuth"            ""
  server::setdata "lastazimuth"        ""
  server::setdata "maxabsazimutherror" ""
  server::setdata "stoppedtimestamp"   ""
  server::setdata "settled"            false
  server::setdata "settledtimestamp"   [utcclock::combinedformat now]
  server::setdata "allowedtomove"      false

  variable settledelayseconds        3
  variable allowedtomovedelayseconds 10

  variable azimuthdeadzonewidth [astrometry::parseangle "2d"]

  proc isignoredcontrollerresponseresponse {line} {
    expr {[string equal $line "G>"] || [string equal $line ""] || [string equal $line "OK"]}
  }

  proc updatecontrollerdata {controllerresponse} {

    set timestamp [utcclock::combinedformat now]

    set controllerresponse [string trim $controllerresponse]
    if {[isignoredcontrollerresponseresponse $controllerresponse]} {
      return false
    }

    if {[scan $controllerresponse ":%f %\[^;\];" encoderazimuth flags] != 2} {
      error "invalid response: \"$controllerresponse\"."
    }

    set azimuth [astrometry::degtorad $encoderazimuth]

    if {[string first "*" $flags] == -1} {
      set controllerinitialized true
    } else {
      set controllerinitialized false
    }
    
    set stoppedtimestamp [server::getdata "stoppedtimestamp"]
    set lastazimuth      [server::getdata "azimuth"]
    if {$azimuth != $lastazimuth} {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $timestamp
    }
    
    variable settledelayseconds
    set settled          [server::getdata "settled"]
    set settledtimestamp [server::getdata "settledtimestamp"]
    if {![string equal $stoppedtimestamp ""] &&
        [utcclock::diff $timestamp $stoppedtimestamp] >= $settledelayseconds} {
      if {!$settled} {
        set settled true
        set settledtimestamp $timestamp
      }
    } else {
      if {$settled} {
        set settled false
        set settledtimestamp $timestamp
      }
    }

    variable allowedtomovedelayseconds
    if {![string equal $stoppedtimestamp ""] &&
        [utcclock::diff $timestamp $stoppedtimestamp] >= $allowedtomovedelayseconds} {
      set allowedtomove true
    } else {
      set allowedtomove false
    }
    
    server::setstatus "ok"
    server::setdata "timestamp"             $timestamp
    server::setdata "encoderazimuth"        $encoderazimuth
    server::setdata "flags"                 $flags
    server::setdata "controllerinitialized" $controllerinitialized
    server::setdata "azimuth"               $azimuth
    server::setdata "lastazimuth"           $lastazimuth
    server::setdata "stoppedtimestamp"      $stoppedtimestamp
    server::setdata "settled"               $settled
    server::setdata "settledtimestamp"      $settledtimestamp
    server::setdata "allowedtomove"         $allowedtomove
    
    setazimutherror
    
    return true
  }
  
  ######################################################################

  proc setazimutherror {} {
    set azimuth            [server::getdata "azimuth"]
    set requestedazimuth   [server::getdata "requestedazimuth"]
    set maxabsazimutherror [server::getdata "maxabsazimutherror"]
    if {[string equal $requestedazimuth ""]} {
      set azimutherror ""
    } else {
      set azimutherror [astrometry::foldradsymmetric [expr {$azimuth - $requestedazimuth}]]
    }
    if {[string equal $azimutherror ""] || [string equal $maxabsazimutherror ""]} {
      set maxabsazimutherror ""      
    } else {
      set maxabsazimutherror [expr {max($maxabsazimutherror,abs($azimutherror))}]
    }
    server::setdata "azimutherror"       $azimutherror
    server::setdata "maxabsazimutherror" $maxabsazimutherror    
  }
  
  proc startmeasuringmaxabsazimutherror {} {
    server::setdata "maxabsazimutherror" 0
    setazimutherror
  }

  proc stopmeasuringmaxabsazimutherror {} {
    server::setdata "maxabsazimutherror" ""
    setazimutherror
  }

  ######################################################################

  proc gettargetdomeazimuth {} {
    while {[catch {client::update "target"}]} {
      log::warning "unable to determine the target position."
      coroutine::yield
    }
    set targetobservedazimuth        [client::getdata "target" "observedazimuth"]
    set targetobservedzenithdistance [client::getdata "target" "observedzenithdistance"]
    set targetdomeazimuth [modeldomeazimuth $targetobservedazimuth $targetobservedzenithdistance]
    log::debug [format "target dome azimuth is %.1fd." [astrometry::radtodeg $targetdomeazimuth]]
    return $targetdomeazimuth
  }

  proc modeldomeazimuth {azimuth zenithdistance} {
    variable sx
    variable sy
    variable sz
    set tx [expr {sin($zenithdistance) * cos($azimuth)}]
    set ty [expr {sin($zenithdistance) * sin($azimuth)}]
    set tz [expr {cos($zenithdistance)}]
    set a 1.0
    set b [expr {2.0 * ($tx * $sx + $ty * $sy + $tz * $sz)}]
    set c [expr {($sx * $sx + $sy * $sy + $sz * $sz) - 1.0}]
    set f [expr {(- $b + sqrt($b * $b - 4.0 * $a * $c)) / (2.0 * $a)}]
    set dx [expr {$sx + $f * $tx}]
    set dy [expr {$sy + $f * $ty}]
    set dz [expr {$sz + $f * $tz}]
    set domeazimuth [astrometry::foldradpositive [expr {atan2($dy,$dx)}]]
    return $domeazimuth
  }
  
  ######################################################################

  proc settled {} {
    return [server::getdata "settled"]
  }
  
  proc waituntilsettled {} {
    log::debug "waiting until settled."
    server::setdata "stoppedtimestamp" ""
    server::setdata "lastazimuth"      ""
    server::setdata "settled"          false
    while {![settled]} {
      log::debug "waiting until settled."
      coroutine::yield
    }
    log::debug "settled."
  }

  proc waituntilallowedtomove {}  {
    while {![server::getdata "allowedtomove"]} {
      log::debug "waiting until allowed to move."
      coroutine::yield
    }
  }
  
  proc initializeandsettle {} {
    log::debug "requesting controller to initialize."
    controller::sendcommand ":O;\n"
    waituntilsettled    
  }

  proc stopandsettle {} {
    if {[settled]} {
      log::debug "not stopping as the dome is already settled."
      return
    }
    log::debug "requesting the controller to stop."
    controller::flushcommandqueue
    controller::sendcommand ":S;\n"
    waituntilsettled
  }
  
  proc roundazimuth {azimuth} {
    set azimuth [astrometry::radtodeg $azimuth]
    set azimuth [expr {int(round($azimuth))}]
    if {$azimuth == 360} {
      set azimuth 0
    }
    return $azimuth
  }
  
  proc moveandsettle {requestedazimuth {anticipation 0}} {

    stopandsettle

    set requestedazimuth   [astrometry::foldradpositive $requestedazimuth]
    set anticipatedazimuth [astrometry::foldradpositive [expr {$requestedazimuth + $anticipation}]]
    
    variable azimuthdeadzonewidth
    set currentazimuth [server::getdata "azimuth"]
    set dazimuth [astrometry::foldradsymmetric [expr {$anticipatedazimuth - $currentazimuth}]]
    if {abs($dazimuth) <= 0.5 * $azimuthdeadzonewidth} {
      log::debug "not moving the dome as the anticipated azimuth is within the current dead zone."
      return
    }
    
    waituntilallowedtomove

    log::debug [format "requesting the controller to move to %dd." [roundazimuth $anticipatedazimuth]]
    controller::sendcommand [format ":M%d;\n" [roundazimuth $anticipatedazimuth]]

    waituntilsettled

  }
  
  ######################################################################
  
  proc acceptableazimutherror {} {
    set azimutherror [server::getdata "azimutherror"]
    variable allowedazimutherror
    log::debug [format "the dome azimuth is %.1fd." [astrometry::radtodeg [server::getdata "azimuth"]]]
    log::debug [format "the dome azimuth error is %+.1fd." [astrometry::radtodeg $azimutherror]]
    return [expr {abs($azimutherror) <= $allowedazimutherror}]
  }
  
  proc setrequestedazimuth {requestedazimuth} {
    server::setdata "requestedazimuth" $requestedazimuth
    setazimutherror
  }
  
  proc startactivitycommand {} {
    setrequestedazimuth ""
    stopandsettle
  }
  
  proc initializeactivitycommand {} {
    setrequestedazimuth ""
    stopandsettle
    initializeandsettle
    if {![server::getdata "controllerinitialized"]} {
      initializeandsettle
    }
    if {![server::getdata "controllerinitialized"]} {
      error "the controller failed to initialize."
    }
  }
  
  proc stopactivitycommand {} {
    setrequestedazimuth ""
    stopandsettle
  }
  
  proc preparetomoveactivitycommand {} {
    setrequestedazimuth ""
  }
  
  proc moveactivitycommand {azimuth} {
    if {[string equal $azimuth "target"]} {
      moveactivitycommand [gettargetdomeazimuth]
    } elseif {[string equal $azimuth "contacts"]} {
      variable contactsazimuth
      moveactivitycommand [expr {$contactsazimuth + [astrometry::parseangle "10d"]}]
      moveactivitycommand $contactsazimuth 
    } else {
      stopmeasuringmaxabsazimutherror
      set azimuth [astrometry::foldradpositive $azimuth]
      setrequestedazimuth $azimuth
      moveandsettle $azimuth
      if {![acceptableazimutherror]} {
        moveandsettle $azimuth
      }
      if {![acceptableazimutherror]} {
        error [format "the dome azimuth error is %+.1fd." [astrometry::radtodeg [server::getdata "azimutherror"]]]
      }
      startmeasuringmaxabsazimutherror
    }
  }
  
  proc parkactivitycommand {} {
    variable parkedazimuth
    moveactivitycommand $parkedazimuth 
  }
  
  proc preparetotrackactivitycommand {} {
    setrequestedazimuth ""
    stopmeasuringmaxabsazimutherror
  }
  
  proc trackactivitycommand {} {
    stopmeasuringmaxabsazimutherror
    variable trackinganticipation
    if {[catch {client::checkactivity "target" "tracking"} message]} {
      log::warning "tracking cancelled because $message"
      return
    }
    set azimuth [gettargetdomeazimuth]
    setrequestedazimuth $azimuth
    set lastazimuth $azimuth
    while {true} {
      if {[catch {client::checkactivity "target" "tracking"} message]} {
        log::warning "tracking cancelled because $message"
        return
      }
      set azimuth [gettargetdomeazimuth]
      setrequestedazimuth $azimuth    
      if {[acceptableazimutherror]} {
        break
      }
      set dazimuth [astrometry::foldradsymmetric [expr {$azimuth - $lastazimuth}]]
      if {$dazimuth > 0} {
        moveandsettle $azimuth +$trackinganticipation
      } elseif {$dazimuth < 0} {
        moveandsettle $azimuth -$trackinganticipation
      } else {
        moveandsettle $azimuth
      }
      set lastazimuth $azimuth
    }
    server::setactivity "tracking"
    startmeasuringmaxabsazimutherror
    server::clearactivitytimeout
    set lastazimuth $azimuth
    while {true} {
      if {[catch {client::checkactivity "target" "tracking"} message]} {
        log::warning "tracking cancelled because $message"
        return
      }
      set azimuth [gettargetdomeazimuth]
      setrequestedazimuth $azimuth
      set dazimuth [astrometry::foldradsymmetric [expr {$azimuth - $lastazimuth}]]
      if {$dazimuth > 0} {
        moveandsettle $azimuth +$trackinganticipation
      } elseif {$dazimuth < 0} {
        moveandsettle $azimuth -$trackinganticipation
      } else {
        moveandsettle $azimuth
      }
      set lastazimuth $azimuth
      coroutine::yield
    }
  }
  
  proc forceerroractivitycommand {} {
    error "forcing error."
  }

  ######################################################################

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" dome::initializeactivitycommand
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] dome::stopactivitycommand
  }
  
  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] dome::stopactivitycommand
  }

  proc preparetomove {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "preparingtomove" "preparedtomove" dome::preparetomoveactivitycommand
  }

  proc move {azimuth} {
    variable pi
    server::checkstatus
    server::checkactivity "preparedtomove"
    switch $azimuth {
      "target" -
      "contacts" {
        set checkedazimuth $azimuth
      }
      default {
        if {
          [catch {astrometry::parseangle $azimuth dms} checkedazimuth] ||
          $checkedazimuth < 0 ||
          $checkedazimuth >= 2 * $pi
        } {
          error "invalid azimuth: \"$azimuth\"."
        }
      }
    }
    server::newactivitycommand "moving" "idle" "dome::moveactivitycommand $checkedazimuth"
  }

  proc park {} {
    server::checkstatus
    server::checkactivity "preparedtomove"
    server::newactivitycommand "parking" "idle" "dome::parkactivitycommand"
  }

  proc preparetotrack {} {
    server::checkstatus
    server::checkactivityformove
    server::newactivitycommand "preparingtotrack" "preparedtotrack" dome::preparetotrackactivitycommand
  }

  proc track {} {
    server::checkstatus
    server::checkactivity "preparedtotrack"
    server::newactivitycommand "moving" "tracking" "dome::trackactivitycommand"
  }
  
  proc forceerror {} {
    server::checkstatus
    server::newactivitycommand "forcingerror" "idle" dome::forceerroractivitycommand
  }

  ######################################################################

  proc start {} {
    setrequestedazimuth ""
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "started" dome::startactivitycommand
  }

}
