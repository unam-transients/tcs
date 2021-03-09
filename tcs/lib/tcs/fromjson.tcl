########################################################################

# This file is part of the UNAM telescope control system.

# $Id: client.tcl 3335 2019-07-01 18:45:22Z Alan $

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

# We use the json package from tcllib. However, for whatever random reason,
# simply loading this package overrides our existing definitions for our html
# and log packages. So, after loading the json package we reload our
# definitions.

package require "json"
source [file join [file dirname [info script]] "packages.tcl"]

package provide "fromjson" 0.0

namespace eval "fromjson" {

  variable svnid {$Id}
  
  # Parse JSON.
  # 
  # JSON is defined at http://www.json.org.
  # 
  # The parser accepts a slightly extended form of JSON: it accepts comment
  # lines wherever white-space can appear in strict JSON. Lines are separated by
  # carriage return or newline characters. A comment line is a line that begins
  # with zero or more space and horizontal tab characters followed by two slash
  # characters (//). Comment lines are treated as if they were empty lines.
  # Other types of comments (e.g., block comments introduced by "/\*" and
  # terminated by "\*/") are not accepted.

  proc parse {string {many false}} {
    set lines [split $string "\n\r"]
    set strictstring ""
    foreach line $lines {
      if {[regexp {^[ \t]*//} $line]} {
        set line ""
      }
      set strictstring "$strictstring$line\n"
    }
    if {$many} {
      if {[catch {set value [json::many-json2dict $strictstring]} message]} {
        error "invalid JSON object: $message"
      }
    } else {
      if {[catch {set value [json::json2dict $strictstring]} message]} {
        error "invalid JSON object: $message"
      }
    }
    return $value
  }
  
  proc read {channel {many false}} {
    set string ""
    while {![eof $channel]} {
      set line [gets $channel]
      set string "$string$line\n"
    }
    return [parse $string $many]
  }
  
  proc readfile {filename {many false}} {
    if {[catch {set channel [open $filename "r"]}]} {
      error "unable to open \"$filename\"."
    }
    chan configure $channel -encoding "utf-8"
    chan configure $channel -buffering "line"
    if {[catch {set value [read $channel $many]} message]} {
      close $channel
      error $message
    }
    close $channel
    return $value
  }

}
