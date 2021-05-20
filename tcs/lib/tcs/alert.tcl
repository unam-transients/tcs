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

namespace eval "alert" {

  variable svnid {$Id}

  ######################################################################
  
  proc readalertfile {alertfile} {
    set defaultalertfile [file join [directories::etc] "alert"]
      
    # Read the defaults.
    if {[catch {set oldalert [fromjson::readfile $defaultalertfile false]} message]} {
      error "invalid default alert file: $message"
    }

    # Read the alert file and iteratively merge the alerts.
    if {[catch {set newalerts [fromjson::readfile $alertfile true]} message]} {
      error "invalid alert file: $message."
    }
    foreach newalert $newalerts {
      set alert       [dict merge $oldalert $newalert]
      set oldalert $alert
    }

    return $alert  
  }
  
  proc alerttoblock {alert} {
  
    set project [dict create \
      "identifier" [projectidentifier $alert] \
      "name"       "alerts" \
    ]

    set visits {}    
    if {[enabled $alert]} {
      set targetcoordinates [visit::makeequatorialtargetcoordinates [alpha $alert] [delta $alert] [equinox $alert]]
      if {![string equal "" [prologcommand $alert]]} {
        lappend visits [visit::makevisit [prologvisitidentifier $alert] "prolog" $targetcoordinates [prologcommand $alert] [prologestimatedduration $alert]]
      }
      lappend visits [visit::makevisit [visitidentifier $alert] [name $alert] $targetcoordinates [command $alert] [estimatedduration $alert]]
    }
      
    set block [block::makeblock [identifier $alert] [name $alert] $project [constraints $alert] $visits $alert true]

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
          dict set constraints $key [dict get $alert $key]
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
      return [astrometry::parsealpha [dict get $alert "alpha"]]
    } else {
      return ""
    }
  }
  
  proc delta {alert} {
    if {[dict exists $alert "delta"]} {
      return [astrometry::parsedelta [dict get $alert "delta"]]
    } else {
      return ""
    }
  }
  
  proc equinox {alert} {
    if {[dict exists $alert "equinox"]} {
      return [astrometry::parseequinox [dict get $alert "equinox"]]
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
  
  proc estimatedduration {alert} {
    if {[dict exists $alert "estimatedduration"]} {
      return [dict get $alert "estimatedduration"]
    } else {
      return "0m"
    }
  }
  
  proc visitidentifier {alert} {
    if {[dict exists $alert "visitidentifier"]} {
      return [dict get $alert "visitidentifier"]
    } else {
      return "0"
    }
  }
  
  proc prologcommand {alert} {
    if {[dict exists $alert "prologcommand"]} {
      return [dict get $alert "prologcommand"]
    } else {
      return ""
    }
  }
  
  proc prologestimatedduration {alert} {
    if {[dict exists $alert "prologestimatedduration"]} {
      return [dict get $alert "prologestimatedduration"]
    } else {
      return "0m"
    }
  }
  
  proc prologvisitidentifier {alert} {
    if {[dict exists $alert "prologvisitidentifier"]} {
      return [dict get $alert "prologvisitidentifier"]
    } else {
      return "1000"
    }
  }
  
  proc enabled {alert} {
    if {[dict exists $alert "enabled"]} {
      return [dict get $alert "enabled"]
    } else {
      return false
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

}
