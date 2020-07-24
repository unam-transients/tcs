########################################################################

# This file is part of the UNAM telescope control system.

# $Id: owsensors.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2012, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "log"
package require "utcclock"

package provide "owsensors" 0.0

namespace eval "owsensors" { 

  variable svnid {$Id}

  ######################################################################

  variable sensors     [config::getvalue "owsensors" "dict"]
  variable sensorslognames [config::getvalue "owsensors" "lognames"]

  ######################################################################

  set server::datalifeseconds 60
  
  ######################################################################
  
  proc getlognames {} {
    variable sensorslognames
    return $sensorslognames
  }
    
  proc getsensornames {} {
    variable sensors
    return [dict keys $sensors]
  }
  
  proc getsensorfile {name} {
    variable sensors
    return [dict get $sensors $name file]
  }

  proc getsensorkeyword {name} {
    variable sensors
    return [dict get $sensors $name keyword]
  }

  proc getsensorkeywords {} {
    set keywords {}
    foreach name [getsensornames] {
      lappend keywords [getsensorkeyword $name]
    }
    return $keywords
  }

  proc getsensorvalue {name} {
    if {[catch {open [getsensorfile $name]} channel]} {
      log::debug "failed to open sensor file for $name."
      return "unknown"
    }
    if {[catch {coroutine::gets $channel 5000} rawvalue]} {
      log::debug "failed to read sensor file for $name."
      close $channel
      return "unknown"
    }
    close $channel
    switch -glob $name {
      "*-temperature" {
        set value [format "%+.1f" $rawvalue]
      }
      "*-humidity" {
        set value [format "%.2f" [expr {$rawvalue / 100}]]
      }
      "*-light-level" {
        if {$rawvalue == 10.23} {
          set rawvalue 0.0
        }
        set value [format "%.2f" [expr {$rawvalue / 10.22}]]
      }
      "*-current" {
        set value [format "%.1f" [expr {$rawvalue / 3.78 * 20.0}]]
      }
    }
    return $value      
  }
  
  ######################################################################

  proc updatedata {} {
    set timestampseconds [utcclock::seconds]
    foreach name [getsensornames] {
      server::setdata $name [getsensorvalue $name]
    }
    server::setdata "timestamp" [utcclock::combinedformat $timestampseconds]
    log::writedatalog "owsensors" [concat timestamp [getlognames]]
  }

  ######################################################################

  variable updatedatapollseconds 15

  proc updatedataloop {} {
    variable updatedatapollseconds
    while {true} {
      if {[catch {updatedata} message]} {
        log::debug "while updating data: $message"
      } else {
        server::setstatus  "ok"
      }
      set updatedatapollmilliseconds [expr {$updatedatapollseconds * 1000}]
      coroutine::after $updatedatapollmilliseconds
    }
  }

  ######################################################################

  proc start {} {
    after idle {
      server::setdata "names"    [owsensors::getsensornames]
      server::setdata "keywords" [owsensors::getsensorkeywords]
      server::setrequestedactivity "idle"
      server::setactivity          "idle"
      coroutine owsensors::updatedataloopcoroutine owsensors::updatedataloop
    }
  }

}
