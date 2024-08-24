########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "directories"
package require "log"

package provide "visit" 0.0

namespace eval "visit" {

  ######################################################################

  variable idleha    [astrometry::parseha    [config::getvalue "target" "idleha"   ]]
  variable idledelta [astrometry::parsedelta [config::getvalue "target" "idledelta"]]

  ######################################################################

  proc ha {visit {seconds now}} {
    return [getcoordinatevalue "ha" $visit $seconds]
  }
    
  proc alpha {visit {seconds now}} {
    return [getcoordinatevalue "alpha" $visit $seconds]
  }
    
  proc delta {visit {seconds now}} {
    return [getcoordinatevalue "delta" $visit $seconds]
  }

  proc equinox {visit {seconds now}} {
    return [getcoordinatevalue "equinox" $visit $seconds]
  }
  
  proc epoch {visit {seconds now}} {
    return [getcoordinatevalue "epoch" $visit $seconds]
  }
    
  proc alpharate {visit {seconds now}} {
    return [getcoordinatevalue "alpharate" $visit $seconds]
  }
    
  proc deltarate {visit {seconds now}} {
    return [getcoordinatevalue "deltarate" $visit $seconds]
  }
    
  proc observedha {visit {seconds now}} {
    return [getcoordinatevalue "observedha" $visit $seconds]
  }

  proc observedalpha {visit {seconds now}} {
    return [getcoordinatevalue "observedalpha" $visit $seconds]
  }
  
  proc observeddelta {visit {seconds now}} {
    return [getcoordinatevalue "observeddelta" $visit $seconds]
  }

  ######################################################################
  
  proc getcoordinatevalue {key visit seconds} {
    
    if {[catch {

      set type [dict get $visit "targetcoordinates" "type"]
      switch $type {

        "equatorial" {

          set ha        ""
          if {[dict exists $visit "targetcoordinates" "alpha"]} {
            set alpha   [dict get $visit "targetcoordinates" "alpha"]
          } else {
            set alpha   [astrometry::alpha [dict get $visit "targetcoordinates" "ha"] $seconds]
          }
          set delta     [dict get $visit "targetcoordinates" "delta"]
          if {[dict exists $visit "targetcoordinates" "equinox"]} {
            set equinox [dict get $visit "targetcoordinates" "equinox"]
          } else {
            set equinox "now"
          }
          set epoch     "now"
          set alpharate 0
          set deltarate 0
          set tracking  true

        }

        "fixed" {
        
          if {[dict exists $visit "targetcoordinates" "ha"]} {
            set ha        [dict get $visit "targetcoordinates" "ha"]
            set delta     [dict get $visit "targetcoordinates" "delta"]
          } else {
            set azimuth        [dict get $visit "targetcoordinates" "azimuth"       ]
            set zenithdistance [dict get $visit "targetcoordinates" "zenithdistance"]
            set ha    [astrometry::horizontaltoha    $azimuth $zenithdistance]
            set delta [astrometry::horizontaltodelta $azimuth $zenithdistance]
          }

          set alpha     ""
          set equinox   "now"
          set epoch     "now"
          set alpharate 0
          set deltarate 0
          set tracking  false

        }
    
        "zenith" {

          set ha        0
          set alpha     ""
          set delta     [astrometry::latitude]
          set equinox   "now"
          set epoch     "now"
          set alpharate 0
          set deltarate 0
          set tracking  false

        }

        "idle" {
        
          variable idleha
          variable idledelta

          set ha        $idleha
          set alpha     ""
          set delta     $idledelta
          set equinox   "now"
          set epoch     "now"
          set alpharate 0
          set deltarate 0
          set tracking  false

        }

        "solarsystembody" {

          set type "equatorial"

          set number [dict get $visit "targetcoordinates" "number"]
        
          log::debug "target is solar system body $number."
          set command "solarsystembodycoordinates $number [utcclock::jd $seconds]"
          log::debug "running command \"$command\"."
          set channel [open "|[directories::bin]/tcs $command" "r"]
          set args [gets $channel]
          close $channel
          log::debug "result was \"$args\"."

          set ha        ""
          set alpha     [lindex $args 0]
          set delta     [lindex $args 1]
          set equinox   [lindex $args 2]
          set epoch     "now"
          set alpharate [lindex $args 3]
          set deltarate [lindex $args 4]
          set tracking  true
          
        }

        "wind" {
        
          while {[catch {client::update "weather"}]} {
            log::warning "unable to determine the wind azimuth."
            coroutine::yield
          }
          set azimuth [client::getdata "weather" "windaverageazimuth"]

          set zenithdistance "30d"
          set ha    [astrometry::horizontaltoha    $azimuth $zenithdistance]
          set delta [astrometry::horizontaltodelta $azimuth $zenithdistance]

          set alpha     ""
          set equinox   "now"
          set epoch     "now"
          set alpharate 0
          set deltarate 0
          set tracking  false

        }

        default {
          error "invalid target coordinates type \"$type\"."
        }

      }
      
      if {$tracking} {
        
        switch $key {
          "alpha" {
            set value [astrometry::parsealpha $alpha]
          }
          "delta" {
            set value [astrometry::parsedelta $delta]
          }  
          "equinox" {
            set value [astrometry::parseequinox $equinox]
          }
          "epoch" {
            set value [astrometry::parseepoch $epoch]
          }  
          "alpharate" {
            set value [astrometry::parserate $alpharate]
          }  
          "deltarate" {
            set value [astrometry::parserate $deltarate]
          }  
          "observedalpha" {
            set value [astrometry::observedalpha $alpha $delta $equinox $seconds] 
          }
          "observeddelta" {
            set value [astrometry::observeddelta $alpha $delta $equinox $seconds] 
          }
          "observedha" {
            set observedalpha [astrometry::observedalpha $alpha $delta $equinox $seconds] 
            set value [astrometry::ha $observedalpha $seconds]
          }  
          default {
            error "invalid key argument \"$key\" for target coordinates type \"$type\"."
          }
        }

      } else {
      
        switch $key {
          "observedalpha" {
            set value [astrometry::alpha [astrometry::parseha $ha] $seconds]
          }
          "observeddelta" {
            set value [astrometry::parsedelta $delta]
          }
          "observedha" {
            set value [astrometry::parseha $ha]
          }  
          default {
            error "invalid key argument \"$key\" for target coordinates type \"$type\"."
          }
        }
      }

    } message]} {
      error "invalid visit target coordinates: $message"
    }

    return $value

  }
  
  ######################################################################

  proc identifier {visit} {
    if {![dict exists $visit "identifier"]} {
      error "invalid visit: missing identifier."
    }
    set identifier [dict get $visit "identifier"]
    if {[scan $identifier "%d" value] != 1} {
      error "invalid visit: invalid identifier \"$identifier\"."
    }
    return $value
  }
  
  proc name {visit} {
    if {![dict exists $visit "name"]} {
      return ""
    }
    return [dict get $visit "name"]
  }
  
  proc targetcoordinates {visit} {
    if {![dict exists $visit "targetcoordinates"]} {
      error "invalid visit: no visit target coordinates."
    }
    return [dict get $visit "targetcoordinates"]
  }
  
  proc estimatedduration {visit} {
    if {![dict exists $visit "estimatedduration"]} {
      error "invalid visit: no estimated duration."
    }
    set estimatedduration [dict get $visit "estimatedduration"]
    if {[catch {
      set estimatedduration [utcclock::scaninterval $estimatedduration]
    }]} {
      error "invalid visit: invalid estimated duration \"$estimatedduration\"."
    }
    return $estimatedduration
  }

  proc command {visit} {
    if {![dict exists $visit "command"]} {
      error "invalid visit: no visit command."
    }
    return [dict get $visit "command"]
  }
  
  proc tasks {visit} {
    if {![dict exists $visit "tasks"]} {
      return ""
    } else {
      return [dict get $visit "tasks"]
    }
  }

  ######################################################################
  
  proc makevisit {identifier name targetcoordinates command estimatedduration} {
    return [dict create \
      "identifier"        $identifier        \
      "name"              $name              \
      "targetcoordinates" $targetcoordinates \
      "command"           $command           \
      "estimatedduration" $estimatedduration \
    ]
  }
  
  proc makeequatorialtargetcoordinates {alpha delta equinox} {
    return [dict create \
      "type"    "equatorial" \
      "alpha"   $alpha       \
      "delta"   $delta       \
      "equinox" $equinox     \
    ]
  }
  
  proc updatevisittargetcoordinates {oldvisit targetcoordinates} {
    return [makevisit \
      [visit::identifier        $oldvisit] \
      [visit::name              $oldvisit] \
      $targetcoordinates \
      [visit::command           $oldvisit] \
      [visit::estimatedduration $oldvisit] \
    ]
  }

  proc updatevisitidentifier {oldvisit identifier} {
    return [makevisit \
      $identifier \
      [visit::name              $oldvisit] \
      [visit::targetcoordinates $oldvisit] \
      [visit::command           $oldvisit] \
      [visit::estimatedduration $oldvisit] \
    ]
  }

  ######################################################################
}
