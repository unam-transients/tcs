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
  
  variable file            ""
  variable type            ""
  variable eventidentifier ""
  variable uncertainty     ""
  variable alerttimestamp  ""
  variable eventtimestamp  ""
  variable enabled         true
  variable exposures       ""
  
  proc start {filearg} {
    variable file
    set file $filearg
    variable type
    set type ""
    variable eventidentifier
    set eventidentifier ""
    variable uncertainty
    set uncertainty ""
    variable alerttimestamp
    set alerttimestamp ""
    variable eventtimestamp
    set eventtimestamp ""
    variable enabled
    set enabled true
    variable exposures
    set exposures ""
  }
  
  proc file {} {
    variable file
    return $file
  }
  
  proc type {} {
    variable type
    return $type
  }
  
  proc uncertainty {} {
    variable uncertainty
    return $uncertainty
  }
  
  proc seteventidentifier {eventidentifierarg} {
    variable eventidentifier
    set eventidentifier $eventidentifierarg
  }
  
  proc eventidentifier {} {
    variable eventidentifier
    return $eventidentifier
  }
  
  proc setalerttimestamp {alerttimestamparg} {
    # For multiple time stamps, we take the earliest value.
    variable alerttimestamp
    if {
      [string equal $alerttimestamp ""] ||
      [utcclock::diff $alerttimestamparg $alerttimestamp] < 0
    } {
      set alerttimestamp $alerttimestamparg
    }
  }
  
  proc alerttimestamp {} {
    variable alerttimestamp
    return $alerttimestamp
  }
  
  proc seteventtimestamp {eventtimestamparg} {
    # For multiple time stamps, we take the last value set. For example, the time
    # stamps in swiftbatquicklookposition and swiftbatgrbposition are often
    # slightly different. Presumably, the swiftbatgrbposition value is the
    # definitive one and this is normally the last one set. 
    variable eventtimestamp
    set eventtimestamp $eventtimestamparg
  }
  
  proc eventtimestamp {} {
    variable eventtimestamp
    return $eventtimestamp
  }
  
  proc delay {} {
    variable eventtimestamp
    variable alerttimestamp
    if {![string equal $eventtimestamp ""]} {
      set delay [utcclock::diff now $eventtimestamp]
    } elseif {![string equal $alerttimestamp ""]} {
      set delay [utcclock::diff now $alerttimestamp]
    } else {
      set delay 0
    }
    return $delay
  }
    
  proc setenabled {enabledarg} {
    variable enabled
    set enabled $enabledarg
  }

  proc enabled {} {
    variable enabled
    return $enabled
  }
  
  proc setexposures {exposuresarg} {
    variable exposures
    set exposures $exposuresarg
  }

  proc exposures {} {
    variable exposures
    return $exposures
  }
  
  proc settargetcoordinates {typearg alphaarg deltaarg equinoxarg uncertaintyarg} {
    set uncertaintyarg [astrometry::parseangle $uncertaintyarg]
    variable type
    variable uncertainty
    if {[string equal $uncertainty ""] || $uncertaintyarg <= $uncertainty} {
      set type        $typearg
      set uncertainty $uncertaintyarg
      visit::settargetcoordinates equatorial $alphaarg $deltaarg $equinoxarg
    }
  }
  
}
