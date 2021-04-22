########################################################################

# This file is part of the UNAM telescope control system.

# $Id: config.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "utcclock"
package require "fromjson"
package require "log"

package provide "config" 0.0

namespace eval "config" {

  variable svnid {$Id}

  ######################################################################

  variable varvaluedict     [dict create]
  variable etcvaluedict     [dict create]
  variable defaultvaluedict [dict create]

  proc setdefaultvalue {args} {
    set value [lindex $args end]
    set keys [lrange $args 0 end-1]
    variable defaultvaluedict
    eval dict set defaultvaluedict $keys {$value}
  }

  proc getvalue {args} {

    variable varvaluedict
    variable etcvaluedict
    variable defaultvaluedict

    set keys $args

    if {[eval dict exists {$varvaluedict} $keys]} {
      set where "var/tcs/config.json"
      set value [eval dict get {$varvaluedict} $keys]
   } elseif {[eval dict exists {$etcvaluedict} $keys]} {
      set where "etc/tcs/config.json"
      set value [eval dict get {$etcvaluedict} $keys]
    } elseif {[eval dict exists {$defaultvaluedict} $keys]} {
      set where "setdefaultvalue"
      set value [eval dict get {$defaultvaluedict} $keys]
    } else {
      error "invalid configuration key \"$keys\"."
    }

    log::debug "configuration value $keys is \"$value\" (from $where)."

    return $value
  }
  
  proc setvarvalue {args} {
    
    variable varvaluedict

    set value [lindex $args end]
    set keys [lrange $args 0 end-1]

    eval dict set varvaluedict $keys {$value}

    set filename [file join [directories::var] "config.json"]
    set tmpfilename "$filename.[pid]"
    
    set channel [open $tmpfilename "w"]
    puts $channel [format "// Written at %s\n%s\n" [utcclock::format now] [tojson::object $varvaluedict]] 
    close $channel
    
    file rename -force -- "$filename.[pid]" "$filename"    
  }
  
  ######################################################################

  set etcconfigfile [file join [directories::etc] "config-defaults.json"]
  if {[file exists $etcconfigfile]} {
    if {[catch {set defaultvaluedict [fromjson::readfile $etcconfigfile]} message]} {
      log::fatalerror "error reading \"$etcconfigfile\": $message."
    }
  }

  set etcconfigfile [file join [directories::etc] "config.json"]
  if {[file exists $etcconfigfile]} {
    if {[catch {set etcvaluedict [fromjson::readfile $etcconfigfile]} message]} {
      log::fatalerror "error reading \"$etcconfigfile\": $message."
    }
  }

  set varconfigfile [file join [directories::var] "config.json"]
  if {[file exists $varconfigfile]} {
    if {[catch {set varvaluedict [fromjson::readfile $varconfigfile]} message]} {
      log::fatalerror "error reading \"$varconfigfile\": $message."
    }
  }

  ######################################################################

}
