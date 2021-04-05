########################################################################

# This file is part of the UNAM telescope control system.

# $Id: block.tcl 3592 2020-06-10 14:32:51Z Alan $

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

  variable svnid {$Id}

  ######################################################################
  
  proc identifier {block} {
    if {[dict exists $block "identifier"]} {
      return [dict get $block "identifier"]
    } else {
      return ""
    }
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
  
  ######################################################################
  
  proc makeblock {identifier name project constraints visits {alert ""}} {
    return [dict create          \
      "identifier"  $identifier  \
      "name"        $name        \
      "project"     $project     \
      "constraints" $constraints \
      "visits"      $visits      \
      "alert"       $alert       \
    ]
  }
  
  proc makealertblock {identifier name project constraints alert} {
    return [dict create          \
      "identifier"  $identifier  \
      "name"        $name        \
      "project"     $project     \
      "constraints" $constraints \
      "alert"       $alert       \
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
