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

package require "fromjson"

package provide "block" 0.0

namespace eval "block" {

  ######################################################################
  
  proc identifier {block} {
    if {![dict exists $block "identifier"]} {
      error "invalid block: missing identifier."
    }
    set identifier [dict get $block "identifier"]
    if {[scan $identifier "%d" value] != 1} {
      error "invalid block: invalid identifier \"$identifier\"."
    }
    return $value
  }
  
  proc name {block} {
    if {[dict exists $block "name"]} {
      return [dict get $block "name"]
    } else {
      return ""
    }
  }
  
  proc project {block} {
    if {[dict exists $block "project"]} {
      return [dict get $block "project"]
    } else {
      return ""
    }
  }
  
  proc constraints {block} {
    if {[dict exists $block "constraints"]} {
      return [dict get $block "constraints"]
    } else {
      return ""
    }
  }
  
  proc visits {block} {
    if {[dict exists $block "visits"]} {
      return [dict get $block "visits"]
    } else {
      return ""
    }
  }
  
  proc alert {block} {
    if {[dict exists $block "alert"]} {
      return [dict get $block "alert"]
    } else {
      return ""
    }
  }
  
  proc persistent {block} {
    if {[dict exists $block "persistent"]} {
      return [dict get $block "persistent"]
    } else {
      return false
    }  
  }
  
  proc priority {block} {
    if {[dict exists $block "priority"]} {
      return [dict get $block "priority"]
    } else {
      return "10"
    }  
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
  
  proc checkpriority {block priority} {
  
    setwhy ""
    
    if {![string equal $priority ""] && $priority != [priority $block]} {
      setwhy "priority is [priority $block]."
      return false
    }
    
    return true
  }
  
  ######################################################################
  
  proc makeblock {identifier name project constraints visits {alert ""} {persistent false} {priority "10"}} {
    return [dict create          \
      "identifier"  $identifier  \
      "name"        $name        \
      "project"     $project     \
      "constraints" $constraints \
      "visits"      $visits      \
      "alert"       $alert       \
      "persistent"  $persistent  \
      "priority"    $priority    \
    ]
  }
  
  ######################################################################
  
  proc readfile {file} {
    if {[catch {
      set block [fromjson::readfile $file]
    } message]} {
      error "invalid block file."
    }
    return $block
  }
  
  ######################################################################
  
}
