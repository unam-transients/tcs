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
config::setdefaultvalue "mount" "derotatoroffsetpark"        "0d"
config::setdefaultvalue "mount" "derotatoroffsetunpark"      "0d"
config::setdefaultvalue "mount" "haunpark"                   "0h"
config::setdefaultvalue "mount" "deltaunpark"                "0d"

namespace eval "mount" {

  ######################################################################

  variable allowedpositionerror        [astrometry::parseangle [config::getvalue "mount" "allowedpositionerror"]]
  variable pointingmodelpolarhole      [astrometry::parsedistance [config::getvalue "mount" "pointingmodelpolarhole"]]
  variable axisdhacorrection           [astrometry::parseoffset [config::getvalue "mount" "axisdhacorrection"]]
  variable axisddeltacorrection        [astrometry::parseoffset [config::getvalue "mount" "axisddeltacorrection"]]
  variable trackingsettledlimit        [astrometry::parseoffset [config::getvalue "mount" "trackingsettledlimit"]]
  variable azimuthpark                 [astrometry::parseangle [config::getvalue "mount" "azimuthpark"]]
  variable zenithdistancepark          [astrometry::parseangle [config::getvalue "mount" "zenithdistancepark"]]
  variable derotatoranglepark          [astrometry::parseangle [config::getvalue "mount" "derotatoranglepark"]]
  variable derotatoroffsetpark         [astrometry::parseangle [config::getvalue "mount" "derotatoroffsetpark"]]
  variable derotatoroffsetunpark       [astrometry::parseangle [config::getvalue "mount" "derotatoroffsetunpark"]]
  variable haunpark                    [astrometry::parseha    [config::getvalue "mount" "haunpark"]]
  variable deltaunpark                 [astrometry::parsedelta [config::getvalue "mount" "deltaunpark"]]
  
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
    POSITION.INSTRUMENTAL.DEROTATOR[3].CURRPOS
    CURRENT.TRACK
    CURRENT.TARGETDISTANCE
    CURRENT.DEROTATOR_OFFSET
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

  server::setdata "unparked"                    false

  variable pendingmountazimuth         ""
  variable pendingmountzenithdistance  ""
  variable pendingmountderotatorangle  ""
  variable pendingmountrotation        ""
  variable pendingmountalpha           ""
  variable pendingmountdelta           ""
  variable pendingmountst              ""
  variable pendingtelescopemotionstate ""
  variable pendingtargetdistance       ""
  
  variable telescopemotionstate        ""
  variable targetdistance              ""

  proc updatedata {response} {

    variable pendingmountazimuth
    variable pendingmountzenithdistance
    variable pendingmountderotatorangle
    variable pendingmountrotation
    variable pendingmountalpha
    variable pendingmountdelta
    variable pendingmountst
    variable pendingtelescopemotionstate
    variable pendingtargetdistance

    variable telescopemotionstate
    variable targetdistance

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
    if {[scan $response "%*d DATA INLINE POSITION.INSTRUMENTAL.DEROTATOR\[3\].CURRPOS=%f" value] == 1} {
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
    if {[scan $response "%*d DATA INLINE CURRENT.TARGETDISTANCE=%f" value] == 1} {
      set pendingtargetdistance [astrometry::degtorad $value]
      return false
    }
    if {[scan $response "%*d DATA INLINE CURRENT.DEROTATOR_OFFSET=%f" value] == 1} {
      set pendingmountrotation [astrometry::degtorad $value]
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

    set telescopemotionstate         $pendingtelescopemotionstate
    set targetdistance               $pendingtargetdistance
    
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

    updaterequestedpositiondata false

    checklimits

    server::setstatus "ok"

    return true
  }
  
  ######################################################################

  proc waitwhilemoving {} {
    log::info "waiting while moving."
    variable telescopemotionstate
    variable targetdistance
    set startingdelay 1
    set settlingdelay 0
    set start [utcclock::seconds]
    while {[utcclock::diff now $start] < $startingdelay} {
      coroutine::yield
    }
    while {(($telescopemotionstate >> 3) & 1) == 0} {
      coroutine::yield
    }
    set settle [utcclock::seconds]
    while {[utcclock::diff now $settle] < $settlingdelay} {
      coroutine::yield
    }
    log::info "finished waiting while moving."
  }

  ######################################################################

  proc emergencystophardware {} {
    log::debug "emergency stop: sending emergency stop."
    variable emergencystopcommandidentifier
    set command "$emergencystopcommandidentifier SET TELESCOPE.STOP=1"
    log::debug "emergency stop: sending command \"$command\"."
    controller::flushcommandqueue
    controller::pushcommand "$command\n"
    log::debug "emergency stop: finished sending emergency stop."
  }

  ######################################################################

  proc startemergencystop {} {
    log::warning "starting emergency stop."
    emergencystophardware
    server::setdata "mounttracking" false
    server::erroractivity
  }

  proc finishemergencystop {} {
    log::error "finished emergency stop."
  }

  ######################################################################

  proc emergencystophardware {} {
    log::debug "emergency stop: sending emergency stop."
    controller::flushcommandqueue
    opentsi::sendcommand "SET TELESCOPE.STOP=1"
    log::debug "emergency stop: finished sending emergency stop."
  }

  proc stophardware {} {
    log::info "stopping the mount."
    controller::flushcommandqueue
    opentsi::sendcommand "SET TELESCOPE.STOP=1"
    waitwhilemoving
  }

  proc parkhardware {} {
    variable azimuthpark
    variable zenithdistancepark
    variable derotatoranglepark
    variable derotatoroffsetpark
    log::info "moving to park."
    # Turn off derotator movement.
    opentsi::sendcommand [format "SET [join {
        "POINTING.SETUP.DEROTATOR.SYNCMODE=0"
      } ";"]" \
    ]
    log::info [format "setting derotator offset to %+.2fd." [astrometry::radtodeg $derotatoroffsetpark]]
    # Move the derotator to the parked position.
    opentsi::sendcommand [format "SET [join {
        "POSITION.INSTRUMENTAL.DEROTATOR\[3\].OFFSET=%.6f"
        "POINTING.SETUP.DEROTATOR.OFFSET=%.6f"
        "POINTING.SETUP.DEROTATOR.SYNCMODE=1"
      } ";"]" \
      [astrometry::radtodeg $derotatoroffsetpark] \
      [astrometry::radtodeg $derotatoranglepark ] \
    ]
    # Move the mount to the parked position.
    opentsi::sendcommand [format "SET [join {
        "OBJECT.INSTRUMENTAL.AZ=%.6f"
        "OBJECT.INSTRUMENTAL.ZD=%.6f"
        "POINTING.TRACK=2"
      } ";"]" \
      [astrometry::radtodeg $azimuthpark       ] \
      [astrometry::radtodeg $zenithdistancepark] \
    ]
    waitwhilemoving
    server::setdata "unparked" false
  }
  
  proc unparkhardware {} {
    variable haunpark
    variable deltaunpark
    variable derotatoroffsetunpark
    log::info "moving to unpark."
    set azimuthunpark        [astrometry::equatorialtoazimuth        $haunpark $deltaunpark]
    set zenithdistanceunpark [astrometry::equatorialtozenithdistance $haunpark $deltaunpark]
    # Turn off derotator movement.
    opentsi::sendcommand [format "SET [join {
        "POINTING.SETUP.DEROTATOR.SYNCMODE=0"
      } ";"]" \
    ]
    # Turn on derotator syncronization.
    log::info [format "setting derotator offset to %+.2fd." [astrometry::radtodeg $derotatoroffsetunpark]]
    opentsi::sendcommand [format "SET [join {
        "POSITION.INSTRUMENTAL.DEROTATOR\[3\].OFFSET=%.6f"
        "POINTING.SETUP.DEROTATOR.SYNCMODE=5"
      } ";"]" \
      [astrometry::radtodeg $derotatoroffsetunpark] \
    ]      
    # Move to unparked position.
    opentsi::sendcommand [format "SET [join {
        "OBJECT.INSTRUMENTAL.AZ=%.6f"
        "OBJECT.INSTRUMENTAL.ZD=%.6f"
        "POINTING.TRACK=2"
      } ";"]" \
      [astrometry::radtodeg $azimuthunpark       ] \
      [astrometry::radtodeg $zenithdistanceunpark] \
    ]      
    waitwhilemoving
    server::setdata "unparked" true
  }
  
  proc checkhardware {action} {
    switch $action {
      "preparetomove" -
      "stop" -
      "reset" {
      }
      default {
        if {$opentsi::readystate != 1.0} {
          error "state is \"$opentsi::readystatetext\"."
        }
      }
    }
  }
  
  proc defaultmountrotation {ha delta} {
    return ""
  }

  ######################################################################

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    while {[string equal [server::getstatus] "starting"]} {
      coroutine::yield
    }
    variable azimuthpark
    variable zenithdistancepark
    variable derotatoranglepark
    opentsi::sendcommand [format "SET TELESCOPE.CONFIG.AZ.PARK_POS=%.6f" [astrometry::radtodeg $azimuthpark]]
    opentsi::sendcommand [format "SET TELESCOPE.CONFIG.ZD.PARK_POS=%.6f" [astrometry::radtodeg $zenithdistancepark]]
    opentsi::sendcommand [format "SET TELESCOPE.CONFIG.PORT\[3\].DEROTATOR.PARK_POS=%.6f" [astrometry::radtodeg $derotatoranglepark]]
    set taiminusutc [utcclock::gettaiminusutc]
    log::info [format "setting TAI-UTC to %+d seconds." $taiminusutc]
    opentsi::sendcommand [format "SET TELESCOPE.CONFIG.LOCAL.TAI-UTC=%d" $taiminusutc]
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    opentsi::sendcommand "SET POINTING.SETUP.USE_PORT=3"
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
    opentsi::sendcommand [format "SET [join {
        "OBJECT.HORIZONTAL.AZ=%.6f"
        "OBJECT.HORIZONTAL.ZD=%.6f"
        "POINTING.TRACK=2"
      } ";"]" \
      [astrometry::radtodeg [server::getdata "requestedobservedazimuth"]] \
      [astrometry::radtodeg [server::getdata "requestedobservedzenithdistance"]] \
    ]      
    waitwhilemoving
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
    opentsi::sendcommand [format \
      "SET OBJECT.EQUATORIAL.RA=%.6f;OBJECT.EQUATORIAL.DEC=%.6f;OBJECT.EQUATORIAL.EQUINOX=%.6f;POINTING.TRACK=1" \
      [astrometry::radtohr  [server::getdata "requestedstandardalpha"]] \
      [astrometry::radtodeg [server::getdata "requestedstandarddelta"]] \
      [server::getdata "requestedstandardequinox"] \
    ]      
    waitwhilemoving
    log::info [format "started tracking after %.1f seconds." [utcclock::diff now $start]]
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

  ######################################################################

  proc correcthardware {truemountalpha truemountdelta equinox dalpha ddelta} {
      
      set dseconds [utcclock::diff "now" "19700101T000000"]

      opentsi::sendcommand [format "SET [join {
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
