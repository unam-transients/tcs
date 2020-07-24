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

package provide "tojson" 0.0

namespace eval "tojson" {

  variable svnid {$Id}
  
  proc identity {x} {
    return $x
  }
  
  proc string {x} {
    # TODO: handle \u and control characters.
    return [format "\"%s\"" [::string map { \" \\" \\ \\\\ } $x]]
  } 

  proc array {x {valuetojson identity}} {
    set y "\["
    set first true
    foreach element $x {
      if {!$first} {
        set y "$y,"
      } 
      set first false
      set y "$y [$valuetojson $element]"
    }
    set y "$y \]"
    return $y
  } 
  
  proc object {x {valuetojson identity}} {
    set y "\{"
    set first true
    foreach key [dict keys $x] {
      if {!$first} {
        set y "$y,"
      } 
      set first false
      set y "$y [string $key] : [$valuetojson [dict get $x $key]]"
    }
    set y "$y \}"
    return $y
  }

}
