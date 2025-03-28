########################################################################

# This file is part of the UNAM telescope control system.

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

package provide "seeing" 0.0

namespace eval "seeing" {

  ######################################################################

  set server::datalifeseconds 0

  ######################################################################
  
  variable lasttimestamp ""

  ######################################################################

  proc parsedata {datalines letter} {

    foreach dataline $datalines {
    
      log::debug "data line is \"$dataline\"."

      if {[string equal $letter "a"]} {
    
        # This is the QHYC monitor
      
        set fields [split $dataline ","]
        if {[llength $fields] != 13} {
          continue
        }
        set seeing [lindex $fields 3]
        
        set timestamp [lindex $fields 12]
        set timestamp [string range $timestamp 0 end-2]
        
      } elseif {[string equal $letter "c"]} {
    
        # This is the Colibrí monitor

        if {[ \
          scan $dataline \
            "c %d/%d/%d %d:%d:%d | %*d/%*d/%*d %*d:%*d:%*d | %*f | %f | %f | %*f" \
            day month year hour minute second flux seeing \
        ] != 8} {
          continue
        }
        
        set timestamp [format "%4d-%02d-%02dT%02d:%02d:%02d" $year $month $day $hour $minute $second]
        
      }
      
      log::debug "seeing is \"$seeing\"."
      log::debug "timestamp is \"$timestamp\"."

      if {![string is double $seeing]} {
        log::warning "invalid seeing value \"$seeing\"."
        continue
      }
      if {[catch {
        set timestampseconds [utcclock::scan $timestamp]
      }]} {
        log::warning "invalid timestamp value \"$timestamp\"."
        continue
      }
        
    }
    
    server::setdata "seeing$letter"    [astrometry::arcsectorad $seeing]
    server::setdata "flux$letter"      $flux
    server::setdata "timestamp$letter" [utcclock::combinedformat $timestampseconds]


    foreach {sensorname dataname} {
    } {
      log::writesensorsfile "seeing$sensorname" [server::getdata $dataname] [server::getdata "timestamp$letter"]
    }

  }

  proc getdatafiles {letter} {
    switch $letter {
    "a" { set pattern "*.csv" }
    "c" { set pattern "*.txt" }
    }
    return [lrange \
             [lsort -increasing [glob -nocomplain -directory "[directories::var]/seeing-$letter" $pattern]] \
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
    log::debug "getting data for monitor \”c\”."
    foreach file [getdatafiles "c"] {
      log::debug "file is \"$file\"."
      set datalines [concat $datalines [getdatalines $file]]
    }
    parsedata $datalines "c"
    server::setdata "timestamp" [server::getdata "timestampc"]
    server::setdata "seeing"    [server::getdata "seeingc"]
    server::setdata "seeingas"  [astrometry::radtoarcsec [server::getdata "seeing"]]
    server::setdata "flux"      [server::getdata "fluxc"]
      
    variable lasttimestamp
    set timestamp [server::getdata "timestampc"]
    if {[string equal $lasttimestamp ""] || ![string equal $timestamp $lasttimestamp]} {
      log::debug "writing seeing data log."
      log::writedatalog "seeing" {
        timestamp seeingas flux
      }
      log::debug "finished writing seeing data log."
      set lasttimestamp $timestamp
    }
    
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
      coroutine seeing::updatedataloopcoroutine seeing::updatedataloop
    }
  }

}
