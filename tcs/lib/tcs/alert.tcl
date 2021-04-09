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
  
  proc readfile {blockfile alertfile} {
  
    log::info "reading alert from block file \"$blockfile\" and alert file \"$alertfile\"."
      
    # Read the partial block from the block file.
    
    if {[catch {set oldblock [block::readfile $blockfile]} message]} {
      error "invalid block file: $message"
    }

    # Read the partial blocks from the alert file and iteratively merge them
    # with partial block from the block file.

    if {[catch {set newblocks [fromjson::readfile $alertfile true]} message]} {
      error "invalid alert file: $message."
    }

    foreach newblock $newblocks {
    
      log::debug "oldblock is $oldblock."
      log::debug "newblock is $newblock."

      set oldalert [block::alert $oldblock]
      set newalert [block::alert $newblock]
      
      # Choose the position with the smallest uncertainty.
      set olduncertainty [alert::uncertainty $oldalert]
      set newuncertainty [alert::uncertainty $newalert]
      if {[string equal $olduncertainty ""]} {
        set identifier      [block::identifier      $newblock]
        set name            [block::name            $newblock]
        set project         [block::project         $newblock]
        set alert           $newalert
      } elseif {[string equal $newuncertainty ""]} {
        set identifier      [block::identifier      $oldblock]
        set name            [block::name            $oldblock]
        set project         [block::project         $oldblock]
        set alert           $oldalert
      } elseif {[astrometry::parsedistance $newuncertainty] <= [astrometry::parsedistance $olduncertainty]} {
        set identifier      [block::identifier      $newblock]
        set name            [block::name            $newblock]
        set project         [block::project         $newblock]
        set alert           $newalert
      } else {
        set identifier      [block::identifier      $oldblock]
        set name            [block::name            $oldblock]
        set project         [block::project         $oldblock]
        set alert           $oldalert
      }
      
      # Choose the earliest eventtimestamp.
      set oldeventtimestamp [alert::eventtimestamp $oldalert]
      set neweventtimestamp [alert::eventtimestamp $newalert]
      if {[string equal "" $neweventtimestamp]} {
        set eventtimestamp $oldeventtimestamp
      } elseif {[string equal "" $oldeventtimestamp]} {
        set eventtimestamp $neweventtimestamp
      } elseif {[utcclock::scan $neweventtimestamp] <  [utcclock::scan $oldeventtimestamp]} {
        set eventtimestamp $neweventtimestamp
      } else {
        set eventtimestamp $oldeventtimestamp
      }

      # Choose the earliest alerttimestamp.
      set oldalerttimestamp [alert::alerttimestamp $oldalert]
      set newalerttimestamp [alert::alerttimestamp $newalert]
      if {[string equal "" $newalerttimestamp]} {
        set alerttimestamp $oldalerttimestamp
      } elseif {[string equal "" $oldalerttimestamp]} {
        set alerttimestamp $newalerttimestamp
      } elseif {[utcclock::scan $newalerttimestamp] <  [utcclock::scan $oldalerttimestamp]} {
        set alerttimestamp $newalerttimestamp
      } else {
        set alerttimestamp $oldalerttimestamp
      }

      # Choose the most specific enabled.
      set oldenabled [alert::enabled $oldalert]
      set newenabled [alert::enabled $newalert]
      if {[string equal "" $newenabled]} {
        set enabled $oldenabled
      } else {
        set enabled $newenabled
      }

      # Choose the most recent constraints.
      set oldconstraints [block::constraints $oldblock]
      set newconstraints [block::constraints $newblock]
      if {[string equal "" $newconstraints]} {
        set constraints $oldconstraints
      } else {
        set constraints $newconstraints
      }
      
      # Choose the most recent command.
      set oldcommand [alert::command $oldalert]
      set newcommand [alert::command $newalert]
      if {[string equal "" $newcommand]} {
        set command $oldcommand
      } else {
        set command $newcommand
      }
      
      set alertname        [alert::name        $alert]
      set alertorigin      [alert::origin      $alert]
      set alertidentifier  [alert::identifier  $alert]
      set alerttype        [alert::type        $alert]
      set alertalpha       [alert::alpha       $alert]
      set alertdelta       [alert::delta       $alert]
      set alertequinox     [alert::equinox     $alert]
      set alertuncertainty [alert::uncertainty $alert]

      set alert [alert::makealert $alertname $alertorigin $alertidentifier $alerttype $alertalpha $alertdelta $alertequinox $alertuncertainty $eventtimestamp $alerttimestamp $command $enabled]
      set block [block::makealertblock $identifier $name $project $constraints $alert true]

      log::debug "block is $block."

      set oldblock $block

    }
    
    set alert [block::alert $block]
    log::info [format "alert name is \"%s\"." [block::name $block]]
    log::info [format "alert origin/identifier/type are %s/%s/%s." [alert::origin $alert] [alert::identifier $alert] [alert::type $alert]]
    log::info [format "alert coordinates are %s %s %s with an uncertainty of %s." \
      [alert::alpha       $alert] \
      [alert::delta       $alert] \
      [alert::equinox     $alert] \
      [alert::uncertainty $alert] \
    ]
    log::info [format "alert command is \"%s\"." [alert::command $alert]]
      
    # Create the proper block.

    set targetcoordinates [visit::makeequatorialtargetcoordinates [alert::alpha $alert] [alert::delta $alert] [alert::equinox $alert]]
    set visit [visit::makevisit "0" ""  $targetcoordinates $command "0m"]
    set block [block::makeblock $identifier $name $project $constraints [list $visit] $alert true]
    
    return $block
  }
    
  ######################################################################
  
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
