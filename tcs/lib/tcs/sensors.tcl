########################################################################

# This file is part of the UNAM telescope control system.

# $Id: sensors.tcl 3601 2020-06-11 03:20:53Z Alan $

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

package require "log"
package require "utcclock"

package provide "sensors" 0.0

namespace eval "sensors" {

  variable svnid {$Id}

  ######################################################################

  variable sensors  [config::getvalue "sensors" "sensors"]
  variable lognames [config::getvalue "sensors" "lognames"]

  ######################################################################

  set server::datalifeseconds 60
  
  ######################################################################
  
  proc getlognames {} {
    variable lognames
    return $lognames
  }
    
  proc getsensornames {} {
    variable sensors
    return [dict keys $sensors]
  }
  
  proc getsensorfile {name} {
    variable sensors
    return [dict get $sensors $name "file"]
  }

  proc getsensorunit {name} {
    variable sensors
    return [dict get $sensors $name "unit"]
  }

  proc getsensormodel {name} {
    variable sensors
    return [dict get $sensors $name "model"]
  }

  proc getsensorkeyword {name} {
    variable sensors
    return [dict get $sensors $name "keyword"]
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
      return ""
    }
    if {[catch {coroutine::gets $channel 5000} rawvalue]} {
      log::debug "failed to read sensor file for $name."
      close $channel
      return ""
    }
    close $channel
    if {[catch {
      switch -glob $name {
        "*-temperature" {
          set value [format "%+.1f" $rawvalue]
        }
        "*-pressure" {
          set value [format "%.0f" $rawvalue]
        }
        "*-humidity" {
          set value [format "%.2f" [expr {$rawvalue / 100}]]
        }
        "*-light-level" {
          switch [getsensormodel $name] {
            "iButtonLink MS-TL" {
              if {$rawvalue == 10.23} {
                set rawvalue 0.0
              }
              set value [format "%.2f" [expr {$rawvalue / 10.22}]]
            }
            default {
              set value $rawvalue
            }
          }
        }
        "*-current" {
          switch [getsensormodel $name] {
            "iButtonLink MS-TC" {
              set value [format "%.1f" [expr {$rawvalue / 3.78 * 20.0}]]
            }
            default {
              set value $rawvalue
            }
          }
        }         
        default {
          set value $rawvalue
        }
      }
    }]} {
     set value $rawvalue
    }
    return $value      
  }
  
  proc getsensortimestamp {name} {
    if {[catch {file mtime [getsensorfile $name]} posixtime]} {
      log::debug "failed to read sensor file timestamp for $name."
      return ""
    }
    set seconds [expr {$posixtime + [utcclock::scan "1970-01-01T00:00:00"]}]
    return [utcclock::combinedformat $seconds 0]
  }
  
  ######################################################################

  proc updatedata {} {
    set timestampseconds [utcclock::seconds]
    server::setdata "names" [getsensornames]
    foreach name [getsensornames] {
        set value     [getsensorvalue     $name]
        set timestamp [getsensortimestamp $name]
        server::setdata $name $value
        server::setdata "${name}-timestamp" $timestamp
    }
    server::setdata "timestamp" [utcclock::combinedformat $timestampseconds]
    log::writedatalog "sensors" [concat "timestamp" [getlognames]]
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
      server::setrequestedactivity "idle"
      server::setactivity          "idle"
      coroutine sensors::updatedataloopcoroutine sensors::updatedataloop
    }
  }

}
