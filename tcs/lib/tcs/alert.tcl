########################################################################

# This file is part of the UNAM telescope control system.

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

  ######################################################################
  
  proc readalertfile {alertfile} {
    set defaultalertfile [file join [directories::etc] "alert"]
      
    # Read the defaults.
    if {[catch {set oldalert [fromjson::readfile $defaultalertfile false]} message]} {
      error "invalid default alert file: $message"
    }

    # Read the alerts from the alert file.
    if {[catch {set newalerts [fromjson::readfile $alertfile true]} message]} {
      error "invalid alert file: $message"
    }

    # Merge the alerts.
    foreach newalert $newalerts {
      set alert    [dict merge $oldalert $newalert]
      set oldalert $alert
    }
    
    # Determine the best position
    set bestuncertainty ""
    foreach newalert $newalerts {
      if {[dict exists $newalert "uncertainty"]} {
        set uncertainty [astrometry::parsedistance [dict get $newalert "uncertainty"]]
        if {[string equal $bestuncertainty ""] || $uncertainty < $bestuncertainty} {
          set bestuncertainty $uncertainty
          set bestalpha   [dict get $newalert "alpha"  ]
          set bestdelta   [dict get $newalert "delta"  ]
          set bestequinox [dict get $newalert "equinox"]
        }
      }
    }
    set bestuncertainty [astrometry::formatdistance $bestuncertainty]
    if {![string equal $bestuncertainty ""]} {
      set alert [dict merge $alert [dict create \
        "uncertainty" $bestuncertainty \
        "alpha"       $bestalpha       \
        "delta"       $bestdelta       \
        "equinox"     $bestequinox     \
      ]]
    }
    
    # Determine the minimum and maximum event timestamps.
    set mineventtimestamp ""
    set maxeventtimestamp ""
    foreach newalert $newalerts {
      if {[dict exists $newalert "eventtimestamp"]} {
        set neweventtimestamp [utcclock::scan [dict get $newalert "eventtimestamp"]]
        if {[string equal $mineventtimestamp ""] || $neweventtimestamp < $mineventtimestamp} {
          set mineventtimestamp $neweventtimestamp
        }
        if {[string equal $maxeventtimestamp ""] || $neweventtimestamp > $maxeventtimestamp} {
          set maxeventtimestamp $neweventtimestamp
        }
      }
    }   
    if {![string equal $mineventtimestamp ""]} {
      set alert [dict merge $alert [dict create "mineventtimestamp" [utcclock::combinedformat $mineventtimestamp]]]
    }
    if {![string equal $maxeventtimestamp ""]} {
      set alert [dict merge $alert [dict create "maxeventtimestamp" [utcclock::combinedformat $maxeventtimestamp]]]
    }
    
    # Determine the minimum priority.
    set priority ""
    foreach newalert $newalerts {
      if {[dict exists $newalert "priority"]} {
        set newpriority [dict get $newalert "priority"]
        if {[string equal $priority ""] || $newpriority < $priority} {
          set priority $newpriority
        }
      }
    }
    if {![string equal $priority ""]} {
      set alert [dict merge $alert [dict create "priority" $priority]]
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
  
  proc originidentifier {alert origin} {
    if {[dict exists $alert "${origin}identifier"]} {
      return [dict get $alert "${origin}identifier"]
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
  
  proc mineventtimestamp {alert} {
    if {[dict exists $alert "mineventtimestamp"]} {
      return [dict get $alert "mineventtimestamp"]
    } else {
      return ""
    }
  }
  
  proc maxeventtimestamp {alert} {
    if {[dict exists $alert "maxeventtimestamp"]} {
      return [dict get $alert "maxeventtimestamp"]
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
  
  proc priority {alert} {
    if {[dict exists $alert "priority"]} {
      return [dict get $alert "priority"]
    } else {
      return "0"
    }
  }
    
  ######################################################################

  proc makealert {name origin identifier type alpha delta equinox uncertainty eventtimestamp alerttimestamp command enabled priority} {
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
      "priority"        $priority          \
    ]
  } 
  
  ######################################################################
  
  variable why

  proc setwhy {whyarg} {
    variable why
    set why $whyarg
  }
  
  proc why {} {
    variable why
    return $why
  }

  ######################################################################  
  
  proc checkpriority {alert priority} {
  
    setwhy ""
    
    if {$priority != [priority $alert]} {
      setwhy "priority is [priority $alert]."
      return false
    }
    
    return true
  }
  
  ######################################################################

}
