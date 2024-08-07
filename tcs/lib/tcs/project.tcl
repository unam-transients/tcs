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
package require "utcclock"

package provide "project" 0.0

namespace eval "project" {

  ######################################################################
  
  proc identifier {project} {
    if {[dict exists $project "identifier"]} {
      # Strip leading zeros and then format like "%04d".
      set identifier [dict get $project "identifier"]
      if {[string equal $identifier ""]} {
        error "invalid project: invalid identifier."
      }
      set identifier [string trimleft $identifier "0"]
      if {[string equal $identifier ""]} {
        set identifier "0"
      }
      set identifier [format "%04d" $identifier]
      return $identifier
    } else {
      error "invalid project: missing identifier."
    }
  }
  
  proc fullidentifier {project} {
    return [format "%s-%s" [utcclock::semester] [identifier $project]]
  }
  
  proc name {project} {
    if {[dict exists $project "name"]} {
      return [dict get $project "name"]
    } else {
      return ""
    }
  }

}
