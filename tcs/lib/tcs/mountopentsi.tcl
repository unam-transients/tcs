########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "opentsi"
package require "client"
package require "log"
package require "pointing"
package require "server"

package provide "mountopentsi" 0.0

source [file join [directories::prefix] "lib" "tcs" "mount.tcl"]

config::setdefaultvalue "mount" "allowedpositionerror"       "4as"
config::setdefaultvalue "mount" "pointingmodelparameters0"   [dict create]
config::setdefaultvalue "mount" "pointingmodelpolarhole"     "0"
config::setdefaultvalue "mount" "pointingmodelID0"           "0"
config::setdefaultvalue "mount" "pointingmodelIH0"           "0"
config::setdefaultvalue "mount" "pointingmodelparameters180" [dict create]
config::setdefaultvalue "mount" "pointingmodelID180"         "0"
config::setdefaultvalue "mount" "pointingmodelIH180"         "0"
config::setdefaultvalue "mount" "trackingsettledlimit"       "1as"
config::setdefaultvalue "mount" "axisdhacorrection"          "0"
config::setdefaultvalue "mount" "axisddeltacorrection"       "0"
config::setdefaultvalue "mount" "azimuthpark"                "0h"
config::setdefaultvalue "mount" "zenithdistancepark"         "80d"
config::setdefaultvalue "mount" "derotatoranglepark"         "0d"
config::setdefaultvalue "mount" "derotatoroffset"            "0d"
config::setdefaultvalue "mount" "haunpark"                   "0h"
config::setdefaultvalue "mount" "deltaunpark"                "0d"

namespace eval "mount" {

  ######################################################################

  variable allowedpositionerror        [astrometry::parseangle    [config::getvalue "mount" "allowedpositionerror"]]
  variable pointingmodelpolarhole      [astrometry::parsedistance [config::getvalue "mount" "pointingmodelpolarhole"]]
  variable axisdhacorrection           [astrometry::parseoffset   [config::getvalue "mount" "axisdhacorrection"]]
  variable axisddeltacorrection        [astrometry::parseoffset   [config::getvalue "mount" "axisddeltacorrection"]]
  variable trackingsettledlimit        [astrometry::parseoffset   [config::getvalue "mount" "trackingsettledlimit"]]
  variable azimuthpark                 [astrometry::parseangle    [config::getvalue "mount" "azimuthpark"]]
  variable zenithdistancepark          [astrometry::parseangle    [config::getvalue "mount" "zenithdistancepark"]]
  variable derotatoranglepark          [astrometry::parseangle    [config::getvalue "mount" "derotatoranglepark"]]
  variable derotatoroffset             [astrometry::parseangle    [config::getvalue "mount" "derotatoroffset"]]
  variable haunpark                    [astrometry::parseha       [config::getvalue "mount" "haunpark"]]
  variable deltaunpark                 [astrometry::parsedelta    [config::getvalue "mount" "deltaunpark"]]
  variable settlingseconds             [config::getvalue "mount" "settlingseconds"]
  
  variable usemountcoordinates false

  ######################################################################

  variable pointingmodelparameters0   [config::getvalue "mount" "pointingmodelparameters0"]
  set pointingmodelparameters0 [pointing::setparameter $pointingmodelparameters0 "ID" [config::getvalue "mount" "pointingmodelID0"]]
  set pointingmodelparameters0 [pointing::setparameter $pointingmodelparameters0 "IH" [config::getvalue "mount" "pointingmodelIH0"]]

  variable pointingmodelparameters180 [config::getvalue "mount" "pointingmodelparameters180"]
  set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 "ID" [config::getvalue "mount" "pointingmodelID180"]]
  set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 "IH" [config::getvalue "mount" "pointingmodelIH180"]]

  ######################################################################

  set statuscommand "GET [join {
    TELESCOPE.MOTION_STATE    
    POSITION.HORIZONTAL.AZ
    POSITION.HORIZONTAL.ZD
    POSITION.EQUATORIAL.RA_CURRENT
    POSITION.EQUATORIAL.DEC_CURRENT
    POSITION.LOCAL.SIDEREAL_TIME
    POSITION.INSTRUMENTAL.DEROTATOR[3].REALPOS
    CURRENT.TRACK
    CURRENT.TRACKTIME
    CURRENT.DEROTATOR_OFFSET
    POSITION.INSTRUMENTAL.PORT_SELECT.CURRPOS
  } ";"]"

  ######################################################################

  set server::datalifeseconds                   30

  server::setdata "mounttracking"              "unknown"
  server::setdata "mountha"                     ""
  server::setdata "mountalpha"                  ""
  server::setdata "mountdelta"                  ""
  server::setdata "axismeanhatrackingerror"     ""
  server::setdata "axismeandeltatrackingerror"  ""
  server::setdata "mountmeaneasttrackingerror"  ""
  server::setdata "mountmeannorthtrackingerror" ""
  server::setdata "mountrmseasttrackingerror"   ""
  server::setdata "mountrmsnorthtrackingerror"  ""
  server::setdata "mountpveasttrackingerror"    ""
  server::setdata "mountpvnorthtrackingerror"   ""
  server::setdata "mountazimuth"                ""
  server::setdata "mountzenithdistance"         ""
  server::setdata "mountderotatorangle"         ""
  server::setdata "mountrotation"               ""
  server::setdata "state"                       ""
  server::setdata "timestamp"                   ""
  server::setdata "lastcorrectiontimestamp"     ""
  server::setdata "lastcorrectiondalpha"        ""
  server::setdata "lastcorrectionddelta"        ""
  
  server::setdata "requestedobservedalpha"      ""
  server::setdata "requestedobserveddelta"      ""
  server::setdata "requestedobservedha"         ""
  server::setdata "requestedobservedalpharate"  ""
  server::setdata "requestedobserveddeltarate"  ""
  server::setdata "requestedmountrotation"      ""

  server::setdata "requestedmountalpha"         ""
  server::setdata "requestedmountdelta"         ""
  server::setdata "requestedmountha"            ""
  server::setdata "requestedmountalpharate"     ""
  server::setdata "requestedmountdeltarate"     ""

  server::setdata "mountalphaerror"             ""
  server::setdata "mountdeltaerror"             ""
  server::setdata "mounthaerror"                ""
  
  server::setdata "requestedport"               ""
  server::setdata "requestedportposition"       ""
  server::setdata "portposition"                ""
  server::setdata "port"                        ""

  server::setdata "remainingtrackingseconds"    ""

  server::setdata "unparked"                    false

  variable pendingmountazimuth             ""
  variable pendingmountzenithdistance      ""
  variable pendingmountderotatorangle      ""
  variable pendingmountrotation            ""
  variable pendingmountalpha               ""
  variable pendingmountdelta               ""
  variable pendingmountst                  ""
  variable pendingtelescopemotionstate     ""
  variable pendingportposition             ""
  variable predingremainingtrackingseconds ""
  
  variable telescopemotionstate            ""
  variable ontarget                        ""

  proc updatedata {response} {

    variable pendingmountazimuth
    variable pendingmountzenithdistance
    variable pendingmountderotatorangle
    variable pendingmountrotation
    variable pendingmountalpha
    variable pendingmountdelta
    variable pendingmountst
    variable pendingtelescopemotionstate
    variable pendingportposition
    variable predingremainingtrackingseconds

    variable telescopemotionstate
    variable ontarget

    set response [string trim $response]
    set response [string trim $response "\0"]
    
    log::debug "controller response: \"$response\"."

    if {[scan $response "%*d DATA INLINE POSITION.HORIZONTAL.AZ=%f" value] == 1} {
      set pendingmountazimuth [astrometry::degtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE POSITION.HORIZONTAL.ZD=%f" value] == 1} {
      set pendingmountzenithdistance [astrometry::degtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE POSITION.INSTRUMENTAL.DEROTATOR\[3\].REALPOS=%f" value] == 1} {
      set pendingmountderotatorangle [astrometry::degtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE POSITION.EQUATORIAL.RA_CURRENT=%f" value] == 1} {
      set pendingmountalpha [astrometry::hrtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE POSITION.EQUATORIAL.DEC_CURRENT=%f" value] == 1} {
      set pendingmountdelta [astrometry::degtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE POSITION.LOCAL.SIDEREAL_TIME=%f" value] == 1} {
      set pendingmountst [astrometry::hrtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE TELESCOPE.MOTION_STATE=%d" value] == 1} {
      set pendingtelescopemotionstate $value
      return false
    }
    if {[scan $response "%*d DATA INLINE CURRENT.TRACK=%d" value] == 1} {
      if {$value == 0 && [string equal [server::getactivity] "tracking"]} {
        log::error "the mount is no longer tracking."
        server::setactivity "error"
      }
      return false
    }
    if {[scan $response "%*d DATA INLINE CURRENT.TRACKTIME=%s" value] == 1} {
      if {[string equal $value "NULL"]} {
        set predingremainingtrackingseconds ""
      } else {
        set predingremainingtrackingseconds $value
      }
      return false
    }
    if {[scan $response "%*d DATA INLINE CURRENT.DEROTATOR_OFFSET=%f" value] == 1} {
      set pendingmountrotation [astrometry::degtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE POSITION.INSTRUMENTAL.PORT_SELECT.CURRPOS=%f" value] == 1} {
      set pendingportposition $value
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
    
    set mountazimuth                 $pendingmountazimuth
    set mountzenithdistance          $pendingmountzenithdistance
    set mountderotatorangle          $pendingmountderotatorangle
    set mountrotation                $pendingmountrotation
    set mountalpha                   $pendingmountalpha
    set mountdelta                   $pendingmountdelta
    set mountst                      $pendingmountst
    set mountha                      [astrometry::foldradsymmetric [expr {$mountst - $mountalpha}]]
    set portposition                 $pendingportposition
    set remainingtrackingseconds     $predingremainingtrackingseconds

    set telescopemotionstate         $pendingtelescopemotionstate
    if {($telescopemotionstate >> 3) & 1} {
      set ontarget true
    } else {
      set ontarget false
    }
    
    set requestedportposition [server::getdata "requestedportposition"]
    set requestedport         [server::getdata "requestedport"        ]
    if {$portposition == $requestedportposition} {
      set port $requestedport
    } elseif {$portposition == 2} {
      set port "port2"
    } elseif {$portposition == 3} {
      set port "port3"
    } else {
      set port "intermediate"
    }

    set lastportposition [server::getdata "portposition"]
    set lastport         [server::getdata "port"]
    if {![string equal $lastportposition ""] && $lastportposition != $portposition} {
      log::debug "port position changed from $lastportposition to $portposition."
      if {![string equal $lastport ""] && ![string equal $lastport $port]} {
        log::info "port changed from \"$lastport\" to \"$port\"."
      }
    }
    
    set timestamp [utcclock::combinedformat "now"]

    server::setdata "timestamp"           $timestamp
    server::setdata "state"               $opentsi::readystatetext
    server::setdata "mountazimuth"        $mountazimuth
    server::setdata "mountzenithdistance" $mountzenithdistance
    server::setdata "mountderotatorangle" $mountderotatorangle
    server::setdata "mountrotation"       $mountrotation
    server::setdata "mountalpha"          $mountalpha
    server::setdata "mountha"             $mountha
    server::setdata "mountdelta"          $mountdelta
    server::setdata "portposition"        $portposition
    server::setdata "port"                $port
    server::setdata "remainingtrackingseconds"        $remainingtrackingseconds

    updaterequestedpositiondata false

    checklimits

    server::setstatus "ok"

    return true
  }
  
  ######################################################################

  proc waituntilontarget {} {
    log::info "waiting until on target."
    variable ontarget
    variable settlingseconds
    set ontarget false
    while {!$ontarget} {
      coroutine::yield
    }
    set start [utcclock::seconds]
    while {[utcclock::diff now $start] < $settlingseconds} {
      coroutine::yield
    }
    log::info "finished waiting until on target."
  }

  ######################################################################

  proc emergencystophardware {} {
    log::warning "emergency stop: sending emergency stop."
    opentsi::sendemergencystopcommand
    log::warning "emergency stop: finished sending emergency stop."
  }

  proc stophardware {} {
    log::info "stopping the mount."
    controller::flushcommandqueue
    if {[opentsi::isoperational]} {
      opentsi::sendcommandandwait "SET TELESCOPE.STOP=1"
    }
  }
  
  proc setportpositionhardware {portposition} {
    server::setdata "requestedportposition" $portposition
    opentsi::sendcommandandwait [format "SET POINTING.SETUP.USE_PORT=%d" $portposition]
  }

  proc parkhardware {} {
    variable azimuthpark
    variable zenithdistancepark
    variable derotatoranglepark
    log::info "moving to park."
    # Move to the parked position.
    opentsi::sendcommandandwait [format "SET [join {
        "POSITION.INSTRUMENTAL.DEROTATOR\[3\].TARGETPOS=%.6f"
        "POSITION.INSTRUMENTAL.AZ.TARGETPOS=%.6f"
        "POSITION.INSTRUMENTAL.ZD.TARGETPOS=%.6f"
      } ";"]" \
      [astrometry::radtodeg $derotatoranglepark ] \
      [astrometry::radtodeg $azimuthpark       ] \
      [astrometry::radtodeg $zenithdistancepark] \
    ]
    waituntilontarget
    server::setdata "unparked" false
  }
  
  proc unparkhardware {} {
    variable haunpark
    variable deltaunpark
    log::info "moving to unpark."
    set azimuthunpark        [astrometry::equatorialtoazimuth        $haunpark $deltaunpark]
    set zenithdistanceunpark [astrometry::equatorialtozenithdistance $haunpark $deltaunpark]
    # Move to unparked position.
    opentsi::sendcommandandwait [format "SET [join {
        "OBJECT.INSTRUMENTAL.AZ=%.6f"
        "OBJECT.INSTRUMENTAL.ZD=%.6f"
        "POINTING.TRACK=2"
      } ";"]" \
      [astrometry::radtodeg $azimuthunpark       ] \
      [astrometry::radtodeg $zenithdistanceunpark] \
    ]      
    waituntilontarget
    server::setdata "unparked" true
  }
  
  proc checkhardwarefor {action} {
    switch $action {
      "preparetomove" -
      "reset" - 
      "stop" {
      }
      default {
        opentsi::checkreadystate "operational"
      }
    }
  }
  
  proc defaultmountrotation {ha delta} {
    return ""
  }

  ######################################################################

  proc startactivitycommand {} {
    variable derotatoroffset
    set start [utcclock::seconds]
    log::info "starting."
    while {[string equal [server::getstatus] "starting"]} {
      coroutine::yield
    }
    set taiminusutc [utcclock::gettaiminusutc]
    log::info [format "setting TAI-UTC to %+d seconds." $taiminusutc]
    opentsi::sendcommandandwait [format "SET TELESCOPE.CONFIG.LOCAL.TAI-UTC=%d" $taiminusutc]
    set end [utcclock::seconds]
    opentsi::sendcommandandwait "SET POINTING.SETUP.OPTIMIZATION=1"
    opentsi::sendcommandandwait "SET POINTING.SETUP.MIN_TRACKTIME=600"
    opentsi::sendcommandandwait [format "SET [join {
        "POSITION.INSTRUMENTAL.DEROTATOR\[3\].OFFSET=%.6f"
        "POINTING.SETUP.DEROTATOR.SYNCMODE=5"
      } ";"]" \
      [astrometry::radtodeg $derotatoroffset] \
    ]      
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    variable initialport
    setport $initialport
    parkhardware
    set end [utcclock::seconds]
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    updaterequestedpositiondata false
    initializeactivitycommand
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    stophardware
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    set end [utcclock::seconds]
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetomoveactivitycommand {} {
  }

  proc checktarget {activity expectedactivity} {
  }

  proc moveactivitycommand {} {
    set start [utcclock::seconds]
    log::info "moving."
    updaterequestedpositiondata
    opentsi::sendcommandandwait [format "SET [join {
        "OBJECT.HORIZONTAL.AZ=%.6f"
        "OBJECT.HORIZONTAL.ZD=%.6f"
        "POINTING.TRACK=2"
      } ";"]" \
      [astrometry::radtodeg [server::getdata "requestedobservedazimuth"]] \
      [astrometry::radtodeg [server::getdata "requestedobservedzenithdistance"]] \
    ]      
    waituntilontarget
    set end [utcclock::seconds]
    log::info [format "finished moving after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc parkactivitycommand {} {
    set start [utcclock::seconds]
    log::info "parking."
    parkhardware
    set end [utcclock::seconds]
    log::info [format "finished parking after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc unparkactivitycommand {} {
    set start [utcclock::seconds]
    log::info "unparking."
    unparkhardware
    set end [utcclock::seconds]
    log::info [format "finished unparking after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetotrackactivitycommand {} {
  }

  proc trackoroffsetactivitycommand {move} {
    set start [utcclock::seconds]
    if {$move} {
      log::info "moving to track."
    }
    updaterequestedpositiondata
    opentsi::sendcommandandwait [format "SET [join {
        "OBJECT.EQUATORIAL.RA=%.6f"
        "OBJECT.EQUATORIAL.DEC=%.6f"
        "OBJECT.EQUATORIAL.EQUINOX=%.3f"
        "POINTING.TRACK=1"
      } ";"]" \
      [astrometry::radtohr  [server::getdata "requestedstandardalpha"]] \
      [astrometry::radtodeg [server::getdata "requestedstandarddelta"]] \
      [server::getdata "requestedstandardequinox"] \
    ]      
    waituntilontarget
    log::info [format "started tracking after %.1f seconds." [utcclock::diff now $start]]
    log::info [format "%.0f seconds tracking remaining." [server::getdata "remainingtrackingseconds"]]
    server::setactivity "tracking"
    server::clearactivitytimeout
  }
  
  proc trackactivitycommand {} {
    trackoroffsetactivitycommand true
  }

  proc offsetactivitycommand {} {
    updaterequestedpositiondata true
    trackoroffsetactivitycommand false
  }

  proc addtopointingmodelactivitycommand {truealpha truedelta equinox} {

    log::info "adding to pointing model."
    set start [utcclock::seconds]

    set truealpha [astrometry::parsealpha $truealpha]
    set truedelta [astrometry::parsedelta $truedelta]
    set equinox [astrometry::parseequinox $equinox]
    log::info "true position is [astrometry::formatalpha $truealpha] [astrometry::formatdelta $truedelta] $equinox"

    set trueobservedalpha [astrometry::observedalpha $truealpha $truedelta $equinox]
    set trueobserveddelta [astrometry::observeddelta $truealpha $truedelta $equinox]    
    log::info "true observed position is [astrometry::formatalpha $trueobservedalpha] [astrometry::formatdelta $trueobserveddelta]."

    set requestedobservedalpha [server::getdata "requestedobservedalpha"]
    set requestedobserveddelta [server::getdata "requestedobserveddelta"]
    log::info "requested observed position is [astrometry::formatalpha $requestedobservedalpha] [astrometry::formatdelta $requestedobserveddelta]."

    set d [astrometry::distance $requestedobservedalpha $requestedobserveddelta $trueobservedalpha $trueobserveddelta]
    log::info [format "correction is %s." [astrometry::formatdistance $d]]

    set dalpha [astrometry::foldradsymmetric [expr {$requestedobservedalpha - $trueobservedalpha}]]
    set ddelta [astrometry::foldradsymmetric [expr {$requestedobserveddelta - $trueobserveddelta}]]
    set alphaoffset [expr {$dalpha * cos($trueobserveddelta)}]
    set deltaoffset $ddelta
    log::info [format "correction is %s E and %s N." [astrometry::formatoffset $alphaoffset] [astrometry::formatoffset $deltaoffset]]

    variable maxcorrection
    if {$d >= $maxcorrection} {

      log::warning [format "ignoring correction: the correction distance of %s is larger than the maximum allowed of %s." [astrometry::formatdistance $d] [astrometry::formatdistance $maxcorrection]]

    } else {

      addtopointingmodelhardware $truealpha $truedelta $equinox $dalpha $ddelta
      
    }

    log::info [format "finished adding to pointing model after %.1f seconds." [utcclock::diff now $start]]

  }

  ######################################################################

  proc addtopointingmodelhardware {truemountalpha truemountdelta equinox dalpha ddelta} {

      set dseconds [utcclock::diff "now" "19700101T000000"]

      opentsi::sendcommandandwait [format "SET [join {
          "TELESCOPE.MEASUREMENT.MODEL.NEW.RA=%.6f"
          "TELESCOPE.MEASUREMENT.MODEL.NEW.DEC=%.6f"
          "TELESCOPE.MEASUREMENT.MODEL.NEW.EQUINOX=%.3f"
          "TELESCOPE.MEASUREMENT.MODEL.NEW.UTC=%.0f"
          "TELESCOPE.MEASUREMENT.MODEL.NEW.ADD=2"
        } ";"]" \
        [astrometry::radtodeg $truemountalpha] \
        [astrometry::radtodeg $truemountdelta] \
        $equinox \
        $dseconds \
      ]

  }

  ######################################################################

  proc start {} {
    opentsi::start $mount::statuscommand mount::updatedata
    server::newactivitycommand "starting" "started" mount::startactivitycommand
  }

  ######################################################################

}
