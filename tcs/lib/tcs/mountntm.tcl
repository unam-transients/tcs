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
package require "controller"
package require "client"
package require "log"
package require "pointing"
package require "server"

package provide "mountntm" 0.0

config::setdefaultvalue "mount" "controllerhost"             "mount"
config::setdefaultvalue "mount" "controllerport"             65432

source [file join [directories::prefix] "lib" "tcs" "mount.tcl"]

config::setdefaultvalue "mount" "pointingmodelparameters0"   [dict create]
config::setdefaultvalue "mount" "pointingmodelID0"           "0"
config::setdefaultvalue "mount" "pointingmodelIH0"           "0"
config::setdefaultvalue "mount" "pointingmodelparameters180" [dict create]
config::setdefaultvalue "mount" "pointingmodelID180"         "0"
config::setdefaultvalue "mount" "pointingmodelIH180"         "0"
config::setdefaultvalue "mount" "pointingmodelpolarhole"     "0"
config::setdefaultvalue "mount" "axisdhacorrection"          "0"
config::setdefaultvalue "mount" "axisddeltacorrection"       "0"
config::setdefaultvalue "mount" "hapark"                     "0h"
config::setdefaultvalue "mount" "deltapark"                  "90h"
config::setdefaultvalue "mount" "haunpark"                   "0h"
config::setdefaultvalue "mount" "deltaunpark"                "0d"

namespace eval "mount" {

  ######################################################################

  variable controllerhost              [config::getvalue "mount" "controllerhost"]
  variable controllerport              [config::getvalue "mount" "controllerport"]
  variable pointingmodelpolarhole      [astrometry::parsedistance [config::getvalue "mount" "pointingmodelpolarhole"]]
  variable axisdhacorrection           [astrometry::parseoffset [config::getvalue "mount" "axisdhacorrection"]]
  variable axisddeltacorrection        [astrometry::parseoffset [config::getvalue "mount" "axisddeltacorrection"]]
  variable hapark                      [astrometry::parseangle [config::getvalue "mount" "hapark"]]
  variable deltapark                   [astrometry::parseangle [config::getvalue "mount" "deltapark"]]
  variable haunpark                    [astrometry::parseangle [config::getvalue "mount" "haunpark"]]
  variable deltaunpark                 [astrometry::parseangle [config::getvalue "mount" "deltaunpark"]]

  variable usemountcoordinates true

  ######################################################################

  variable pointingmodelparameters0   [config::getvalue "mount" "pointingmodelparameters0"]
  set pointingmodelparameters0 [pointing::setparameter $pointingmodelparameters0 "ID" [config::getvalue "mount" "pointingmodelID0"]]
  set pointingmodelparameters0 [pointing::setparameter $pointingmodelparameters0 "IH" [config::getvalue "mount" "pointingmodelIH0"]]

  variable pointingmodelparameters180 [config::getvalue "mount" "pointingmodelparameters180"]
  set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 "ID" [config::getvalue "mount" "pointingmodelID180"]]
  set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 "IH" [config::getvalue "mount" "pointingmodelIH180"]]

  ######################################################################

  # We use command identifiers 1 for status command, 2 for emergency
  # stop, and 3-99 for normal commands,

  variable statuscommandidentifier        1
  variable emergencystopcommandidentifier 2
  variable firstnormalcommandidentifier   3
  variable lastnormalcommandidentifier    99

  ######################################################################

  set controller::host                        $controllerhost
  set controller::port                        $controllerport
  set controller::connectiontype              "persistent"
  set controller::statuscommand "$statuscommandidentifier GET [join {
    HA.REALPOS
    HA.TARGETDISTANCE
    HA.MOTION_STATE
    HA.TRAJECTORY.RUN
    HA.TRAJECTORY.FREEPOINTS
    HA.REFERENCED
    HA.ERROR_STATE
    DEC.REALPOS
    DEC.TARGETDISTANCE
    DEC.MOTION_STATE
    DEC.TRAJECTORY.RUN
    DEC.TRAJECTORY.FREEPOINTS
    DEC.REFERENCED
    DEC.ERROR_STATE
    LOCAL.REFERENCED
    CABINET.POWER_STATE
    CABINET.REFERENCED
    CABINET.STATUS.LIST
    CABINET.STATUS.GLOBAL
    } ";"]\n"
  set controller::timeoutmilliseconds         10000
  set controller::intervalmilliseconds        50
  set controller::updatedata                  mount::updatecontrollerdata
  set controller::statusintervalmilliseconds  200

  set server::datalifeseconds                 30

  ######################################################################

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
  server::setdata "unparked"                    false

  variable hamotionstate    ""
  variable deltamotionstate ""

  variable moving              true
  variable waitmoving          true
  variable cabinetstatuslist   ""
  variable cabinetpowerstate   ""
  variable cabinetstatusglobal ""
  variable cabinetreferenced   ""
  variable haaxisreferenced    ""
  variable deltaaxisreferenced ""
  variable gpsreferenced       ""
  variable state               ""
  variable freepoints          0

  proc isignoredcontrollerresponse {controllerresponse} {
    expr {
      [regexp {TPL2 OpenTPL-1.99-pl2 CONN [0-9]+ AUTH ENC TLS MESSAGE Welcome .*} $controllerresponse] == 1 ||
      [string equal {AUTH OK 0 0} $controllerresponse] ||
      [regexp {^[0-9]+ COMMAND OK}  $controllerresponse] == 1 ||
      [regexp {^[0-9]+ DATA OK}     $controllerresponse] == 1 ||
      [regexp {^[0-9]+ EVENT INFO } $controllerresponse] == 1
    }
  }

  variable pendingaxisha
  variable pendingaxishaseconds
  variable pendingaxisdelta
  variable pendingaxisdha
  variable pendingaxisddelta
  variable pendinghamotionstate
  variable pendingdeltamotionstate
  variable pendingcabinetstatuslist
  variable pendingcabinetstatusglobal
  variable pendingcabinetpowerstate
  variable pendingcabinetreferenced
  variable pendinghafreepoints
  variable pendingdeltafreepoints

  proc updatecontrollerdata {controllerresponse} {

    variable pendingaxisha
    variable pendingaxishaseconds
    variable pendingaxisdelta
    variable pendingaxisdha
    variable pendingaxisddelta
    variable pendinghamotionstate
    variable pendingdeltamotionstate
    variable pendingcabinetstatuslist
    variable pendingcabinetstatusglobal
    variable pendingcabinetpowerstate
    variable pendingcabinetreferenced
    variable pendinghafreepoints
    variable pendingdeltafreepoints

    variable hamotionstate
    variable deltamotionstate
    variable moving
    variable waitmoving
    variable cabinetstatuslist
    variable cabinetpowerstate
    variable cabinetstatusglobal
    variable cabinetreferenced
    variable state
    variable freepoints

    set controllerresponse [string trim $controllerresponse]
    set controllerresponse [string trim $controllerresponse "\0"]

    if {[isignoredcontrollerresponse $controllerresponse]} {
      return false
    }

    if {
      [regexp {^[0-9]+ EVENT ERROR } $controllerresponse] == 1 ||
      [regexp {^[0-9]+ DATA ERROR } $controllerresponse] == 1
    } {
      log::warning "controller error: \"$controllerresponse\"."
      return false
    }

    if {![scan $controllerresponse "%d " commandidentifier] == 1} {
      log::warning "unexpected controller response \"$controllerresponse\"."
      return true
    }

    variable statuscommandidentifier
    variable emergencystopcommandidentifier
    variable completedcommandidentifier

    if {$commandidentifier == $emergencystopcommandidentifier} {
      log::debug "controller response \"$controllerresponse\"."
      if {[regexp {^[0-9]+ COMMAND COMPLETE} $controllerresponse] == 1} {
        log::error "finished emergency stop."
        return false
      }
    }

    if {$commandidentifier != $statuscommandidentifier} {
      variable currentcommandidentifier
      variable completedcurrentcommand
      log::debug "controller response \"$controllerresponse\"."
      if {[regexp {^[0-9]+ COMMAND COMPLETE} $controllerresponse] == 1} {
        log::debug [format "controller command %d completed." $commandidentifier]
        if {$commandidentifier == $currentcommandidentifier} {
          log::debug "current controller command completed."
          set completedcurrentcommand true
        }
      }
      return false
    }

    #log::debug "status: controller response \"$controllerresponse\"."
    if {[scan $controllerresponse "%*d DATA INLINE CABINET.STATUS.GLOBAL=%d" value] == 1} {
      set pendingcabinetstatusglobal $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE CABINET.POWER_STATE=%f" value] == 1} {
      set pendingcabinetpowerstate $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE CABINET.STATUS.LIST=%s" value] == 1} {
      set pendingcabinetstatuslist [string trim $value "\""]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE CABINET.REFERENCED=%f" value] == 1} {
      set pendingcabinetreferenced $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE HA.REFERENCED=%f" value] == 1} {
      variable haaxisreferenced
      if {[string equal $haaxisreferenced ""] || $value != $haaxisreferenced} {
        if {$value == 1} {
          log::info "the HA axis is referenced."
        } else {
          log::info "the HA axis is not referenced."
        }
      }
      set haaxisreferenced $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE DEC.REFERENCED=%f" value] == 1} {
      variable deltaaxisreferenced
      if {[string equal $deltaaxisreferenced ""] || $value != $deltaaxisreferenced} {
        if {$value == 1} {
          log::info "the δ axis is referenced."
        } else {
          log::info "the δ axis is not referenced."
        }
      }
      set deltaaxisreferenced $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE LOCAL.REFERENCED=%f" value] == 1} {
      variable gpsreferenced
      if {[string equal $gpsreferenced ""] || $value != $gpsreferenced} {
        if {$value == 1} {
          log::info "the GPS is referenced."
        } else {
          log::info "the GPS is not referenced."
        }
      }
      set gpsreferenced $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE HA.REALPOS=%f" value] == 1} {
      set pendingaxisha [astrometry::degtorad $value]
      set pendingaxishaseconds [utcclock::seconds]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE DEC.REALPOS=%f" value] == 1} {
      set pendingaxisdelta [astrometry::degtorad $value]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE HA.TARGETDISTANCE=%f" value] == 1} {
      variable axisdhacorrection
      set pendingaxisdha [expr {[astrometry::degtorad $value] - $axisdhacorrection}]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE DEC.TARGETDISTANCE=%f" value] == 1} {
      variable axisddeltacorrection
      set pendingaxisddelta [expr {[astrometry::degtorad $value] - $axisddeltacorrection}]
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE HA.MOTION_STATE=%d" value] == 1} {
      set pendinghamotionstate $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE DEC.MOTION_STATE=%d" value] == 1} {
      set pendingdeltamotionstate $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE HA.TRAJECTORY.FREEPOINTS=%d" value] == 1} {
      set pendinghafreepoints $value
      return false
    }
    if {[scan $controllerresponse "%*d DATA INLINE DEC.TRAJECTORY.FREEPOINTS=%d" value] == 1} {
      set pendingdeltafreepoints $value
      return false
    }
    if {[regexp {[0-9]+ DATA INLINE } $controllerresponse] == 1} {
      return false
    }
    if {[regexp {[0-9]+ COMMAND COMPLETE} $controllerresponse] != 1} {
      log::warning "unexpected controller response \"$controllerresponse\"."
      return true
    }

    set timestamp [utcclock::combinedformat "now"]

    if {
      ![string equal $pendingcabinetstatuslist ""] &&
      ![string equal $pendingcabinetstatuslist $cabinetstatuslist]
    } {
      if {[string equal -length [string length $cabinetstatuslist] $cabinetstatuslist $pendingcabinetstatuslist]} {
        set statuslist [string range $pendingcabinetstatuslist [string length $cabinetstatuslist] end]
      } else {
        set statuslist $pendingcabinetstatuslist
      }
      set statuslist [split $statuslist ","]
      foreach status $statuslist {
        log::warning "controller reports: \"$status\"."      
      }
    }

    set cabinetstatuslist   $pendingcabinetstatuslist
    set cabinetstatusglobal $pendingcabinetstatusglobal
    set cabinetpowerstate   $pendingcabinetpowerstate
    set cabinetreferenced   $pendingcabinetreferenced
    
    if {$pendinghafreepoints < $pendingdeltafreepoints} {
      set freepoints $pendinghafreepoints
    } else {
      set freepoints $pendingdeltafreepoints
    }

    log::debug "state: cabinetstatusglobal = $cabinetstatusglobal."
    log::debug "state: cabinetpowerstate   = $cabinetpowerstate."
    log::debug "state: cabinetreferenced   = $cabinetreferenced."

    variable laststate
    set laststate $state
    if {$cabinetstatusglobal != 0} {
      set state "error"
    } elseif {$cabinetpowerstate == 0} {
      set state "off"
    } elseif {$cabinetpowerstate < 1 || $cabinetreferenced != 1} {
      set state "referencing"
    } else {
      set state "operational"
    }
    log::debug "state: state = $state."
    if {[string equal $laststate ""]} {
      log::info "the controller state is $state."
    } elseif {![string equal $state $laststate]} {
      if {
        [string equal $state "error"] ||
        [string equal $laststate "operational"]
      } {
        log::error "the controller state changed from $laststate to $state."
        server::erroractivity
      } else {
        log::info "the controller state changed from $laststate to $state."
      }
    }

    if {![string equal $state "operational"]} {
      set mountrotation           0
      set mountha                 0
      set mountdelta              0
      set mounteasttrackingerror  0
      set mountnorthtrackingerror 0
      set axishatrackingerror     0
      set axisdeltatrackingerror  0
    } elseif {$pendingaxisdelta <= 0.5 * [astrometry::pi]} {
      # The mount is not flipped.
      set mountrotation           0
      set mountha                 $pendingaxisha
      set mountdelta              $pendingaxisdelta
      set mounteasttrackingerror  [expr {$pendingaxisdha * cos($mountdelta)}]
      set mountnorthtrackingerror $pendingaxisddelta
      set axishatrackingerror     $pendingaxisdha
      set axisdeltatrackingerror  $pendingaxisddelta
    } else {
      # The mount is flipped.
      set mountrotation           [astrometry::pi]
      set mountha                 [expr {$pendingaxisha - [astrometry::pi]}]
      set mountdelta              [expr {[astrometry::pi] - $pendingaxisdelta}]
      set mounteasttrackingerror  [expr {-($pendingaxisdha) * cos($mountdelta)}]
      set mounteasttrackingerror  $pendingaxisdha
      set mountnorthtrackingerror [expr {-($pendingaxisddelta)}]
      set axishatrackingerror     $pendingaxisdha
      set axisdeltatrackingerror  $pendingaxisddelta
    }
    set mounttrackingerror  [expr {sqrt(pow($mounteasttrackingerror, 2) + pow($mountnorthtrackingerror, 2))}]
    set mountha             [astrometry::foldradsymmetric $mountha]
    set mountalpha          [astrometry::foldradpositive [expr {[astrometry::last $pendingaxishaseconds] - $mountha}]]
    set mountazimuth        [astrometry::equatorialtoazimuth $mountha $mountdelta]
    set mountzenithdistance [astrometry::equatorialtozenithdistance $mountha $mountdelta]

    variable hamotionstate
    set lasthamotionstate $hamotionstate
    set hamotionstate $pendinghamotionstate
    if {![string equal $lasthamotionstate ""] && $hamotionstate != $lasthamotionstate} {
      log::debug [format "status: the HA motion state changed from %05b to %05b." $lasthamotionstate $hamotionstate]
    }

    variable deltamotionstate
    set lastdeltamotionstate $deltamotionstate
    set deltamotionstate $pendingdeltamotionstate
    if {![string equal $lastdeltamotionstate ""] && $deltamotionstate != $lastdeltamotionstate} {
      log::debug [format "status: the δ motion state changed from %05b to %05b." $lastdeltamotionstate $deltamotionstate]
    }

    checkmotionstate "HA" $lasthamotionstate    $hamotionstate
    checkmotionstate "δ"  $lastdeltamotionstate $deltamotionstate

    if {[bit $hamotionstate 0] || [bit $deltamotionstate 0]} {
      set mountmoving true
    } else {
      set mountmoving false
    }
    updatemoving $mountmoving
    
    if {
      [bit $hamotionstate    1] &&
      [bit $hamotionstate    3] &&
      [bit $deltamotionstate 1] &&
      [bit $deltamotionstate 3]
    } { 
      set mounttracking true
    } else {
      set mounttracking false
    }
    updatetracking $mounttracking $axishatrackingerror $axisdeltatrackingerror $mounteasttrackingerror $mountnorthtrackingerror
  
    server::setdata "timestamp"                   $timestamp
    server::setdata "mountha"                     $mountha
    server::setdata "mountalpha"                  $mountalpha
    server::setdata "mountdelta"                  $mountdelta
    server::setdata "mountazimuth"                $mountazimuth
    server::setdata "mountzenithdistance"         $mountzenithdistance
    server::setdata "mountrotation"               $mountrotation
    server::setdata "state"                       $state
    
    checklimits

    updaterequestedpositiondata false

    server::setstatus "ok"

    return true
  }

  ######################################################################

  proc checkmotionstate {name lastmotionstate motionstate} {
    checkmotionstatebit $name $lastmotionstate $motionstate 0 \
      log::debug "moving"
    checkmotionstatebit $name $lastmotionstate $motionstate 1 \
      log::debug "following a trajectory"
    checkmotionstatebit $name $lastmotionstate $motionstate 2 \
      log::warning "being blocked"
    checkmotionstatebit $name $lastmotionstate $motionstate 3 \
      log::debug "having acquisition"
    checkmotionstatebit $name $lastmotionstate $motionstate 4 \
      log::warning "being limited"
  }
  
  proc checkmotionstatebit {name lastmotionstate motionstate bit logproc activity} {
    if {[bit $lastmotionstate $bit] && ![bit $motionstate $bit]} {
      $logproc "$name axis stopped $activity."
    } elseif {![bit $lastmotionstate $bit] && [bit $motionstate $bit]} {
      $logproc "$name axis started $activity."
    }
  }
  
  proc bit {value bit} {
    if {$value & (1 << $bit)} {
      return true
    } else {
      return false
    }
  }
  
  ######################################################################

  proc waitwhilemountrotation {mountrotation} {
    log::debug "waitwhilemountrotation: starting."
    while {$mountrotation == [server::getdata "mountrotation"]} {
      log::debug "waitwhilemountrotation: yielding."
      coroutine::yield
    }
    log::debug "waitwhilemountrotation: finished."
  }
  
  proc waituntilsafetomovebothaxes {} {
    log::debug "waituntilsafetomovebothaxes: starting."
    variable maxzenithdistancelimit
    while {true} {
      set requestedmountha       [server::getdata "requestedmountha"]
      set requestedmountdelta    [server::getdata "requestedmountdelta"]
      set mountha                [server::getdata "mountha"]
      set mountdelta             [server::getdata "mountdelta"]
      if {
        [astrometry::equatorialtozenithdistance $requestedmountha $requestedmountdelta] > $maxzenithdistancelimit
      } {
        error "the requested position is below the zenith distance limit."
      } elseif {
        [astrometry::equatorialtozenithdistance $mountha $requestedmountdelta] < $maxzenithdistancelimit &&
        [astrometry::equatorialtozenithdistance $requestedmountha $mountdelta] < $maxzenithdistancelimit
      } {
        log::debug "waituntilsafetomovebothaxes: finished."
        return
      }
      log::debug "waituntilsafetomovebothaxes: yielding."
      coroutine::yield
    }
  }

  proc isoperational {} {
    variable state
    if {[string equal $state "operational"]} {
      return true
    } else {
      return false
    }
  }

  proc waituntiloperational {} {
    log::debug "waituntiloperational: starting."
    while {![isoperational]} {
      log::debug "waituntiloperational: yielding."
      coroutine::yield
    }
    log::debug "waituntiloperational: finished."
  }

  ######################################################################

  proc axisha {ha delta mountrotation} {
    if {$mountrotation == 0} {
      return $ha
    } else {
      return [expr {[astrometry::pi] + $ha}]
    }
  }

  proc axisdelta {ha delta mountrotation} {
    if {$mountrotation == 0} {
      return $delta
    } else {
      return [expr {[astrometry::pi] - $delta}]
    }
  }

  proc defaultmountrotation {ha delta} {
    if {$ha >= 0} {
      return 0
    } else {
      return [astrometry::pi]
    }
  }

  ######################################################################

  proc pointingmodelparameters {rotation} {
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    if {$rotation == 0} {
      return $pointingmodelparameters0
    } else {
      return $pointingmodelparameters180
    }
  }

  proc setpointingmodelparameters {rotation newpointingmodelparameters} {
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    if {$rotation == 0} {
      set pointingmodelparameters0 $newpointingmodelparameters
      config::setvarvalue "mount" "pointingmodelID0" [pointing::getparameter $pointingmodelparameters0 "ID"]
      config::setvarvalue "mount" "pointingmodelIH0" [pointing::getparameter $pointingmodelparameters0 "IH"]
    } else {
      set pointingmodelparameters180 $newpointingmodelparameters
      config::setvarvalue "mount" "pointingmodelID180" [pointing::getparameter $pointingmodelparameters180 "ID"]
      config::setvarvalue "mount" "pointingmodelIH180" [pointing::getparameter $pointingmodelparameters180 "IH"]
    }
  }

  proc updatepointingmodel {dIH dID rotation} {
    setpointingmodelparameters $rotation [pointing::updateabsolutemodel [pointingmodelparameters $rotation] $dIH $dID]
  }
  
  proc setMAtozero {} {
    log::info "setting MA to zero in the pointing model parameters."
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    set pointingmodelparameters0   [pointing::setparameter $pointingmodelparameters0   MA 0]
    set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 MA 0]
    log::info "the pointing model parameters for mount rotation 0 are: $pointingmodelparameters0:"
    log::info "the pointing model parameters for mount rotation 180 are: $pointingmodelparameters180:"
  }

  proc setMEtozero {} {
    log::info "setting ME to zero in the pointing model parameters."
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    set pointingmodelparameters0   [pointing::setparameter $pointingmodelparameters0   ME 0]
    set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 ME 0]
    log::info "the pointing model parameters for mount rotation 0 are: $pointingmodelparameters0:"
    log::info "the pointing model parameters for mount rotation 180 are: $pointingmodelparameters180:"
  }

  ######################################################################

  variable currentcommandidentifier 0
  variable nextcommandidentifier $firstnormalcommandidentifier
  variable completedcurrentcommand

  proc sendcommand {command} {
    variable currentcommandidentifier
    variable nextcommandidentifier
    variable completedcurrentcommand
    variable firstnormalcommandidentifier
    variable lastnormalcommandidentifier
    set currentcommandidentifier $nextcommandidentifier
    if {$nextcommandidentifier == $lastnormalcommandidentifier} {
      set nextcommandidentifier $firstnormalcommandidentifier
    } else {
      set nextcommandidentifier [expr {$nextcommandidentifier + 1}]
    }
    log::debug "sending controller command $currentcommandidentifier: \"$command\"."
    controller::pushcommand "$currentcommandidentifier $command\n"
  }

  proc sendcommandandwait {command} {
    variable currentcommandidentifier
    variable completedcurrentcommand
    set start [utcclock::seconds]
    set completedcurrentcommand false
    sendcommand $command    
    coroutine::yield
    while {!$completedcurrentcommand} {
      coroutine::yield
    }
    set end [utcclock::seconds]
    log::debug [format "completed controller command $currentcommandidentifier after %.1f seconds." [utcclock::diff $end $start]]
  }

  ######################################################################

  proc emergencystophardware {} {
    log::warning "starting emergency stop."
    variable emergencystopcommandidentifier
    set command "$emergencystopcommandidentifier SET HA.STOP=1;DEC.STOP=1"
    controller::flushcommandqueue
    controller::pushcommand "$command\n"
    log::debug "emergencystophardware: finished sending emergency stop."
  }

  proc stophardware {} {
    log::info "stopping the mount."
    controller::flushcommandqueue
    sendcommandandwait "SET HA.STOP=1;DEC.STOP=1"
    waitwhilemoving
  }

  proc movehardware {movetotrack} {

    updaterequestedpositiondata true
    set requestedmountha       [server::getdata "requestedmountha"]
    set requestedmountdelta    [server::getdata "requestedmountdelta"]
    set requestedmountrotation [server::getdata "requestedmountrotation"]

    set mountha                [server::getdata "mountha"]
    set mountdelta             [server::getdata "mountdelta"]
    set mountrotation          [server::getdata "mountrotation"]

    log::info [format \
      "moving from %s %s (%.0f°) to %s %s (%.0f°)." \
      [astrometry::formatha $mountha] \
      [astrometry::formatdelta $mountdelta] \
      [astrometry::radtodeg $mountrotation] \
      [astrometry::formatha $requestedmountha] \
      [astrometry::formatdelta $requestedmountdelta] \
      [astrometry::radtodeg $requestedmountrotation] \
    ]
    server::setdata "mounttracking" false

    if {$mountrotation != $requestedmountrotation} {
      log::info "moving in δ to flip the mount rotation."
      if {$mountrotation == 0} {
        sendcommandandwait "SET DEC.TARGETPOS=100"
      } else {
        sendcommandandwait "SET DEC.TARGETPOS=80"
      }
      waitwhilemountrotation $mountrotation
      set mountha       [server::getdata "mountha"]
      set mountdelta    [server::getdata "mountdelta"]
      set mountrotation [server::getdata "mountrotation"]
    } else {
      log::info "maintaining the mount rotation."
    }

    set requestedaxisha    [axisha    $requestedmountha $requestedmountdelta $requestedmountrotation]
    set requestedaxisdelta [axisdelta $requestedmountha $requestedmountdelta $requestedmountrotation]
    
    variable maxzenithdistancelimit
    if {
      [astrometry::equatorialtozenithdistance $requestedmountha $requestedmountdelta] > $maxzenithdistancelimit
    } {
      error "the requested position is below the zenith distance limit."
    } elseif {
      [astrometry::equatorialtozenithdistance $mountha $requestedmountdelta] > $maxzenithdistancelimit
    } {
      log::info "moving first in HA to stay above the zenith distance limit."
      sendcommandandwait \
        [format "SET HA.TARGETPOS=%.5f" [astrometry::radtodeg $requestedaxisha]]
      waituntilsafetomovebothaxes
      if {!$movetotrack} {
        log::info "moving in δ."
        sendcommandandwait \
          [format "SET DEC.TARGETPOS=%.5f" [astrometry::radtodeg $requestedaxisdelta]]
      }
    } elseif {
      [astrometry::equatorialtozenithdistance $requestedmountha $mountdelta] > $maxzenithdistancelimit
    } {
      log::info "moving first in δ to stay above the zenith distance limit."
      sendcommandandwait \
        [format "SET DEC.TARGETPOS=%.5f" [astrometry::radtodeg $requestedaxisdelta]]
      waituntilsafetomovebothaxes
      if {!$movetotrack} {
        log::info "moving in HA."
        sendcommandandwait \
          [format "SET HA.TARGETPOS=%.5f" [astrometry::radtodeg $requestedaxisha]]
      }
    } elseif {!$movetotrack} {
      log::info "moving simultaneously in HA and δ."
      sendcommandandwait [format \
        "SET HA.TARGETPOS=%.5f;DEC.TARGETPOS=%.5f" \
        [astrometry::radtodeg $requestedaxisha] \
        [astrometry::radtodeg $requestedaxisdelta] \
      ]
    }
    
    if {!$movetotrack} {
      waitwhilemoving
    }
    
  }
  
  proc parkhardware {} {
    variable hapark
    variable deltapark
    server::setdata "unparked" false
    log::info "moving in δ to pole."
    sendcommandandwait "SET DEC.TARGETPOS=90"
    waitwhilemoving
    log::info [format "moving in HA to park at %+.1fd." [astrometry::radtodeg $hapark]]
    sendcommandandwait "SET HA.TARGETPOS=[astrometry::radtodeg $hapark]"
    waitwhilemoving
    log::info [format "moving in δ to park at %+.1fd." [astrometry::radtodeg $deltapark]]
    sendcommandandwait "SET DEC.TARGETPOS=[astrometry::radtodeg $deltapark]"
    waitwhilemoving
  }
  
  proc unparkhardware {} {
    variable haunpark
    variable deltaunpark
    log::info "moving in δ to pole."
    sendcommandandwait "SET DEC.TARGETPOS=90"
    waitwhilemoving
    log::info [format "moving in HA to unpark at %+.1fd." [astrometry::radtodeg $haunpark]]
    sendcommandandwait "SET HA.TARGETPOS=[astrometry::radtodeg $haunpark]"
    waitwhilemoving
    log::info [format "moving in δ to unpark at %+.1fd." [astrometry::radtodeg $deltaunpark]]
    sendcommandandwait "SET DEC.TARGETPOS=[astrometry::radtodeg $deltaunpark]"
    waitwhilemoving  
    server::setdata "unparked" true
  }
  
  proc checkhardware {action} {
    variable state
    switch $action {
      "initialize" -
      "stop" -
      "reset" {
      }
      default {
        if {![string equal $state "operational"]} {
          error "state is \"$state\"."
        }
      }
    }
  }

  ######################################################################
  
  variable initialized false

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    while {[string equal [server::getstatus] "starting"]} {
      coroutine::yield
    }
    stophardware
    sendcommandandwait [format "SET LOCAL.TAI-UTC=%d" [utcclock::gettaiminusutc]]
    set end [utcclock::seconds]
    log::info [format "finished starting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "initializing."
    updaterequestedpositiondata false
    server::setdata "mounttracking" false
    stophardware
    if {![isoperational]} {
      log::info "attempting to change the controller state from [server::getdata "state"] to operational."
      coroutine::after 1000
      sendcommandandwait "SET CABINET.POWER=0"
      coroutine::after 1000
      sendcommandandwait "SET CABINET.STATUS.CLEAR=1"
      coroutine::after 1000
      sendcommandandwait "SET CABINET.POWER=1"
      coroutine::after 1000
      waituntiloperational
    }
    log::info "the controller state is operational."
    sendcommandandwait "SET DEC.OFFSET=0"
    sendcommandandwait "SET HA.OFFSET=0"
    parkhardware
    set end [utcclock::seconds]
    variable initialized
    set initialize true
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc openactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "opening."
    updaterequestedpositiondata false
    server::setdata "mounttracking" false
    stophardware
    sendcommandandwait "SET DEC.OFFSET=0"
    sendcommandandwait "SET HA.OFFSET=0"
    parkhardware
    set end [utcclock::seconds]
    log::info [format "finished opening after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "stopping."
    updaterequestedpositiondata false
    server::setdata "mounttracking" false
    stophardware
    set end [utcclock::seconds]
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "resetting."
    updaterequestedpositiondata false
    server::setdata "mounttracking" false
    stophardware
    variable initialized
    if {![isoperational] && $initialized} {
      log::info "attempting to change the controller state from [server::getdata "state"] to operational."
      sendcommandandwait "SET CABINET.POWER=0"
      coroutine::after 1000
      sendcommandandwait "SET CABINET.STATUS.CLEAR=1"
      coroutine::after 1000
      sendcommandandwait "SET CABINET.POWER=1"
      coroutine::after 1000
      waituntiloperational
    }
    set end [utcclock::seconds]
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetomoveactivitycommand {} {
    updaterequestedpositiondata false
  }

  proc checktarget {activity expectedactivity} {
    if {[catch {client::checkactivity "target" $expectedactivity} message]} {
      controller::flushcommandqueue
#      controller::sendcommand "NGUIA\n"
      server::setdata "mounttracking" false
      error "$activity cancelled: $message"
    }
    if {![client::getdata "target" "withinlimits"]} {
      controller::flushcommandqueue
#      controller::sendcommand "NGUIA\n"
      server::setdata "mounttracking" false
      error "$activity cancelled: the target is not within the limits."
    }
  }

  proc moveactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "moving."
    if {[catch {checktarget "move" "idle"} message]} {
      log::warning $message
      return
    }
#    log::info "stopping."
#    stophardware
    movehardware false
    if {[checkaftermoving false]} {
      movehardware false
    }
    checkaftermoving true
    set end [utcclock::seconds]
    log::info [format "finished moving after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc parkactivitycommand {} {
    set start [utcclock::seconds]
    maybeendtracking
    log::info "parking."
#    stophardware
    parkhardware
    set end [utcclock::seconds]
    log::info [format "finished parking after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc unparkactivitycommand {} {
    set start [utcclock::seconds]
    log::info "unparking."
#     stophardware
    unparkhardware
    server::setdata "unparked" true
    movehardware false
    if {[checkaftermoving false]} {
      movehardware false
    }
    checkaftermoving true
    set end [utcclock::seconds]
    log::info [format "finished unparking after %.1f seconds." [utcclock::diff $end $start]]
  }

  proc preparetotrackactivitycommand {} {
    updaterequestedpositiondata false
  }

  proc addtrajectorypoints {seconds n dseconds} {
    variable freepoints
    set start [utcclock::seconds]
    log::debug "adding trajectory points."
    if {$n > $freepoints} {
      log::debug "only attempting to add $freepoints points."
      set n $freepoints
    }
    set halist    ""
    set deltalist ""
    set timelist  ""
    set i 0
    if {[catch {
      updaterequestedpositiondata false
      set requestedseconds        [utcclock::scan [server::getdata "requestedtimestamp"]]
      set requestedmountha        [server::getdata "requestedmountha"]
      set requestedmountdelta     [server::getdata "requestedmountdelta"]
      set requestedmountrotation  [server::getdata "requestedmountrotation"]
      set requestedmountharate    [server::getdata "requestedmountharate"]
      set requestedmountdeltarate [server::getdata "requestedmountdeltarate"]
      log::debug "adding $n trajectory points from [utcclock::format $requestedseconds] to [utcclock::format [expr {$requestedseconds + ($n - 1) * $dseconds}]]."
      while {$i < $n} {
        set futurerequestedseconds    [expr {$seconds + $i * $dseconds}]
        set futurerequestedmountha    [astrometry::foldradsymmetric [expr {$requestedmountha + ($futurerequestedseconds - $requestedseconds) * $requestedmountharate}]]
        set futurerequestedmountdelta [expr {$requestedmountdelta + ($futurerequestedseconds - $requestedseconds) * $requestedmountdeltarate}]
        set futurerequestedaxisha     [axisha    $futurerequestedmountha $futurerequestedmountdelta $requestedmountrotation]
        set futurerequestedaxisdelta  [axisdelta $futurerequestedmountha $futurerequestedmountdelta $requestedmountrotation]
        log::debug [format "trajectory point %d is %s %s %s %+.6fd %+.6fd" \
          $i \
          [utcclock::format $futurerequestedseconds] \
          [astrometry::formatha $futurerequestedmountha] \
          [astrometry::formatdelta $futurerequestedmountdelta] \
          [astrometry::radtodeg $futurerequestedaxisha] \
          [astrometry::radtodeg $futurerequestedaxisdelta]]
        if {$i > 0} {
          set halist    "$halist,"
          set deltalist "$deltalist,"
          set timelist  "$timelist,"
        }
        # The NTM documentation states that the times in trajectories should be
        # in UT1 seconds, which we approximate by UTC. However, the LOCAL.UTC
        # variable appears to return the number of POSIX seconds since the
        # epoch, not the number of UTC seconds. Thus, we assume that times in
        # trajectories need to be given in POSIX seconds.
        set futurerequestedposixseconds [utcclock::utctoposixseconds $futurerequestedseconds]
        set timelist  [format "%s%.4f" $timelist  $futurerequestedposixseconds]
        set halist    [format "%s%.6f" $halist    [astrometry::radtodeg $futurerequestedaxisha   ]] 
        set deltalist [format "%s%.6f" $deltalist [astrometry::radtodeg $futurerequestedaxisdelta]]
        set i [expr {$i + 1}]
      }
    } message]} {
      error "unable to calculate new trajectory points: $message"
    }
    set command "SET "
    set command [format "%sHA.TRAJECTORY.BUFFER\[0-%d\].TIME=%s;"       $command [expr {$n - 1}] $timelist ]
    set command [format "%sHA.TRAJECTORY.BUFFER\[0-%d\].TARGETPOS=%s;"  $command [expr {$n - 1}] $halist   ]
    set command [format "%sDEC.TRAJECTORY.BUFFER\[0-%d\].TIME=%s;"      $command [expr {$n - 1}] $timelist ]
    set command [format "%sDEC.TRAJECTORY.BUFFER\[0-%d\].TARGETPOS=%s;" $command [expr {$n - 1}] $deltalist]
    set command [format "%sHA.TRAJECTORY.ADDPOINTS=%d;"                 $command $n]
    set command [format "%sDEC.TRAJECTORY.ADDPOINTS=%d;"                $command $n]
    log::debug "loading trajectory."
    sendcommandandwait $command
    log::debug [format "finished adding trajectory points after %.1f seconds." [utcclock::diff now $start]]
    return [expr {$seconds + $n * $dseconds}]
  }
  
  proc trackoroffsetactivitycommand {move} {
    set start [utcclock::seconds]
    maybeendtracking
    stophardware
    if {$move} {
      log::info "moving to track."
      movehardware true
    }
    if {[catch {checktarget "tracking" "tracking"} message]} {
      log::warning $message
      return
    }
    set trajectoryseconds [utcclock::seconds]
    set trajectorydseconds 2
    set trajectoryn 60
    set trajectorydfutureseconds 120
    set trajectoryseconds [addtrajectorypoints $trajectoryseconds $trajectoryn $trajectorydseconds]
    waituntilnottracking
    sendcommand "SET HA.TRAJECTORY.RUN=1"
    sendcommand "SET DEC.TRAJECTORY.RUN=1"
    waituntiltracking
    log::info [format "started tracking after %.1f seconds." [utcclock::diff now $start]]
    server::setactivity "tracking"
    server::clearactivitytimeout
    while {true} {
      if {[catch {checktarget "tracking" "tracking"} message]} {
        log::warning $message
        return
      }
      if {[utcclock::diff $trajectoryseconds now] < $trajectorydfutureseconds} {
        set trajectoryseconds [addtrajectorypoints $trajectoryseconds $trajectoryn $trajectorydseconds]
      }
      coroutine::after 1000
    }
  }
  
  proc trackactivitycommand {} {
    trackoroffsetactivitycommand true
  }

  proc offsetactivitycommand {} {
    updaterequestedpositiondata true
    set mountrotation          [server::getdata "mountrotation"]
    set requestedmountrotation [server::getdata "requestedmountrotation"]
    if {$mountrotation == $requestedmountrotation} {
      set move false
    } else {
      set move true
    }
    trackoroffsetactivitycommand $move
  }

  ######################################################################

  proc correcthardware {truealpha truedelta equinox dalpha ddelta} {

    set dha [expr {-($dalpha)}]
    updatepointingmodel $dha $ddelta [server::getdata "mountrotation"]

    updaterequestedpositiondata
    set requestedobservedalpha [server::getdata "requestedobservedalpha"]
    set requestedobserveddelta [server::getdata "requestedobserveddelta"]
    log::info "requested mount observed position is [astrometry::formatalpha $requestedobservedalpha] [astrometry::formatdelta $requestedobserveddelta]."  

  }

  ######################################################################

  proc start {} {
    controller::startcommandloop
    controller::startstatusloop
    server::newactivitycommand "starting" "started" mount::startactivitycommand
  }

  ######################################################################

}
