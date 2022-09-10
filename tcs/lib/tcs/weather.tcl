########################################################################

# This file is part of the UNAM telescope control system.

# $Id: weather.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "weather" 0.0

namespace eval "weather" {

  variable svnid {$Id}

  ######################################################################

  variable windaveragespeedlimit [config::getvalue "weather" "windaveragespeedlimit"]

  set server::datalifeseconds 900

  ######################################################################

  server::setdata "windaveragespeedlimit" $windaveragespeedlimit
  server::setdata "humidityalarm" "unknown"
  server::setdata "windalarm"     "unknown"
  server::setdata "rainalarm"     "unknown"
  server::setdata "lightlevel"    "unknown"
  server::setdata "cloudiness"    "unknown"
  server::setdata "mustbeclosed"  "unknown"

  proc parsedata {datalines} {

    set previoustemperature        "unknown"
    set previoushumidity           "unknown"
    set previousdewpoint           "unknown"
    set previousdewpointdepression "unknown"
    set previouspressure           "unknown"
    set previoushumidityalarm       "unknown"
    set lastwindalarmseconds        "unknown"

    foreach dataline $datalines {
    
      if {
        [scan $dataline \
          "a.0 %s %s %*s %*s C K %*f %f %*f %*f %f %f %*f %*d %*d %*d %*f %d %d %*d %d %*d %*d" \
          date time temperature humidity dewpoint cloudindex rainindex lightindex] == 8
      } {
      
        # This is the SATINO AAG station. It doesn't have an anemometer.
        
        set windaveragespeed    "unknown"
        set windgustspeed       "unknown"
        set windaverageazimuth  "unknown"
        set rainrate            "unknown"
        set pressure            "unknown"
        
        switch $cloudindex {
          1 {
            set cloudiness "clear"
          }
          2 {
            set cloudiness "light"
          }
          3 {
            set cloudiness "heavy"
          }
          default {
            set cloudiness "unknown"
          }
        }
        
        if {$rainindex > 1} {
          set rainalarm true
        } else {
          set rainalarm false
        }
        
        if {$lightindex > 1} {
          set lightlevel "bright"
        } else {
          set lightlevel "dark"
        }

      } elseif {
        [scan $dataline \
          "a.1 %s %s %*s %*s C K %*f %f %*f %*f %f %f %*f %*d %*d %*d %*f %d %*d %d %d %*d %*d %f" \
          date time temperature humidity dewpoint cloudindex rainindex lightindex windaveragespeed] == 9
      } {
      
        # This is the combination of the SATINO AAG station and PLC.

        set windgustspeed      "unknown"
        set windaverageazimuth "unknown"
        set rainrate           "unknown"
        set pressure           "unknown"
        
        switch $cloudindex {
          1 {
            set cloudiness "clear"
          }
          2 {
            set cloudiness "light"
          }
          3 {
            set cloudiness "heavy"
          }
          default {
            set cloudiness "unknown"
          }
        }
        
        if {$rainindex == 0} {
          set rainalarm false
        } else {
          set rainalarm true
        }
        
        if {$lightindex == 0} {
          set lightlevel "unknown"
        } elseif {$lightindex == 1} {
          set lightlevel "dark"
        } else {
          set lightlevel "bright"
        }
        
        # The wind speed is sometimes close to zero but negative.
        if {$windaveragespeed < 0} {
          set windaveragespeed 0.0
        }

      } elseif {
        [scan $dataline \
          "b.0 %s %s %*s %*f %f %*f %*f %f %f %f %f %f %*f %*f %f %*f %*f %*f %*f %*f %*f %*f %*f %*f %f %*d %d %d %*d %*d %*d %d"\
          date time windaverageazimuth windaveragespeed windgustspeed temperature humidity pressure rainrate dewpoint rainindex cloudindex lightindex] == 13
      } {
      
        # This is the COLIBRÍ PLC
        
        switch $cloudindex {
          1 {
            set cloudiness "clear"
          }
          2 {
            set cloudiness "light"
          }
          3 {
            set cloudiness "heavy"
          }
          default {
            set cloudiness "unknown"
          }
        }
        
        if {$rainindex > 1 || $rainrate > 0} {
          set rainalarm true
        } else {
          set rainalarm false
        }
        
        if {$lightindex > 1} {
          set lightlevel "bright"
        } else {
          set lightlevel "dark"
        }

        # Convert from m/s to km/h        
        set windaveragespeed [expr {$windaveragespeed * 3.6}]
        set windgustspeed    [expr {$windgustspeed * 3.6}]

      } elseif {
        [scan $dataline "%s %s %f %*f %*f %f %f %f %f %f %f %f" \
          date time temperature humidity dewpoint \
          windaveragespeed windgustspeed windaverageazimuth \
          rainrate pressure] == 10
      } {
      
        # This is the OAN weather station.

        if {$rainrate > 0} {
          set rainalarm true
        } else {
          set rainalarm false
        }
        set cloudiness "unknown"
        set lightlevel "unknown"
      
      } else {
            
        log::debug "invalid data line: \"$dataline\"."
        continue
      
      }

      # Fix the format of the date.
      if {[scan $date "%4d-%2d-%2d" years months days] == 3} {
        set date [format "%04d-%02d-%02d" $years $months $days]
      } elseif {[scan $date "%4d%2d%2d" years months days] == 3} {
        set date [format "%04d-%02d-%02d" $years $months $days]
      } else  {
        error "invalid date \"$date\"."
      }

      # Fix the format of the time.
      if {[scan $time "%2d:%2d:%2d" hours minutes seconds] == 3} {
        set time [format "%02d:%02d:%02d" $hours $minutes $seconds]
      } elseif {[scan $time "%2d:%2d" hours minutes] == 2} {
        set time [format "%02d:%02d:00" $hours $minutes]
      } elseif {[scan $time "%2d%2d%2d" hours minutes seconds] == 3} {
        set time [format "%02d:%02d:%02d" $hours $minutes $seconds]
      } elseif {[scan $time "%2d%2d" hours minutes] == 2} {
        set time [format "%02d:%02d:00" $hours $minutes]
      } else {
        error "invalid time \"$time\"."
      }

      # The time in the OAN data files can be 24:00.
      if {[string equal $time "24:00"]} {
        set timestampseconds [expr {[utcclock::scan "$date 23:59:00"] + 60}]
      } else {
        set timestampseconds [utcclock::scan "$date $time"]
      }
        
      set humidity           [expr {$humidity / 100.0}]
      set dewpointdepression [expr {$temperature - $dewpoint}]

      if {[string equal $previoustemperature "unknown"]} {
        set temperaturetrend "unknown"
      } elseif {$previoustemperature < $temperature} {
        set temperaturetrend "rising"
      } elseif {$previoustemperature > $temperature} {
        set temperaturetrend "falling"
      }
      set previoustemperature $temperature

      if {[string equal $previoushumidity "unknown"]} {
        set humiditytrend "unknown"
      } elseif {$previoushumidity < $humidity} {
        set humiditytrend "rising"
      } elseif {$previoushumidity > $humidity} {
        set humiditytrend "falling"
      }
      set previoushumidity $humidity
        
      if {[string equal $previousdewpoint "unknown"]} {
        set dewpointtrend "unknown"
      } elseif {$previousdewpoint < $dewpoint} {
        set dewpointtrend "rising"
      } elseif {$previousdewpoint > $dewpoint} {
        set dewpointtrend "falling"
      }
      set previousdewpoint $dewpoint

      if {[string equal $previousdewpointdepression "unknown"]} {
        set dewpointdepressiontrend "unknown"
      } elseif {$previousdewpointdepression < $dewpointdepression} {
        set dewpointdepressiontrend "rising"
      } elseif {$previousdewpointdepression > $dewpointdepression} {
        set dewpointdepressiontrend "falling"
      }
      set previousdewpointdepression $dewpointdepression

      if {[string equal $pressure "unknown"] || [string equal $previouspressure "unknown"]} {
        set pressuretrend "unknown"
      } elseif {$previouspressure < $pressure} {
        set pressuretrend "rising"
      } elseif {$previouspressure > $pressure} {
        set pressuretrend "falling"
      }
      set previouspressure $pressure

      variable windaveragespeedlimit
      
      log::debug "windaveragespeed is \"$windaveragespeed\""
      log::debug "windaveragespeedlimit is \"$windaveragespeedlimit\""
      log::debug "lastwindalarmseconds is \"$lastwindalarmseconds\""
      if {
        ![string equal $windaveragespeedlimit ""] &&
        ([string equal $lastwindalarmseconds "unknown"] || $windaveragespeed >= $windaveragespeedlimit)
      } {
        set lastwindalarmseconds $timestampseconds
      }
        
      if {![string equal $windaverageazimuth "unknown"]} {
        set windaverageazimuth [expr {22.5 * round($windaverageazimuth / 22.5)}]
      }
                
      if {$humidity < 0.80} {
        set humiditylimit 0.90
      } elseif {$humidity >= 0.90 || [string equal $humiditytrend "unknown"]} {
        set humiditylimit 0.80
      }

    }


    if {[string equal $previoustemperature "unknown"]} {
      error "no valid data."
    }

    if {[string equal $windaveragespeedlimit ""]} {
      set lowwindspeedseconds 0
    } else {
      set lowwindspeedseconds [expr {$timestampseconds - $lastwindalarmseconds}]
    }

    server::setdata "timestamp"               [utcclock::combinedformat $timestampseconds]
    server::setdata "temperature"             $temperature
    server::setdata "temperaturetrend"        $temperaturetrend
    server::setdata "humidity"                $humidity
    server::setdata "humiditytrend"           $humiditytrend
    server::setdata "humiditylimit"           $humiditylimit
    server::setdata "dewpoint"                $dewpoint
    server::setdata "dewpointtrend"           $dewpointtrend
    server::setdata "dewpointdepression"      $dewpointdepression
    server::setdata "dewpointdepressiontrend" $dewpointdepressiontrend
    server::setdata "windaveragespeed"        $windaveragespeed
    server::setdata "windgustspeed"           $windgustspeed
    if {[string equal $windaverageazimuth "unknown"]} {
      server::setdata "windaverageazimuth" $windaverageazimuth
    } else {
      server::setdata "windaverageazimuth" [astrometry::degtorad $windaverageazimuth]
    }
    server::setdata "rainrate"                $rainrate
    server::setdata "pressure"                $pressure
    server::setdata "pressuretrend"           $pressuretrend
    server::setdata "lowwindspeedseconds"     $lowwindspeedseconds

    set lastlightlevel [server::getdata "lightlevel"]
    server::setdata "lightlevel" $lightlevel
    if {$lightlevel != $lastlightlevel} {
      if {[string equal $lastlightlevel "unknown"]} {
        log::summary "the light level is $lightlevel."
      } else {
        log::summary "the light level has changed from $lastlightlevel to $lightlevel."
      }
    }

    if {$humidity >= $humiditylimit || ($humidity >= 0.85 && ![string equal $humiditytrend "falling"])} {
      set humidityalarm true
    } else {
      set humidityalarm false
    } 
  
    if {[string equal $windaveragespeedlimit ""]} {
      set windalarm false
    } elseif {$lowwindspeedseconds < 30 * 60} {
      set windalarm true
    } else {
      set windalarm false
    }

    logalarm $humidityalarm [server::getdata "humidityalarm"] "humidity alarm"
    logalarm $windalarm     [server::getdata "windalarm"    ] "wind alarm"
    logalarm $rainalarm     [server::getdata "rainalarm"    ] "rain alarm"

    server::setdata "humidityalarm" $humidityalarm
    server::setdata "windalarm" $windalarm
    server::setdata "rainalarm" $rainalarm

    set lastcloudiness [server::getdata "cloudiness"]
    server::setdata "cloudiness" $cloudiness
    if {$cloudiness != $lastcloudiness} {
      if {[string equal $lastcloudiness "unknown"]} {
        log::summary "the cloudiness is $cloudiness."
      } else {
        log::summary "the cloudiness has changed from $lastcloudiness to $cloudiness."
      }
    }
    
    set lastmustbeclosed [server::getdata "mustbeclosed"]
    if {
      [server::getdata "windalarm"] ||
      [server::getdata "humidityalarm"] ||
      [server::getdata "rainalarm"]    
    } {
      set mustbeclosed true
    } else {
      set mustbeclosed false
    }
    server::setdata "mustbeclosed" $mustbeclosed
    set mustbeclosed [server::getdata "mustbeclosed"]
    if {[string equal $lastmustbeclosed "unknown"] || $lastmustbeclosed != $mustbeclosed} {
      if {$mustbeclosed} {
        log::summary "the enclosure must be closed."
      } else {
        log::summary "the enclosure may be open."
      }
    }

    log::debug "writing weather data log."
    log::writedatalog "weather" {
      timestamp
      temperature temperaturetrend
      humidity humiditytrend
      dewpoint dewpointtrend
      dewpointdepression dewpointdepressiontrend
      windaveragespeed windgustspeed windaverageazimuth lowwindspeedseconds
      rainrate
      pressure pressuretrend
      humidityalarm windalarm rainalarm mustbeclosed
    }
    log::debug "finished writing weather data log."
    
    foreach {sensorname dataname} {
      temperature          temperature
      humidity             humidity
      dewpoint             dewpoint
      dewpoint-depression  dewpointdepression
      wind-average-speed   windaveragespeed
      wind-gust-speed      windgustspeed
      rain-rate            rainrate
      pressure             pressure
    } {
      log::writesensorsfile "weather-$sensorname" [server::getdata $dataname] [server::getdata "timestamp"]
    }
    log::writesensorsfile "weather-wind-average-azimuth" \
      [astrometry::radtodeg [server::getdata "windaverageazimuth"]] \
      [server::getdata "timestamp"]

  }

  proc logalarm {value lastvalue name} {
    if {[string equal $lastvalue ""]} {
      if {$value} {
        log::summary "the $name is on."
      } else {
        log::summary "the $name is off."
      }
    } elseif {![string equal $lastvalue $value]} {
      if {$value} {
        log::summary "the $name has changed from off to on."
      } else {
        log::summary "the $name has changed from on to off."
      }
    }
  }

  proc getdatafiles {} {
    return [lrange \
             [lsort -increasing [glob -nocomplain -directory "[directories::var]/weather" "*.txt"]] \
             end-2 \
             end]
  }

  proc getdatalines {file} {
    log::debug "file is \"$file\"."
    if {[catch {open $file} channel]}  {
      log::debug "open failed."
      set datalines {}
    } else {
      log::debug "open succeeded."
      set datalines [lrange [split [read $channel] "\n"] 2 end-1]
      close $channel
    }
    return $datalines
  }

  proc updatedata {} {
      set datalines {}
      foreach file [getdatafiles] {
         set datalines [concat $datalines [getdatalines $file]]
      }
      parsedata $datalines
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
      coroutine weather::updatedataloopcoroutine weather::updatedataloop
    }
  }

}
