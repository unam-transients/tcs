########################################################################

# This file is part of the UNAM telescope control system.

# $Id: astrometry.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2013, 2014, 2015, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "config"
package require "client"
package require "coroutine"
package require "utcclock"

package provide "astrometry" 0.0

load [file join [directories::prefix] "lib" "astrometry.so"]

namespace eval "astrometry" {

  variable svnid {$Id}

  ######################################################################

  variable pi [expr {4.0 * atan(1.0)}]

  proc pi {} {
    variable pi
    return $pi
  }

  ######################################################################

  proc fold {x min max} {
    while {$x >= $max} {
      set x [expr {$x - ($max - $min)}]
    }
    while {$x < $min} {
      set x [expr {$x + ($max - $min)}]
    }
    # Deal with possible rounding error.
    if {$x >= $max} {
      set x $min
    }
    return $x
  }

  proc foldradpositive {x} {
    variable pi
    fold $x 0 [expr {2 * $pi}]
  }

  proc foldradsymmetric {x} {
    variable pi
    fold $x [expr {-$pi}] $pi
  }

  ######################################################################
  
  proc unitvector {x y z} {
    set n [expr {sqrt($x * $x + $y * $y + $z * $z)}]
    set x [expr {$x / $n}]
    set y [expr {$y / $n}]
    set z [expr {$z / $n}]
    return [list $x $y $z]
  }
  
  proc vectorx {v} {
    return [lindex $v 0]
  }

  proc vectory {v} {
    return [lindex $v 1]
  }

  proc vectorz {v} {
    return [lindex $v 2]
  }

  proc alphadeltatovector {alpha delta} {
    set x [expr {cos($delta) * cos($alpha)}]
    set y [expr {cos($delta) * sin($alpha)}]
    set z [expr {sin($delta)}]
    return [unitvector $x $y $z]
  }
  
  proc vectortoalpha {v} {
    set x [vectorx $v]
    set y [vectory $v]
    set z [vectorz $v]
    set alpha [foldradpositive [expr {atan2($y,$x)}]]
    return $alpha
  }
  
  proc vectortodelta {v} {
    set x [vectorx $v]
    set y [vectory $v]
    set z [vectorz $v]
    set delta [expr {asin($z)}]
    return $delta
  }
  
  proc meanalpha {alphalist deltalist} {
    set x 0
    set y 0
    set z 0
    foreach alpha $alphalist delta $deltalist {
      set v [alphadeltatovector $alpha $delta]
      set x [expr {$x + [vectorx $v]}]
      set y [expr {$y + [vectory $v]}]
      set z [expr {$z + [vectorz $v]}]
    }
    set v [unitvector $x $y $z]
    return [vectortoalpha $v]
  }
  
  proc meandelta {alphalist deltalist} {
    set x 0
    set y 0
    set z 0
    foreach alpha $alphalist delta $deltalist {
      set v [alphadeltatovector $alpha $delta]
      set x [expr {$x + [vectorx $v]}]
      set y [expr {$y + [vectory $v]}]
      set z [expr {$z + [vectorz $v]}]
    }
    set v [unitvector $x $y $z]
    return [vectortodelta $v]
  }
  
  ######################################################################

  proc degtorad {deg} {
    variable pi
    expr {$pi * ($deg / 180.0)}
  }

  proc radtodeg {rad} {
    variable pi
    expr {180.0 * ($rad / $pi)}
  }

  proc hrtorad {hr} {
    variable pi
    expr {$pi * ($hr / 12.0)}
  }

  proc radtohr {rad} {
    variable pi
    expr {12.0 * ($rad / $pi)}
  }
  
  proc hrtodeg {hr} {
    expr {$hr * 15.0}
  }
  
  proc degtohr {deg} {
    expr {$deg / 15.0}
  }

  proc arcmintorad {arcmin} {
    variable pi
    expr {$pi * ($arcmin / (180.0 * 60.0))}   
  }

  proc radtoarcmin {rad} {
    variable pi
    expr {180.0 * 60.0 * ($rad / $pi)}
  }
  
  proc arcsectorad {arcsec} {
    variable pi
    expr {$pi * ($arcsec / (180.0 * 60.0 * 60.0))}
  }

  proc radtoarcsec {rad} {
    variable pi
    expr {180.0 * 60.0 * 60.0 * ($rad / $pi)}
  }
  
  ######################################################################

  proc parseangle {angle {sexagesimalformat none}} {
    if {[string is double -strict $angle]} {
      set newangle $angle
    } elseif {[scan $angle "%f%\[adhmrs°\"\'\]" value unit] == 2} {
      switch -nocase $unit {
        "r" {
          set newangle $value
        }
        "d" -
        "ad" -
        "°" {
          set newangle [degtorad $value]
        }
        "am" -
        "\'" {
          set newangle [arcmintorad $value]
        }
        "as" -
        "\"" {
          set newangle [arcsectorad $value]
        }
        "h" {
          set newangle [hrtorad $value]
        }
        "m" {
          set newangle [expr {[hrtorad $value] / 60.0}]
        }
        "s" {
          set newangle [expr {[hrtorad $value] / 60.0 / 60.0}]
        }
        default {
          error "invalid angle: \"$angle\"."
        }
      }
    } elseif {[string equal $sexagesimalformat "hms"]} {
      set newangle [hmstorad $angle]
    } elseif {[string equal $sexagesimalformat "dms"]} {
      set newangle [dmstorad $angle]
    } else {
      error "invalid angle: \"$angle\"."
    }
    return $newangle
  }
  
  proc parsealpha {alpha} {
    variable pi
    if {
        [catch {parseangle $alpha hms} newalpha] ||
        $newalpha < 0 ||
        $newalpha >= 2 * $pi
    } {
      error "invalid alpha: \"$alpha\"."
    }
    return $newalpha
  }

  proc parsedelta {delta} {
    variable pi
    if {
        [catch {parseangle $delta dms} newdelta] ||
        $newdelta < -0.5 * $pi ||
        $newdelta > 0.5 * $pi
    } {
      error "invalid delta: \"$delta\"."
    }
    return $newdelta
  }

  proc parseha {ha} {
    variable pi
    if {
        [catch {parseangle $ha hms} newha] ||
        $newha < -$pi ||
        $newha > $pi
      } {
      error "invalid ha: \"$ha\"."
    }
    return $newha
  }

  proc parseequinox {equinox} {
    if {[string is double -strict $equinox]} {
      set newequinox $equinox
    } elseif {[string equal $equinox "now"]} {
      set newequinox [utcclock::epoch "now"]
    } else {
      error "invalid equinox: \"$equinox\"."
    }
    return $newequinox
  }

  proc parseepoch {epoch} {
    if {[string equal $epoch "now"]} {
      set newepoch "$epoch"
    } elseif {![catch {utcclock::scan $epoch}]} {
      set newepoch [utcclock::combinedformat [utcclock::scan $epoch]]
    } else {
      error "invalid epoch: \"$epoch\"."
    }
    return $newepoch
  }
  
  proc parserate {rate} {
    if {
      [catch {parseangle $rate "dms"} newrate]
    } {
      error "invalid rate: \"$rate\"."
    }
    return $newrate
  }

  proc parseoffset {offset} {
    if {
      [catch {parseangle $offset "dms"} newoffset]
    } {
      error "invalid offset: \"$offset\"."
    }
    return $newoffset
  }

  proc parsedistance {distance} {
    if {
      [catch {parseangle $distance "dms"} newdistance] ||
      $newdistance < 0
    } {
      error "invalid distance: \"$distance\"."
    }
    return $newdistance
  }

  ######################################################################

  proc sexagesimaltodouble {sexagesimal strict} {
    if {[scan $sexagesimal "%d%*\[^0-9\]%d%*\[^0-9\]%f" d0 d1 d2] != 3} {
      error "invalid sexagesimal angle: \"$sexagesimal\"."      
    }
    if {$strict && ($d1 < 0 || $d1 >= 60 || $d2 < 0 || $d2 >= 60)} {
      error "invalid sexagesimal angle: \"$sexagesimal\"."
    }
    set d [expr {($d2 / 60.0 + $d1) / 60.0 + abs($d0)}]
    scan $sexagesimal "%1s" sign
    if {[string equal $sign "-"]} {
      set d [expr {-$d}]
    }
    return $d
  }

  proc dmstodeg {dms {strict true}} {
    return [sexagesimaltodouble $dms $strict]
  }

  proc dmstorad {dms {strict true}} {
    return [degtorad [sexagesimaltodouble $dms $strict]]
  }

  proc hmstodeg {hms {strict true}} {
    return [hrtodeg [sexagesimaltodouble $hms $strict]]
  }

  proc hmstorad {hms {strict true}} {
    return [hrtorad [sexagesimaltodouble $hms $strict]]
  }

  ######################################################################

  proc doubletosexagesimal {d precision min max withsign {separator ":"}} {
    set d [fold $d $min $max]
    set d0 [expr {abs($d)}]
    set i0 [expr {int($d0)}]
    set d1 [expr {($d0 - $i0) * 60.0}]
    set i1 [expr {int($d1)}]
    set d2 [expr {($d1 - $i1) * 60.0}]
    set i2 [expr {int(floor($d2))}]
    set f2 [expr {$d2 - $i2}]
    set fscale  [expr {pow(10,$precision)}]
    set fdigits [expr {int(round($f2 * $fscale))}]
    if {$fdigits == $fscale} {
      set i2 [expr {$i2 + 1}]
      set fdigits 0
    }
    if {$i2 == 60} {
      set i1 [expr {$i1 + 1}]
      set i2 0
    }
    if {$i1 == 60} {
      set i0 [expr {$i0 + 1}]
      set i1 0
    }
    if {$d >= 0} {
      if {$i0 < $min} {
        set i0 [expr {abs($i0 + ($max - $min))}]
        set d  [expr {$d  + ($max - $min)}]
      } elseif {$i0 > $max || (!$withsign && $i0 == $max)} {
        set i0 [expr {abs($i0 - ($max - $min))}]
        set d  [expr {$d  - ($max - $min)}]
      }
    } else {
      if {-$i0 < $min} {
        set i0 [expr {abs($i0 - ($max - $min))}]
        set d  [expr {$d  + ($max - $min)}]
      } elseif {-$i0 > $max || (!$withsign && $i0 == $max)} {
        set i0 [expr {abs($i0 + ($max - $min))}]
        set d  [expr {$d  - ($max - $min)}]
      }
    }
    if {$min < 0 && $d < 0} {
      set sign "-"
    } elseif {$withsign} {
      set sign "+"
    } else {
      set sign ""
    }
    if {$precision == 0} {
      set ftext ""
    } else {
      set ftext [format ".%0*d" $precision $fdigits]
    }
    format "%s%02d%s%02d%s%02d%s" $sign $i0 $separator $i1 $separator $i2 $ftext
  }

  proc degtodms {deg precision withsign {separator ":"}} {
    if {$withsign} {
      doubletosexagesimal $deg $precision -180 +180 $withsign $separator
    } else {
      doubletosexagesimal $deg $precision    0 +360 $withsign $separator
    }
  }

  proc radtodms {rad precision withsign {separator ":"}} {
    set deg [radtodeg $rad]
    if {$withsign} {
      doubletosexagesimal $deg $precision -180 +180 $withsign $separator
    } else {
      doubletosexagesimal $deg $precision    0 +360 $withsign $separator
    }
  }

  proc degtohms {deg precision withsign {separator ":"}} {
    set hr [degtohr $deg]
    if {$withsign} {
      doubletosexagesimal $hr $precision -12 +12 $withsign $separator
    } else {
      doubletosexagesimal $hr $precision   0 +24 $withsign $separator
    }
  }

  proc radtohms {rad precision withsign {separator ":"}} {
    set hr [radtohr $rad]
    if {$withsign} {
      doubletosexagesimal $hr $precision -12 +12 $withsign $separator
    } else {
      doubletosexagesimal $hr $precision   0 +24 $withsign $separator
    }
  }

  ######################################################################
  
  proc formatalpha {alpha {precision 2}} {
    set alpha [parsealpha $alpha]
    return [radtohms $alpha $precision false]
  }
  
  proc formatdelta {delta {precision 1}} {
    set delta [parsedelta $delta]
    return [radtodms $delta $precision true]
  }
  
  proc formatha {ha {precision 2}} {
    set ha [parseha $ha]
    return [radtohms $ha $precision true]
  }
  
  proc formatrate {rate {precision 5}} {
    set rate [parserate $rate]
    if {$rate == 0} {
      return "0"
    } else {
      return [format "%+.${precision}fas" [radtoarcsec $rate]]
    }
  }
  
  proc formatoffset {offset {precision 1}} {
    set offset [parseoffset $offset]
    set distance [expr {abs($offset)}]
    if {$offset == 0} {
      return "0"
    } elseif {$offset < 0} {
      return "-[formatdistance $distance $precision]"
    } else {
      return "+[formatdistance $distance $precision]"
    }  
  }
  
  proc formatdistance {distance {precision 1}} {
    set distance [parsedistance $distance]
    if {$distance == 0} {
      return "0"
    } elseif {abs($distance) <= [parseangle "1am"]} {
      return [format "%.${precision}fas" [radtoarcsec $distance]]
    } elseif {abs($distance) <= [parseangle "1d"]} {
      return [format "%.${precision}fam" [radtoarcmin $distance]]
    } else {
      return [format "%.${precision}fd" [radtodeg $distance]]
    }  
  }
  
  ######################################################################
  
  proc equatorialtoazimuth {ha delta} {
    set ha    [parseha $ha]
    set delta [parsedelta $delta]
    variable pi
    variable latitude
    set y [expr {cos($delta) * sin($ha)}]
    set x [expr {sin($latitude) * cos($delta) * cos($ha) - cos($latitude) * sin($delta)}]
    set azimuth [expr {atan2($y, $x)}]
    set azimuth [foldradpositive $azimuth]
    return $azimuth
  }
  
  proc equatorialtozenithdistance {ha delta} {
    set ha    [parseha $ha]
    set delta [parsedelta $delta]
    variable latitude
    set zenithdistance [expr {acos(sin($latitude) * sin($delta) + cos($latitude) * cos($delta) * cos($ha))}]
    set zenithdistance [foldradpositive $zenithdistance]
    return $zenithdistance
  }

  proc airmass {z} {
    set z [parseangle $z]
    # Adapted from the SLALIB sla_AIRMAS function.
    set seczm1 [expr {1 / (cos(min(1.52,abs($z)))) - 1}]
    expr {1 + $seczm1*(0.9981833 - $seczm1*(0.002875 + 0.0008083*$seczm1))}
  }
  
  proc parallacticangle {ha delta} {
    set ha    [parseha $ha]
    set delta [parsedelta $delta]
    variable latitude
    expr {atan2(sin($ha), cos($delta) * tan($latitude) - sin($delta) * cos($ha))}
  }

  ######################################################################
  
  proc distance {alpha0 delta0 alpha1 delta1} {
    set alpha0 [parsealpha $alpha0]
    set alpha1 [parsealpha $alpha1]
    set delta0 [parsedelta $delta0]
    set delta1 [parsedelta $delta1]
    set cosd [expr {sin($delta0) * sin($delta1) + cos($delta0) * cos($delta1) * cos($alpha0 - $alpha1)}]
    if {$cosd < 0.99999} {
      return [expr {acos($cosd)}]
    } else {
      set delta [expr {($delta0 + $delta1) / 2}]
      set dx [expr {($alpha0 - $alpha1) * cos($delta)}]
      set dy [expr {$delta0 - $delta1}]
      return [expr {sqrt($dx * $dx + $dy * $dy)}]
    }
  }
  
  ######################################################################

  proc last {{seconds "now"}} {
    set gast [rawgast [utcclock::mjd $seconds]]
    variable longitude
    return [foldradpositive [expr {$gast + $longitude}]]
  }
  
  proc ha {alpha {seconds "now"}} {
    set alpha [parsealpha $alpha]
    return [foldradsymmetric [expr {[last $seconds] - $alpha}]]
  }
  
  proc alpha {ha {seconds "now"}} {
    set ha [parseha $ha]
    return [foldradpositive [expr {[last $seconds] - $ha}]]
  }

  ######################################################################

  variable temperature 5
  variable pressure    733
  variable humidity    0.5
  
  variable updatingweatherdata false
  
  proc updateweatherdata {} {
    log::debug "updateweatherdata: start."
    if {[catch {client::update "weather"} message]} {
      log::debug "updateweatherdata: $message"
    }
    log::debug "updateweatherdata: end."
    
  }

  proc getweatherdata {} {
    
    variable updatingweatherdata
    if {!$updatingweatherdata} {
      astrometry::updateweatherdata
      coroutine::every 30000 astrometry::updateweatherdata
      set updatingweatherdata true
    }

    variable temperature
    variable pressure
    variable humidity

    if {[catch {
      set newtemperature [client::getdata "weather" "temperature"]
      set newhumidity    [client::getdata "weather" "humidity"]
      set newpressure    [client::getdata "weather" "pressure"]
    }]} {
      log::debug "astrometry::getweatherdata: unable to determine the weather data."
    } else {
      set temperature $newtemperature
      set humidity    $newhumidity
      if {![string equal $newpressure "unknown"]} {
        set pressure $newpressure
      }
    }

  }

  proc observedalpha {alpha delta equinox {seconds "now"}} {
    set alpha   [parsealpha $alpha]
    set delta   [parsedelta $delta]
    set equinox [parseequinox $equinox]
    variable longitude
    variable latitude
    variable altitude
    variable temperature
    variable pressure
    variable humidity
    getweatherdata
    rawobservedalpha \
      $alpha $delta $equinox \
      [utcclock::mjd $seconds] \
      $longitude $latitude $altitude \
      [expr {$temperature + 273.15}] $pressure $humidity 0.55
  }

  proc observeddelta {alpha delta equinox {seconds "now"}} {
    set alpha   [parsealpha $alpha]
    set delta   [parsedelta $delta]
    set equinox [parseequinox $equinox]
    variable longitude
    variable latitude
    variable altitude
    variable temperature
    variable pressure
    variable humidity
    getweatherdata
    rawobserveddelta \
      $alpha $delta $equinox \
      [utcclock::mjd $seconds] \
      $longitude $latitude $altitude \
      [expr {$temperature + 273.15}] $pressure $humidity 0.55
  }
  
  proc nextobservedtransitseconds {alpha delta equinox {seconds "now"}} {
    set seconds [utcclock::scan [utcclock::format $seconds]]
    # Bracket the next observed transit in [minseconds,maxseconds).
    set minseconds $seconds
    set maxseconds [expr {$minseconds + 3600}]
    while {
      [ha [observedalpha $alpha $delta $equinox $minseconds] $minseconds] > 0 ||
      [ha [observedalpha $alpha $delta $equinox $maxseconds] $maxseconds] <= 0
    } {
      set minseconds $maxseconds
      set maxseconds [expr {$minseconds + 3600}]
    }
    # Now use bisection, maintaining the transit in [minseconds,maxseconds). 
    while {$maxseconds - $minseconds > 0.001} {
      set midseconds [expr {0.5 * ($minseconds + $maxseconds)}]
      if {[ha [observedalpha $alpha $delta $equinox $midseconds] $midseconds] <= 0} {
        set minseconds $midseconds
      } else {
        set maxseconds $midseconds
      }
    }
    return [expr {0.5 * ($minseconds + $maxseconds)}]
  }

  ######################################################################

  proc precessedalpha {alpha delta startequinox endequinox} {
    set alpha [parsealpha $alpha]
    set delta [parsedelta $delta]
    set startequinox [parseequinox $startequinox]
    set endequinox   [parseequinox $endequinox]
    rawprecessedalpha $alpha $delta $startequinox $endequinox
  }

  proc precesseddelta {alpha delta startequinox endequinox} {
    set alpha [parsealpha $alpha]
    set delta [parsedelta $delta]
    set startequinox [parseequinox $startequinox]
    set endequinox   [parseequinox $endequinox]
    rawprecesseddelta $alpha $delta $startequinox $endequinox
  }

  ######################################################################  
  
  proc bodyapparentalpha {body {seconds "now"}} {
    variable longitude
    variable latitude
    return [
      rawbodyapparentalpha \
        $body \
        [utcclock::mjd $seconds] \
        $longitude $latitude \
    ]
  }
  
  proc bodyapparentdelta {body {seconds "now"}} {
    variable longitude
    variable latitude
    return [
      rawbodyapparentdelta \
        $body \
        [utcclock::mjd $seconds] \
        $longitude $latitude \
    ]
  }
  
  proc moonapparentalpha {{seconds "now"}} {
    return [bodyapparentalpha 3 $seconds]
  }
  
  proc moonapparentdelta {{seconds "now"}} {
    return [bodyapparentdelta 3 $seconds]
  }
  
  proc sunapparentalpha {{seconds "now"}} {
    return [bodyapparentalpha 0 $seconds]
  }
  
  proc sunapparentdelta {{seconds "now"}} {
    return [bodyapparentdelta 0 $seconds]
  }
  
  ######################################################################  
  
  proc bodyobservedalpha {body {seconds "now"}} {
    variable longitude
    variable latitude
    variable altitude
    variable temperature
    variable pressure
    variable humidity
    getweatherdata
    return [
      rawbodyobservedalpha \
        $body \
        [utcclock::mjd $seconds] \
        $longitude $latitude $altitude \
        [expr {$temperature + 273.15}] $pressure $humidity 0.55 \
    ]
  }
  
  proc bodyobserveddelta {body {seconds "now"}} {
    variable longitude
    variable latitude
    variable altitude
    variable temperature
    variable pressure
    variable humidity
    getweatherdata
    return [
      rawbodyobserveddelta \
        $body \
        [utcclock::mjd $seconds] \
        $longitude $latitude $altitude \
        [expr {$temperature + 273.15}] $pressure $humidity 0.55 \
    ]
  }
  
  proc moonobservedalpha {{seconds "now"}} {
    return [bodyobservedalpha 3 $seconds]
  }
  
  proc moonobserveddelta {{seconds "now"}} {
    return [bodyobserveddelta 3 $seconds]
  }
  
  proc moonskystate {{seconds "now"}} {

    variable horizonzenithdistance

    set observedalpha [moonobservedalpha $seconds]
    set observeddelta [moonobserveddelta $seconds]
    set observedha    [ha $observedalpha $seconds]
    set observedzenithdistance [equatorialtozenithdistance $observedha $observeddelta]
    set observedaltitude [expr {[horizonzenithdistance] - $observedzenithdistance}]

    set illuminatedfraction [moonilluminatedfraction $seconds]
    
    # The mean angular diameter varies between 15 and 17 am, according to 
    # http://aa.usno.navy.mil/faq/docs/RST_defs.php, so we use 16 am.
    if {$observedaltitude < [parseangle "-16am"]} {
      set skystate "dark"
    } elseif {$illuminatedfraction <= 0.50} {
      set skystate "grey"
    } else {
      set skystate "bright"
    }

    return $skystate
  }
  
  proc sunobservedalpha {{seconds "now"}} {
    return [bodyobservedalpha 0 $seconds]
  }
  
  proc sunobserveddelta {{seconds "now"}} {
    return [bodyobserveddelta 0 $seconds]
  }
  
  # Definitions from http://aa.usno.navy.mil/faq/docs/RST_defs.php
  variable daylightminaltitude [parseangle "-16am"]
  variable civiltwilightminaltitude [parseangle "-6d"]
  variable nauticaltwilightminaltitude [parseangle "-12d"]
  variable astronomicaltwilightminaltitude [parseangle "-18d"]
  
  proc sunskystate {{seconds "now"}} {
    
    variable horizonzenithdistance

    set observedalpha [sunobservedalpha $seconds]
    set observeddelta [sunobserveddelta $seconds]
    set observedha    [ha $observedalpha $seconds]
    set observedzenithdistance [equatorialtozenithdistance $observedha $observeddelta]
    set observedaltitude [expr {[horizonzenithdistance] - $observedzenithdistance}]

    variable daylightminaltitude
    variable civiltwilightminaltitude
    variable nauticaltwilightminaltitude
    variable astronomicaltwilightminaltitude

    if {$observedaltitude >= $daylightminaltitude} {
      set skystate "daylight"
    } elseif {$observedaltitude >= $civiltwilightminaltitude} {
      set skystate "civiltwilight"
    } elseif {$observedaltitude >= $nauticaltwilightminaltitude} {
      set skystate "nauticaltwilight"
    } elseif {$observedaltitude >= $astronomicaltwilightminaltitude} {
      set skystate "astronomicaltwilight"
    } else {
      set skystate "night"
    }
    
    return $skystate
  }
  
  proc nextsunskystateseconds {skystate {seconds "now"}} {
    log::debug "nextsunskystateseconds: determining next skystate."
    log::debug "nextsunskystateseconds: skystate is $skystate."
    set start [utcclock::seconds]
    set i 0
    if {[string equal $seconds "now"]} {
      set seconds [utcclock::seconds]
    }
    log::debug "nextsunskystateseconds: seconds $seconds."
    set seconds [expr {ceil($seconds)}]
    incr i
    if {![string equal $skystate [sunskystate $seconds]]} {
      # We rely on each sky state lasting for at least step seconds. In
      # the tropics, the Sun moves 6 degrees in zenith distance in about
      # 1440 seconds or less, so step should be 1024.
      set step 1024
      # Search linearly for the sky state.
      while {true} {
        set seconds [expr {$seconds + $step}]
        incr i
        if {[string equal $skystate [sunskystate $seconds]]} {
          break
        }
      }
      # Refine the boundary using bisection.
      set minseconds [expr {$seconds - $step}]
      set maxseconds $seconds
      while {$maxseconds - $minseconds > 1} {
        set seconds [expr {0.5 * ($minseconds + $maxseconds)}]
        incr i
        if {[string equal $skystate [sunskystate $seconds]]} {
          set maxseconds $seconds
        } else {
          set minseconds $seconds
        }
      }
      set seconds $maxseconds
    }
    set end [utcclock::seconds]
    log::debug "nextsunskystateseconds: $i calls to sunskystate."
    log::debug [format "nextsunskystateseconds: finished determining next skystate after %.1f seconds." [expr {$end - $start}]]
    return $seconds
  }
  
  ######################################################################  

  proc moonilluminatedfraction {{seconds "now"}} {
    # See Meeus, "Astronomical Algorithms", pp. 316-317. We use the
    # approximation that the cosine of the selenocentric elongation of
    # the Earth is approximately the negative cosine of the apparent
    # topocentric elongation of the Moon.
    set moonalpha [moonapparentalpha $seconds]
    set moondelta [moonapparentdelta $seconds]
    set sunalpha  [sunapparentalpha  $seconds]
    set sundelta  [sunapparentdelta  $seconds]
    set elongation [distance $moonalpha $moondelta $sunalpha $sundelta]
    set illuminatedfraction [expr {(1 - cos($elongation)) / 2}]
    return $illuminatedfraction
  }
  
  ######################################################################  

  variable longitude [astrometry::parseangle [config::getvalue "site" "longitude"] "dms"]
  variable latitude  [astrometry::parseangle [config::getvalue "site" "latitude"]  "dms"]
  variable altitude  [config::getvalue "site" "altitude"]
  
  variable horizonzenithdistance
  # We assume the horizon is at sea level.
  # Horizon distance formula from http://en.wikipedia.org/wiki/Horizon
  set horizondistance [expr {3.856 * sqrt($altitude)}]
  set earthradius 6378
  set horizonzenithdistance [expr {$pi / 2 + atan($horizondistance/$earthradius)}]

  proc longitude {} {
    variable longitude
    return $longitude
  }
  
  proc latitude {} {
    variable latitude
    return $latitude
  }
  
  proc altitude {} {
    variable altitude
    return $altitude
  }
  
  proc horizonzenithdistance {} {
    variable horizonzenithdistance
    return $horizonzenithdistance
  }
  
  ######################################################################
  
  # Default values in case we can't get these from the weather server.

  # Pressure from https://www.engineeringtoolbox.com/air-altitude-pressure-d_462.html

  variable temperature 5
  variable pressure    [expr {760.0 * pow(1 - 2.25577e-5 * $altitude, 5.25588)}]
  variable humidity    0.5
  
  ######################################################################

}
