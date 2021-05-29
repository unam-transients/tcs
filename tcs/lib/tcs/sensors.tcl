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

  proc getsensorcorrectionmodel {name} {
    variable sensors
    if {[dict exists $sensors $name "correctionmodel"]} {
      return [dict get $sensors $name "correctionmodel"]
    } else {
      return ""
    }
  }

  proc getsensorkeywords {} {
    set keywords {}
    foreach name [getsensornames] {
      lappend keywords [getsensorkeyword $name]
    }
    return $keywords
  }

  ######################################################################

  proc getsensorrawvalue {name} {
    # Read a sensor value from the  associated file and perform basic unit conversion.
    if {[catch {open [getsensorfile $name]} channel]} {
      log::debug "failed to open sensor file for $name."
      return ""
    }
    if {[catch {coroutine::gets $channel 5000} filevalue]} {
      log::debug "failed to read sensor file for $name."
      close $channel
      return ""
    }
    close $channel
    if {[catch {
      switch -glob $name {
        "*-temperature" {
          set rawvalue $filevalue
        }
        "*-pressure" {
          set rawvalue $filevalue
        }
        "*-humidity" {
          set rawvalue [expr {$filevalue * 0.01}]
        }
        "*-light-level" {
          switch [getsensormodel $name] {
            "iButtonLink MS-TL" {
              if {$filevalue == 10.23} {
                set filevalue 0.0
              }
              set rawvalue [expr {$filevalue / 10.22}]
            }
            default {
              set rawvalue $filevalue
            }
          }
        }
        "*-current" {
          switch [getsensormodel $name] {
            "iButtonLink MS-TC" {
              set rawvalue [expr {$filevalue / 3.78 * 20.0}]
            }
            default {
              set rawvalue $filevalue
            }
          }
        }         
        default {
          set rawvalue $filevalue
        }
      }
    }]} {
     set rawvalue $filevalue
    }
    return $rawvalue      
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
  
  proc correctsensorrawvalue {name rawvalue} {
    set correctionmodel [getsensorcorrectionmodel $name]
    if {[string equal $correctionmodel ""]} {
      set value $rawvalue
    } elseif {
      [scan $correctionmodel "MS-T:1.0:%f" a] == 1 ||
      [scan $correctionmodel "ENV-T:1.0:%f" a] == 1
    } {
      set value [expr {$rawvalue - $a}]
    } elseif {
      [scan $correctionmodel "MS-H:1.0:%f:%f:%f:%f" al bl ah bh] == 4 ||
      [scan $correctionmodel "ENV-H:1.0:%f:%f:%f:%f" al bl ah bh] == 4
    } {
      set cl [expr {$al + $rawvalue * $bl}]
      set ch [expr {$ah + $rawvalue * $bh}]
      if {$rawvalue < 0.30} {
        set c $cl
      } elseif {$rawvalue < 0.40} {
        set c [expr {($cl * (0.40 - $rawvalue) + $ch * ($rawvalue - 0.30)) / 0.10}]
      } else {
        set c $ch
      }
      set value [expr {$rawvalue - $c}]
    } elseif {
        [scan $correctionmodel "ENV-P:1.0:%f" a] == 1
    } {
      set value [expr {$rawvalue - $a}]
    } else {
      error "invalid correction model \"$correctionmodel\" for sensor \"$name\"."
    }
    return $value
  }
  
  ######################################################################
  
  proc formatsensorvalue {name value} {
    if {[string is double -strict $value]} {
      switch -glob $name {
        *-temperature {
          set value [format "%+.1f" $value]
        }
        *-humidity {
          set value [format "%.2f" $value]
        }
        *-chamber-pressure {
          set value [format "%.2e" $value]
        }
        *-pressure {
          set value [format "%.1f" $value]
        }
        *-current {
          set value [format "%.1f" $value]
        }
      }
    }
    return $value
  }
  
  ######################################################################

  proc updatedata {} {
    set timestampseconds [utcclock::seconds]
    server::setdata "names" [getsensornames]
    foreach name [getsensornames] {
        set timestamp [getsensortimestamp $name]
        set rawvalue  [getsensorrawvalue  $name]
        set value     [formatsensorvalue $name [correctsensorrawvalue $name $rawvalue]]
        server::setdata $name $value
        server::setdata "${name}-raw" $rawvalue
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
        log::warning "while updating data: $message"
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
