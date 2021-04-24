########################################################################

# This file is part of the UNAM telescope control system.

# $Id: alert.tcl 3557 2020-05-22 18:23:30Z Alan $

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

package require "astrometry"
package require "log"
package require "visit"

package provide "alert" 0.0

config::setdefaultvalue "alert" "prologcommand"            ""
config::setdefaultvalue "alert" "prologidentifier"         "1000"
config::setdefaultvalue "alert" "prologestimatedduration"  "0m"

namespace eval "alert" {

  variable svnid {$Id}

  variable alertprologcommand           [config::getvalue "alert" "prologcommand"]
  variable alertprologidentifier        [config::getvalue "alert" "prologidentifier"]
  variable alertprologestimatedduration [config::getvalue "alert" "prologestimatedduration"]

  ######################################################################
  
  proc readfile {defaultalertfile alertfile} {
  
    log::info "reading alert from \"$defaultalertfile\" and \"$alertfile\"."
      
    # Read the defaults.
    
    if {[catch {set oldalert [fromjson::readfile $defaultalertfile false]} message]} {
      error "invalid default alert file: $message"
    }

    # Read the alert file and iteratively merge the alerts.

    if {[catch {set newalerts [fromjson::readfile $alertfile true]} message]} {
      error "invalid alert file: $message."
    }

    foreach newalert $newalerts {
    
      log::debug "old alert is $oldalert."
      log::debug "new alert is $newalert."
      
      set alert       [dict merge $oldalert $newalert]

      log::debug "merged alert is $alert."

      set oldalert $alert

    }
    
    log::info [format "alert name is \"%s\"." [alert::name $alert]]
    log::info [format "alert origin/identifier/type are %s/%s/%s." [alert::origin $alert] [alert::identifier $alert] [alert::type $alert]]

    set project [dict create \
      "identifier" [alert::projectidentifier $alert] \
      "name"       "alerts" \
    ]

    set constraints [alert::constraints $alert]

    set visits {}
    
    if {[alert::enabled $alert]} {

      log::info [format "alert is enabled."]
      log::info [format "alert coordinates are %s %s %s with an uncertainty of %s." \
        [alert::alpha       $alert] \
        [alert::delta       $alert] \
        [alert::equinox     $alert] \
        [alert::uncertainty $alert] \
      ]
      log::info [format "alert command is \"%s\"." [alert::command $alert]]

      set targetcoordinates [visit::makeequatorialtargetcoordinates [alert::alpha $alert] [alert::delta $alert] [alert::equinox $alert]]
      variable alertprologcommand
      variable alertprologidentifier
      variable alertprologestimatedduration
      if {![string equal "" $alertprologcommand]} {
        lappend visits [visit::makevisit $alertprologidentifier "prolog" $targetcoordinates $alertprologcommand $alertprologestimatedduration]
      }
      lappend visits [visit::makevisit "0" [alert::name $alert] $targetcoordinates [alert::command $alert] "0m"]

    } else {
    
      log::info [format "alert is not enabled."]

    }
      
    set block [block::makeblock [alert::identifier $alert] [alert::name $alert] $project $constraints $visits $alert true]
    
    log::info "block is: $block"
    
    return $block
  }

  ######################################################################
  
  proc projectidentifier {alert} {
    if {[dict exists $alert "projectidentifier"]} {
      return [dict get $alert "projectidentifier"]
    } else {
      return ""
    }
  }
  
  proc projectname {alert} {
    if {[dict exists $alert "projectname"]} {
      return [dict get $alert "projectname"]
    } else {
      return ""
    }
  }
  
  proc constraints {alert} {
    set constraints {}
    foreach key [dict keys $alert] {
      switch -glob $key {
        "min*" -
        "max*" {
          dict append constraints $key [dict get $alert $key]
        }
      }
    }
    return $constraints
  }
  
  proc name {alert} {
    if {[dict exists $alert "name"]} {
      return [dict get $alert "name"]
    } else {
      return ""
    }
  }
  
  proc origin {alert} {
    if {[dict exists $alert "origin"]} {
      return [dict get $alert "origin"]
    } else {
      return ""
    }
  }
  
  proc identifier {alert} {
    if {[dict exists $alert "identifier"]} {
      return [dict get $alert "identifier"]
    } else {
      return ""
    }
  }
  
  proc type {alert} {
    if {[dict exists $alert "type"]} {
      return [dict get $alert "type"]
    } else {
      return ""
    }
  }
  
  proc alpha {alert} {
    if {[dict exists $alert "alpha"]} {
      return [dict get $alert "alpha"]
    } else {
      return ""
    }
  }
  
  proc delta {alert} {
    if {[dict exists $alert "delta"]} {
      return [dict get $alert "delta"]
    } else {
      return ""
    }
  }
  
  proc equinox {alert} {
    if {[dict exists $alert "equinox"]} {
      return [dict get $alert "equinox"]
    } else {
      return ""
    }
  }
  
  proc uncertainty {alert} {
    if {[dict exists $alert "uncertainty"]} {
      return [dict get $alert "uncertainty"]
    } else {
      return ""
    }
  }
  
  proc eventtimestamp {alert} {
    if {[dict exists $alert "eventtimestamp"]} {
      return [dict get $alert "eventtimestamp"]
    } else {
      return ""
    }
  }
  
  proc alerttimestamp {alert} {
    if {[dict exists $alert "alerttimestamp"]} {
      return [dict get $alert "alerttimestamp"]
    } else {
      return ""
    }
  }
  
  proc command {alert} {
    if {[dict exists $alert "command"]} {
      return [dict get $alert "command"]
    } else {
      return ""
    }
  }
  
  proc enabled {alert} {
    if {[dict exists $alert "enabled"]} {
      return [dict get $alert "enabled"]
    } else {
      return ""
    }
  }
  
  proc delay {alert} {
    set eventtimestamp [eventtimestamp $alert]
    set alerttimestamp [alerttimestamp $alert]
    if {![string equal $eventtimestamp ""]} {
      set delay [utcclock::diff now $eventtimestamp]
    } elseif {![string equal $alerttimestamp ""]} {
      set delay [utcclock::diff now $alerttimestamp]
    } else {
      set delay 0
    }
    return $delay
  }
    
  ######################################################################

  proc makealert {name origin identifier type alpha delta equinox uncertainty eventtimestamp alerttimestamp command enabled} {
    return [dict create                    \
      "name"            $name              \
      "origin"          $origin            \
      "identifier"      $identifier        \
      "type"            $type              \
      "alpha"           $alpha             \
      "delta"           $delta             \
      "equinox"         $equinox           \
      "uncertainty"     $uncertainty       \
      "eventtimestamp"  $eventtimestamp    \
      "alerttimestamp"  $alerttimestamp    \
      "command"         $command           \
      "enabled"         $enabled           \
    ]
  } 
  
  ######################################################################
  
  proc setexposures {exposuresarg} {
    variable exposures
    set exposures $exposuresarg
  }

  proc exposures {} {
    variable exposures
    return $exposures
  }
  
}
