########################################################################

# This file is part of the UNAM telescope control system.

# $Id: html.tcl 3615 2020-06-22 19:37:40Z Alan $

########################################################################

# Copyright © 2014, 2015, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "config"
package require "log"
package require "client"
package require "utcclock"
package require "server"

package provide "html" 0.0

namespace eval "html" {

  variable svnid {$Id}

  ######################################################################
  
  variable servers [concat \
    { "html" } \
    [config::getvalue "html" "servers"] \
    [config::getvalue "instrument" "detectors"] \
  ]
  variable sensors                   [config::getvalue "sensors" "sensors"]
  variable powerhosts                [config::getvalue "power" "hosts"]
  variable poweroutletgroupaddresses [config::getvalue "power" "outletgroupaddresses"]
  variable civiltimezone             [config::getvalue "site" "civiltimezone"]
  
  ######################################################################
  
  variable wwwdirectory "[directories::prefix]/var/www/tcs"
  
  ######################################################################
  
  variable lastserverstatus {}
  
  ######################################################################
  
  variable htmlchannel

  proc openhtml {filename} {
    variable htmlchannel
    file mkdir [file dirname $filename]
    set htmlchannel [open "$filename" "w"]
    chan configure $htmlchannel -translation "crlf"
    chan configure $htmlchannel -encoding "utf-8"
  }
  
  proc closehtml {} {
    variable htmlchannel
    close $htmlchannel
  }
  
  proc putshtml {text} {
    variable htmlchannel
    puts $htmlchannel $text
  }
  
  proc putshtmlnonewline {text} {
    variable htmlchannel
    puts -nonewline $htmlchannel $text
  }
  
  ######################################################################

  proc formattimestamp {timestamp} {
    if {[catch {
      utcclock::format [utcclock::scan $timestamp]
    } result]} {
      return $timestamp
    } else {
      return $result
    }
  }

  proc formatifok {formatstring value} {
    if {[catch {
      format $formatstring $value
    } result]} {
      return $value
    } else {
      return $result
    }
  }
  
  proc formatpercentifok {formatstring value} {
    if {[catch {
      format $formatstring [expr {$value * 100}]
    } result]} {
      return $value
    } else {
      return $result
    }
  }

  proc formathaifdouble {ha {precision 2}} {
    if {[string is double -strict $ha]} {
      return [astrometry::radtohms $ha $precision true]
    } else {
      return $ha
    }
  }

  proc formatalphaifdouble {alpha {precision 2}} {
    if {[string is double -strict $alpha]} {
      return [astrometry::radtohms $alpha $precision false]
    } else {
      return $alpha
    }
  }

  proc formatdeltaifdouble {delta {precision 1}} {
    if {[string is double -strict $delta]} {
      return [astrometry::radtodms $delta $precision true]
    } else {
      return $delta
    }
  }

  proc formatarcsecifdouble {format angle} {
    if {[string is double -strict $angle]} {
      return [format $format [astrometry::radtoarcsec $angle]]
    } else {
      return $angle
    }
  }

  proc formatrateifdouble {rate} {
        return [formatarcsecifdouble "%+.4fas/s" $rate]
  }

  proc formatoffsetifdouble {offset} {
    return [formatarcsecifdouble "%+.1fas" $offset]
  }

  proc formatguidererrorifdouble {error} {
    return [formatarcsecifdouble  "%+.2fas" $error]
  }

  proc formatradtodegifdouble {formatstring rad} {
    if {[catch {
      format $formatstring [astrometry::radtodeg $rad]
    } result]} {
      return $rad
    } else {
      return $result
    }
  }

  proc formatdifferenceifdouble {formatstring x y} {
    if {[catch {expr {$x - $y}} difference]} {
      return ""
    } else {
      format $formatstring $difference
    }
  }
  
  proc entify {text} {
    set text [string map {
      "&" "&amp;"
      "<" "&lt;"
      ">" "&gt;"
      "\"" "&quot;"
      "α" "&alpha;"
      "δ" "&delta;"
      "°" "&deg;"
      "→" "&rarr;"
      "±" "&plusmn;"
      " -0" " &minus;0"
      " -1" " &minus;1"
      " -2" " &minus;2"
      " -3" " &minus;3"
      " -4" " &minus;4"
      " -5" " &minus;5"
      " -6" " &minus;6"
      " -7" " &minus;8"
      " -8" " &minus;0"
      " -9" " &minus;9"
    } $text]
    if {[string match "-\[0-9\]*" $text]} {
      set text "&minus;[string range $text 1 end]"
    } 
    return $text
  }

  proc writehtmlblankline {} {
    putshtml ""
  }

  proc writehtmlkey {text} {
    set text [entify $text]
    putshtmlnonewline "<td class=\"key\">$text:</td>"
  }

  proc writehtmlfield {colspan class text} {
    set text [entify $text]
    if {[string equal "" $class]} {
      putshtmlnonewline "<td colspan=\"$colspan\" class=\"field\">$text</td>"
    } else {
      putshtmlnonewline "<td colspan=\"$colspan\" class=\"field $class\">$text</td>"
    }
  }

  proc writehtmlfullrow {{key ""} {arg ""}} {
    putshtmlnonewline "<tr>"
    writehtmlkey $key
    writehtmlfield 3 "full" $arg
    putshtml "</tr>"
  }

  proc writehtmlfullrowwithemph {{key ""} {class ""} {arg ""}} {
    putshtmlnonewline "<tr>"
    writehtmlkey $key
    writehtmlfield 3 "full $class" $arg
    putshtml "</tr>"
  }

  proc writehtmltimestampedrowwithemph {{key ""} {timestamp ""} {class ""} {arg ""}} {
    writehtmlfullrowwithemph $key $class "[formattimestamp $timestamp] $arg"
  }

  proc writehtmltimestampedrow {{key ""} {timestamp ""} {arg ""}} {
    writehtmltimestampedrowwithemph $key $timestamp "" $arg
  }

  proc writehtmlrowwithemph {{key ""} {class0 ""} {arg0 ""} {class1 ""} {arg1 ""} {class2 ""} {arg2 ""}} {
    putshtmlnonewline "<tr>"
    writehtmlkey $key
    writehtmlfield 1 $class0 $arg0
    writehtmlfield 1 $class1 $arg1
    writehtmlfield 1 $class2 $arg2
    putshtml "</tr>"
  }

  proc writehtmlrow {{key ""} {arg0 ""} {arg1 ""} {arg2 ""}} {
    writehtmlrowwithemph $key "" $arg0 "" $arg1 "" $arg2
  }

  proc writehtmlstatusline {name server} {
    set status [client::getstatus $server]
    if {[string equal $status "ok"]} {
      set activity          [client::getdata $server "activity"         ]
      set requestedactivity [client::getdata $server "requestedactivity"]
      if {[string equal $activity "error"] && [string equal $requestedactivity "error"]} {
        writehtmlfullrowwithemph "$name" "error" "$activity"
      } elseif {[string equal $activity "error"]} {
        writehtmlfullrowwithemph "$name" "error" "$activity → $requestedactivity"
      } elseif {![string equal $activity $requestedactivity]} {
        writehtmlfullrow "$name" "$activity → $requestedactivity"
      } elseif {![string equal $activity "idle"]} {
        writehtmlfullrow "$name" "$activity"
      }
    } else {
      writehtmlfullrowwithemph "$name" "error" $status
    }
  }
  
  proc alarmemph {alarm} {
    if {$alarm} {
      return "warning"
    } else {
      return ""
    } 
  }

  ######################################################################

  proc writehtmlstatusblock {server} {
  
    writehtmltimestampedrow "Current time"  [utcclock::format]

    set statustimestamp [client::getstatustimestamp $server]
    set status          [client::getstatus $server]
    set starttimestamp  [client::getstarttimestamp $server]
    set pid             [client::getpid $server]
  
    if {[string equal $starttimestamp "unknown"]} {
      set starttimestamp ""
    }
    if {[string equal $pid "unknown"]} {
      set pid ""
    }

    switch $status {
      "unknown" -
      "stale" -
      "error" {
        set emph "error"
      }
      "starting" {
        set emph "warning"
      }
      default {
        set emph ""
      }
    }

    writehtmltimestampedrowwithemph "Status" \
      $statustimestamp \
      "$emph" $status
    writehtmltimestampedrow "Process" \
      $starttimestamp \
      $pid
  
    if {[string equal $status "ok"]} {
      set activity                   [client::getdata $server "activity"                  ]
      set activitytimestamp          [client::getdata $server "activitytimestamp"         ]
      set requestedactivity          [client::getdata $server "requestedactivity"         ]
      set requestedactivitytimestamp [client::getdata $server "requestedactivitytimestamp"]
      set timestamp                  [client::getdata $server "timestamp"                 ]
      if {[string equal $activity "error"]} {
        writehtmltimestampedrowwithemph "Requested activity" \
          $requestedactivitytimestamp \
          "warning" $requestedactivity
        writehtmltimestampedrowwithemph "Current activity" \
          $activitytimestamp \
          "error" $activity
      } elseif {![string equal $activity $requestedactivity]} {
        writehtmltimestampedrowwithemph "Requested activity" \
          $requestedactivitytimestamp \
          "warning" $requestedactivity
        writehtmltimestampedrowwithemph "Current activity" \
          $activitytimestamp \
          "warning" $activity
      } else {
        writehtmltimestampedrowwithemph "Requested activity" \
          $requestedactivitytimestamp \
          "" $requestedactivity
        writehtmltimestampedrowwithemph "Current activity" \
          $activitytimestamp \
          "" $activity
      }
      writehtmltimestampedrow "Current data" \
        $timestamp
    } else {
      writehtmltimestampedrow "Requested activity"
      writehtmltimestampedrow "Current activity"
      writehtmltimestampedrow "Current data"
    }

  }

  proc writeccd {server} {
  
    putshtml "<table class=\"status\">"

    writehtmlstatusblock $server

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus $server] "ok"]} {
      writehtmlfullrow "Telescope"                 [client::getdata $server "telescopedescription"]
      writehtmlfullrow "Detector"                  [client::getdata $server "detectordescription"]
      writehtmlrow "Exposure time"                 [formatifok "%.3f seconds" [client::getdata $server "exposuretime"]]
      writehtmlfullrow "FITS file"                 [file tail [client::getdata $server "fitsfilename"]]
      writehtmlrow "Detector read mode"            [client::getdata $server "detectorreadmode"]
      writehtmlrow "Detector software gain"        [formatifok "%d" [client::getdata $server "detectorsoftwaregain"]]
      writehtmlfullrow "Detector window"           [client::getdata $server "detectorwindow"]
      writehtmlrow "Detector binning"              [formatifok "%d" [client::getdata $server "detectorbinning"]]
      writehtmlrow "Cooler state"                  [format "%s" [client::getdata $server "detectorcoolerstate"]]
      writehtmlrow "Cooler set temperature"        [formatifok "%+.1f C" [client::getdata $server "detectorcoolersettemperature"]]
      writehtmlrow "Detector temperature"          [formatifok "%+.1f C" [client::getdata $server "detectordetectortemperature"]]
      if {![string equal "" [client::getdata $server "detectorhousingtemperature"]]} {
        writehtmlrow "Housing temperature"           [formatifok "%+.1f C" [client::getdata $server "detectorhousingtemperature"]]
      }
      if {![string equal "" [client::getdata $server "detectorcoldendtemperature"]]} {
        writehtmlrow "Cold end temperature"          [formatifok "%+.1f C" [client::getdata $server "detectorcoldendtemperature"]]
      }
      if {![string equal "" [client::getdata $server "detectorpowersupplytemperature"]]} {
        writehtmlrow "Power supply temperature"      [formatifok "%+.1f C" [client::getdata $server "detectorpowersupplytemperature"]]
      }
      if {![string equal "" [client::getdata $server "detectorchamberpressure"]]} {
        writehtmlrow "Chamber pressure"              [formatifok "%.2e mbar" [client::getdata $server "detectorchamberpressure"]]
      }
      if {![string equal "" [client::getdata $server "detectorcompressorsupplypressure"]]} {
        writehtmlrow "Compressor supply pressure"    [formatifok "%.0f psi" [client::getdata $server "detectorcompressorsupplypressure"]]
      }
      if {![string equal "" [client::getdata $server "detectorcompressorreturnpressure"]]} {
        writehtmlrow "Compressor return pressure"    [formatifok "%.0f psi" [client::getdata $server "detectorcompressorreturnpressure"]]
      }
      if {![string equal "" [client::getdata $server "detectorcompressorcurrent"]]} {
        writehtmlrow "Compressor current"            [formatifok "%.2f A" [client::getdata $server "detectorcompressorcurrent"]]
      }
      if {![string equal "" [client::getdata $server "detectorcoolerlowflow"]]} {
        writehtmlrow "Cooler low-flow"               [format "%s" [client::getdata $server "detectorcoolerlowflow"]]
      }
      if {![string equal "" [client::getdata $server "detectorcoolerpower"]]} {
        writehtmlrow "Cooler power"                  [formatpercentifok "%.0f%%" [client::getdata $server "detectorcoolerpower"]]
      }
      if {![string equal "" [client::getdata $server "detectordetectorheatercurrent"]]} {
        writehtmlrow "Detector heater current"       [formatifok "%.2f A" [client::getdata $server "detectordetectorheatercurrent"]]
      }
      if {![string equal "" [client::getdata $server "detectorcoldendheatercurrent"]]} {
        writehtmlrow "Cold end heater current"       [formatifok "%.2f A" [client::getdata $server "detectorcoldendheatercurrent"]]
      }
      writehtmlfullrow "Filter wheel"              [client::getdata $server "filterwheeldescription"]
      writehtmlfullrow "Filter"                    [client::getdata $server "filter"]
      if {![string equal "null" [client::getdata $server "filterwheeldescription"]]} {
        writehtmlrow "Filter wheel position"         [formatifok "%d" [client::getdata $server "filterwheelposition"]]
        writehtmlrow "Filter wheel maximum position" [formatifok "%d" [client::getdata $server "filterwheelmaxposition"]]
      }
      writehtmlfullrow "Focuser"                   [client::getdata $server "focuserdescription"]
      if {![string equal "null" [client::getdata $server "focuserdescription"]]} {
        writehtmlrow "Focuser requested position"    [formatifok "%d" [client::getdata $server "requestedfocuserposition"]]
        writehtmlrow "Focuser position"              [formatifok "%d" [client::getdata $server "focuserposition"]]
        writehtmlrow "Focuser position error"        [formatifok "%+d" [client::getdata $server "focuserpositionerror"]]
        writehtmlrow "Focuser raw position"          [formatifok "%d" [client::getdata $server "focuserrawposition"]]
        writehtmlrow "Focuser minimum position"      [formatifok "%d" [client::getdata $server "focuserminposition"]]
        writehtmlrow "Focuser maximum position"      [formatifok "%d" [client::getdata $server "focusermaxposition"]]
      }
      writehtmlrow "Solved position (α,δ)" \
        [formatalphaifdouble [client::getdata $server "solvedalpha"]] \
        [formatdeltaifdouble [client::getdata $server "solveddelta"] 1] \
        [formatifok "%.2f" [client::getdata $server "solvedequinox"]]
      writehtmlrow "Solved observed position (α,δ)" \
        [formatalphaifdouble [client::getdata $server "solvedobservedalpha"]] \
        [formatdeltaifdouble [client::getdata $server "solvedobserveddelta"] 1]
      writehtmlrow "Mount observed position (α,δ)" \
        [formatalphaifdouble [client::getdata $server "mountobservedalpha"]] \
        [formatdeltaifdouble [client::getdata $server "mountobserveddelta"] 1]
      writehtmltimestampedrow "Last correction" \
        [client::getdata $server "lastcorrectiontimestamp"]
      writehtmlrow "Last correction (E,N)" \
        [formatoffsetifdouble [client::getdata $server "lastcorrectioneastoffset"]] \
        [formatoffsetifdouble [client::getdata $server "lastcorrectionnorthoffset"]]
      writehtmlrow "FWHM" \
        [formatifok "%.2f pixels" [client::getdata $server "fwhm"]]
      writehtmlrow "Average and Standard Deviation" \
        [formatifok "%.1f" [client::getdata $server "average"]] \
        [formatifok "%.1f" [client::getdata $server "standarddeviation"]] \
    }

    putshtml "</table>"

  }

  proc writeC0 {} {
    writeccd C0
  }

  proc writeC1 {} {
    writeccd C1
  }

  proc writeC2 {} {
    writeccd C2
  }

  proc writeC3 {} {
    writeccd C3
  }

  proc writeC4 {} {
    writeccd C4
  }

  proc writeC5 {} {
    writeccd C5
  }

  proc writecovers {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "covers"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "covers"] "ok"]} {
      writehtmlrow "Requested covers" [client::getdata "covers" "requestedcovers"]
      writehtmlrow "Current covers" [client::getdata "covers" "covers"]
      writehtmlrow "Mode" [client::getdata "covers" "mode"]
      if {![catch {client::getdata "covers" "inputchannels"}]} {
        writehtmlrow "Input channels" [client::getdata "covers" "inputchannels"]
      }
      if {![catch {client::getdata "covers" "outputchannels"}]} {
        writehtmlrow "Output channels" [client::getdata "covers" "outputchannels"]
      }
    }
  
    putshtml "</table>"

  }

  proc writeshutters {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "shutters"
  
    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "shutters"] "ok"]} {
      writehtmlrow "Requested shutters"     [client::getdata "shutters" "requestedshutters"]    
      writehtmlrow "Current upper shutter"  [client::getdata "shutters" "uppershutter"]
      writehtmlrow "Current lower shutter"  [client::getdata "shutters" "lowershutter"]
      writehtmlrow "Current power contacts" [client::getdata "shutters" "powercontacts"]
    }
  
    putshtml "</table>"

  }

  proc writetarget {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "target"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    writehtmlrow "LAST" [formatalphaifdouble [astrometry::last]]
    if {[string equal [client::getstatus "target"] "ok"]} {
      writehtmlrow "Requested position (α,HA,δ)" \
        [formatalphaifdouble [client::getdata "target" "requestedalpha"]] \
        [formathaifdouble    [client::getdata "target" "requestedha"]] \
        [formatdeltaifdouble [client::getdata "target" "requesteddelta"]]
      writehtmlrow "Requested equinox" \
        [formatifok "%.2f" [client::getdata "target" "requestedequinox"]]
      writehtmlrow "Requested offset (α,δ)" \
        [formatoffsetifdouble [client::getdata "target" "requestedalphaoffset"]] \
        "" \
        [formatoffsetifdouble [client::getdata "target" "requesteddeltaoffset"]]
      writehtmltimestampedrow "Requested epoch" \
        [client::getdata "target" "requestedepochtimestamp"]
      writehtmlrow "Requested rate (α,δ)" \
        [formatrateifdouble [client::getdata "target" "requestedalpharate"]] \
        "" \
        [formatrateifdouble [client::getdata "target" "requesteddeltarate"]]
      writehtmlrow "Requested aperture" \
        [client::getdata "target" "requestedaperture"]
      writehtmlrow "Current position (α,HA,δ)" \
        [formatalphaifdouble [client::getdata "target" "currentalpha"]] \
        [formathaifdouble    [client::getdata "target" "currentha"]] \
        [formatdeltaifdouble [client::getdata "target" "currentdelta"]]
      writehtmlrow "Current equinox" \
        [formatifok "%.2f" [client::getdata "target" "currentequinox"]]
      writehtmlrow "Standard position (α,HA,δ)" \
        [formatalphaifdouble [client::getdata "target" "standardalpha"]] \
        "" \
        [formatdeltaifdouble [client::getdata "target" "standarddelta"]]
      writehtmlrow "Standard rate (α,δ)" \
        [formatrateifdouble [client::getdata "target" "standardalpharate"]] \
        "" \
        [formatrateifdouble [client::getdata "target" "standarddeltarate"]]
      writehtmlrow "Standard equinox" \
        [formatifok "%.2f" [client::getdata "target" "standardequinox"]]
      writehtmlrow "Aperture offset (α,δ)" \
        [formatoffsetifdouble [client::getdata "target" "aperturealphaoffset"]] \
        "" \
        [formatoffsetifdouble [client::getdata "target" "aperturedeltaoffset"]]
      writehtmlrow "Observed position (α,HA,δ)" \
        [formatalphaifdouble [client::getdata "target" "observedalpha"]] \
        [formathaifdouble    [client::getdata "target" "observedha"]] \
        [formatdeltaifdouble [client::getdata "target" "observeddelta"]]
      writehtmlrow "Observed rate (α,δ)" \
        [formatrateifdouble [client::getdata "target" "observedalpharate"]] \
        [formatrateifdouble [client::getdata "target" "observedharate"]] \
        [formatrateifdouble [client::getdata "target" "observeddeltarate"]]
      writehtmlrow "Observed position (A,z,X)" \
        [formatradtodegifdouble "%.2f°" [client::getdata "target" "observedazimuth"]] \
        [formatradtodegifdouble "%.2f°" [client::getdata "target" "observedzenithdistance"]] \
        [formatifok "%.3f" [client::getdata "target" "observedairmass"]]
      writehtmlrow "Within limits" \
        [client::getdata "target" "withinlimits"]
    }

    putshtml "</table>"

  }

  proc writelights {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "lights"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "lights"] "ok"]} {
      writehtmlrow "Requested lights" [client::getdata "lights" "requestedlights"]
      writehtmlrow "Current lights" [client::getdata "lights" "lights"]
    }
  
    putshtml "</table>"

  }

  proc writemoon {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "moon"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    writehtmlrow "LAST" [formatalphaifdouble [astrometry::last]]
    if {[string equal [client::getstatus "moon"] "ok"]} {
      writehtmlrow "Observed position (α,HA,δ)" \
        [formatalphaifdouble [client::getdata "moon" "observedalpha"]] \
        [formathaifdouble    [client::getdata "moon" "observedha"]] \
        [formatdeltaifdouble [client::getdata "moon" "observeddelta"]]
      writehtmlrow "Observed position (A,z)" \
        [formatradtodegifdouble "%.2f°" [client::getdata "moon" "observedazimuth"]] \
        [formatradtodegifdouble "%.2f°" [client::getdata "moon" "observedzenithdistance"]]
      writehtmlrow "Observed target distance" \
        [formatradtodegifdouble "%.2f°" [client::getdata "moon" "observedtargetdistance"]]
      writehtmlrow "Sky state" [client::getdata "moon" "skystate"]
      writehtmlrow "Illuminated" \
        [format "%2.0f%%" [expr {[client::getdata "moon" "illuminatedfraction"] * 100}]]
    }

    putshtml "</table>"

  }

  proc writeplc {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "plc"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "plc"] "ok"]} {
      writehtmlrow "Mode"        [client::getdata "plc" "mode"]
      if {[client::getdata "plc" "mustbeclosed"]} {
        writehtmlrowwithemph "Must be closed" "warning" "true"
      } else {
        writehtmlrowwithemph "Must be closed" "" "false"
      }
      writehtmlrow "Roof"           [client::getdata "plc" "roof"]
      writehtmlrow "Door"           [client::getdata "plc" "door"]
      writehtmlrow "Lights"         [client::getdata "plc" "lights"]
      writehtmlrowwithemph "Alarm"          [alarmemph [client::getdata "plc" "alarm"]]         [client::getdata "plc" "alarm"]
      writehtmlrowwithemph "AAG alarm"      [alarmemph [client::getdata "plc" "aagalarm"]]      [client::getdata "plc" "aagalarm"]
      writehtmlrowwithemph "Rain alarm"     [alarmemph [client::getdata "plc" "rainalarm"]]     [client::getdata "plc" "rainalarm"]
      writehtmlrowwithemph "Wind alarm"     [alarmemph [client::getdata "plc" "windalarm"]]     [client::getdata "plc" "windalarm"]
      writehtmlrowwithemph "UPS alarm"      [alarmemph [client::getdata "plc" "upsalarm"]]      [client::getdata "plc" "upsalarm"]
      writehtmlrowwithemph "Humidity alarm" [alarmemph [client::getdata "plc" "humidityalarm"]] [client::getdata "plc" "humidityalarm"]
      writehtmlrowwithemph "Watchdog alarm" [alarmemph [client::getdata "plc" "watchdogalarm"]] [client::getdata "plc" "watchdogalarm"]
    }

    putshtml "</table>"

  }

  proc writesun {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "sun"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    writehtmlrow "LAST" [formatalphaifdouble [astrometry::last]]
    if {[string equal [client::getstatus "sun"] "ok"]} {
      writehtmlrow "Observed position (α,HA,δ)" \
        [formatalphaifdouble [client::getdata "sun" "observedalpha"]] \
        [formathaifdouble    [client::getdata "sun" "observedha"]] \
        [formatdeltaifdouble [client::getdata "sun" "observeddelta"]]
      writehtmlrow "Observed position (A,z)" \
        [formatradtodegifdouble "%.2f°" [client::getdata "sun" "observedazimuth"]] \
        [formatradtodegifdouble "%.2f°" [client::getdata "sun" "observedzenithdistance"]]
      writehtmlrow "Observed target distance" \
        [formatradtodegifdouble "%.2f°" [client::getdata "sun" "observedtargetdistance"]]
      writehtmlrow "Sky state" [client::getdata "sun" "skystate"]
      set seconds [utcclock::seconds]
      set startofdayseconds   [utcclock::scan [client::getdata "sun" "startofday"  ]]
      set endofdayseconds     [utcclock::scan [client::getdata "sun" "endofday"    ]]
      set startofnightseconds [utcclock::scan [client::getdata "sun" "startofnight"]]
      set endofnightseconds   [utcclock::scan [client::getdata "sun" "endofnight"  ]]
      writehtmlfullrow "End of day" \
        "[utcclock::format $endofdayseconds     0] (in [utcclock::formattime [expr {$endofdayseconds     - $seconds}] 0])"
      writehtmlfullrow "Start of night" \
        "[utcclock::format $startofnightseconds 0] (in [utcclock::formattime [expr {$startofnightseconds - $seconds}] 0])"
      writehtmlfullrow "End of night" \
        "[utcclock::format $endofnightseconds   0] (in [utcclock::formattime [expr {$endofnightseconds   - $seconds}] 0])"
      writehtmlfullrow "Start of day" \
        "[utcclock::format $startofdayseconds   0] (in [utcclock::formattime [expr {$startofdayseconds   - $seconds}] 0])"
    }

    putshtml "</table>"

  }

  proc writesupervisor {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "supervisor"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "supervisor"] "ok"]} {
      writehtmlrow "Mode"                [client::getdata "supervisor" "mode"]
      writehtmlrow "May be open"         [client::getdata "supervisor" "maybeopen"]
      writehtmlrow "May be open to cool" [client::getdata "supervisor" "maybeopentocool"]
      writehtmlrow "Open"                [client::getdata "supervisor" "open"]
      writehtmlrow "Open to cool"        [client::getdata "supervisor" "opentocool"]
      writehtmlrow "Closed"              [client::getdata "supervisor" "closed"]
      writehtmlrow "Why"                 [client::getdata "supervisor" "why"]
    }

    putshtml "</table>"

  }

  proc writemount {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "mount"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "mount"] "ok"]} {
      writehtmlrow "LAST" [formatalphaifdouble [astrometry::last [utcclock::scan [client::getdata "mount" "timestamp"]]]]
      writehtmlrow "State" [client::getdata "mount" "state"]
      writehtmlrow "Requested observed position (α,HA,δ)" \
        [formatalphaifdouble [client::getdata "mount" "requestedobservedalpha"]] \
        [formathaifdouble    [client::getdata "mount" "requestedobservedha"]] \
        [formatdeltaifdouble [client::getdata "mount" "requestedobserveddelta"]]
      writehtmlrow "Requested observed rate (α,δ)" \
        [formatrateifdouble [client::getdata "mount" "requestedobservedalpharate"]] \
        "" \
        [formatrateifdouble [client::getdata "mount" "requestedobserveddeltarate"]]
      writehtmlrow "Requested mount rotation" \
        [formatradtodegifdouble "%.0f°"  [client::getdata "mount" "requestedmountrotation"]]
      writehtmlrow "Requested mount position (α,HA,δ)" \
        [formatalphaifdouble [client::getdata "mount" "requestedmountalpha"]] \
        [formathaifdouble    [client::getdata "mount" "requestedmountha"]] \
        [formatdeltaifdouble [client::getdata "mount" "requestedmountdelta"]]
      writehtmlrow "Requested mount rate (α,δ)" \
        [formatrateifdouble [client::getdata "mount" "requestedmountalpharate"]] \
        "" \
        [formatrateifdouble [client::getdata "mount" "requestedmountdeltarate"]]
      writehtmlrow "Current mount rotation" \
        [formatradtodegifdouble "%.0f°"  [client::getdata "mount" "mountrotation"]]
      writehtmlrow "Current mount position (α,HA,δ)" \
        [formatalphaifdouble [client::getdata "mount" "mountalpha"]] \
        [formathaifdouble    [client::getdata "mount" "mountha"]] \
        [formatdeltaifdouble [client::getdata "mount" "mountdelta"]]
      writehtmlrow "Current mount error (α,HA,δ)" \
        [formathaifdouble    [client::getdata "mount" "mountalphaerror"]] \
        [formathaifdouble    [client::getdata "mount" "mounthaerror"]] \
        [formatdeltaifdouble [client::getdata "mount" "mountdeltaerror"]]
      writehtmlrow "Mean mount tracking error (α,δ)" \
        [formatarcsecifdouble "%+.2fas" [client::getdata "mount" "mountmeaneasttrackingerror"]] \
        "" \
        [formatarcsecifdouble "%+.2fas" [client::getdata "mount" "mountmeannorthtrackingerror"]]
      writehtmlrow "RMS mount tracking error (α,δ)" \
        [formatarcsecifdouble "%.2fas" [client::getdata "mount" "mountrmseasttrackingerror"]] \
        "" \
        [formatarcsecifdouble "%.2fas" [client::getdata "mount" "mountrmsnorthtrackingerror"]]
      writehtmlrow "P-V mount tracking error (α,δ)" \
        [formatarcsecifdouble "%.2fas" [client::getdata "mount" "mountpveasttrackingerror"]] \
        "" \
        [formatarcsecifdouble "%.2fas" [client::getdata "mount" "mountpvnorthtrackingerror"]]
      writehtmltimestampedrow "Last correction" \
        [client::getdata "mount" "lastcorrectiontimestamp"]
      writehtmlrow "Last correction (α,δ)" \
        [formatoffsetifdouble [client::getdata "mount" "lastcorrectiondalpha"]] \
        "" \
        [formatoffsetifdouble [client::getdata "mount" "lastcorrectionddelta"]]
    }

    putshtml "</table>"

  }

  proc writeinclinometers {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "inclinometers"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "inclinometers"] "ok"]} {
      writehtmlrow "Current position (X,Y)" \
        [format "%+.2f°" [astrometry::radtodeg [client::getdata "inclinometers" "X"]]] \
        [format "%+.2f°" [astrometry::radtodeg [client::getdata "inclinometers" "Y"]]]
      writehtmlrow "Current position (x,y)" \
        [format "%+.2f°" [astrometry::radtodeg [client::getdata "inclinometers" "x"]]] \
        [format "%+.2f°" [astrometry::radtodeg [client::getdata "inclinometers" "y"]]]
      writehtmlrow "Current position (HA,δ)" \
        [formathaifdouble [client::getdata "inclinometers" "ha"]] \
        [formatdeltaifdouble [client::getdata "inclinometers" "delta"]]
      writehtmlrow "Current position (A,z)" \
        [formatradtodegifdouble "%.2f°" [client::getdata "inclinometers" "azimuth"]] \
        [format "%.2f°" [astrometry::radtodeg [client::getdata "inclinometers" "zenithdistance"]]]
      writehtmlrow "Proximity switches (HA,δ)" \
        [client::getdata "inclinometers" "haswitch"] \
        [client::getdata "inclinometers" "deltaswitch"]
    }

    putshtml "</table>"

  }

  proc writeinstrument {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "instrument"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "instrument"] "ok"]} {
      writehtmlfullrow "Detectors" [join [client::getdata "instrument" "detectors"]]
    }

    putshtml "</table>"

  }

  proc writedome {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "dome"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "dome"] "ok"]} {
      writehtmlrow "Controller initialized"         [client::getdata "dome" "controllerinitialized"]
      writehtmlrow "Requested azimuth"              [formatradtodegifdouble "%.1f°" [client::getdata "dome" "requestedazimuth"]]
      writehtmlrow "Current azimuth"                [formatradtodegifdouble "%.1f°" [client::getdata "dome" "azimuth"]]
      writehtmlrow "Current azimuth error"          [formatradtodegifdouble "%+.1f°" [client::getdata "dome" "azimutherror"]]
      writehtmlrow "Maximum absolute azimuth error" [formatradtodegifdouble "%+.1f°" [client::getdata "dome" "maxabsazimutherror"]]
    }
  
    putshtml "</table>"

  }

  proc writeguider {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "guider"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "guider"] "ok"]} {
      writehtmlrow "Guiding" \
        [formatifok "%.0f seconds" [client::getdata "guider" "guidingtime"]]
      writehtmlrow "Finder" \
        [client::getdata "guider" "finder"]
      writehtmlrow "Exposure time" \
        [formatifok "%.2f seconds" [client::getdata "guider" "exposuretime"]]
      writehtmlrow "Mean cadence" \
        [formatifok "%.2f seconds" [client::getdata "guider" "meancadence"]]
      writehtmlrow "East Gain" \
        [formatifok "%+.2f" [client::getdata "guider" "eastgain"]]
      writehtmlrow "North Gain" \
        [formatifok "%+.2f" [client::getdata "guider" "northgain"]]
      writehtmlrow "Dead-zone width" \
        [formatguidererrorifdouble [client::getdata "guider" "deadzonewidth"]]
      writehtmlrow "Dead-zone fraction" \
        [formatifok "%.2f" [client::getdata "guider" "deadzonefraction"]]
      writehtmlrow "Current error (E, N, total)" \
        [formatguidererrorifdouble [client::getdata "guider" "easterror"]] \
        [formatguidererrorifdouble [client::getdata "guider" "northerror"]] \
        [formatguidererrorifdouble [client::getdata "guider" "totalerror"]]
      writehtmlrow "Mean error (E, N, total)" \
        [formatguidererrorifdouble [client::getdata "guider" "meaneasterror"]] \
        [formatguidererrorifdouble [client::getdata "guider" "meannortherror"]] \
        [formatguidererrorifdouble [client::getdata "guider" "meantotalerror"]]
      writehtmlrow "RMS error about mean (E, N, total)" \
        [formatguidererrorifdouble [client::getdata "guider" "rmseasterror"]] \
        [formatguidererrorifdouble [client::getdata "guider" "rmsnortherror"]] \
        [formatguidererrorifdouble [client::getdata "guider" "rmstotalerror"]]
      writehtmlrow "Total offset (E, N, total)" \
        [formatguidererrorifdouble [client::getdata "guider" "totaleastoffset"]] \
        [formatguidererrorifdouble [client::getdata "guider" "totalnorthoffset"]] \
        [formatguidererrorifdouble [client::getdata "guider" "totaltotaloffset"]]
      writehtmlrow "Mean offset rate (E, N, total)" \
        [formatrateifdouble [client::getdata "guider" "meaneastoffsetrate"]] \
        [formatrateifdouble [client::getdata "guider" "meannorthoffsetrate"]] \
        [formatrateifdouble [client::getdata "guider" "meantotaloffsetrate"]]
    }

    putshtml "</table>"

  }

  proc writepower {} {
  
    variable powerhosts
    variable poweroutletgroupaddresses

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "power"

    putshtml "</table>"

    putshtml "<table class=\"status\">"


    if {[string equal [client::getstatus "power"] "ok"]} {
      foreach host [dict keys $powerhosts] {
        writehtmlfullrow "Host $host current" [format "%.1f A" [client::getdata "power" "$host-current"]]
      }
      foreach outletgroup [dict keys $poweroutletgroupaddresses] {
        writehtmlfullrow "Outlet $outletgroup" [join [client::getdata "power" "$outletgroup"] " "]
      }
    }

    putshtml "</table>"

  }

  proc writesecondary {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "secondary"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "secondary"] "ok"]} {
      writehtmlrow "Requested position (z0)" [formatifok "%d" [client::getdata "secondary" "requestedz0"]]
      writehtmlrow "Temperature correction (dzT)" [formatifok "%+d" [client::getdata "secondary" "dzT"]]
      writehtmlrow "Requested position (zT)" [formatifok "%d" [client::getdata "secondary" "requestedzT"]]
      writehtmlrow "Position correction (dzP)" [formatifok "%+d" [client::getdata "secondary" "dzP"]]
      writehtmlrow "Requested position (zP)" [formatifok "%d" [client::getdata "secondary" "requestedzP"]]
      writehtmlrow "Requested offset (dzO)" [formatifok "%+d" [client::getdata "secondary" "requesteddzoffset"]]
      writehtmlrow "Requested position (z)" [formatifok "%d" [client::getdata "secondary" "requestedz"]]
      writehtmlrow "Current position (z)" [formatifok "%d" [client::getdata "secondary" "z"]]
      writehtmlrow "Current error in position (z)" [formatifok "%+d" [client::getdata "secondary" "zerror"]]
      writehtmlrow "Minimum position (z)" [formatifok "%d" [client::getdata "secondary" "minz"]]
      writehtmlrow "Maximum position (z)" [formatifok "%d" [client::getdata "secondary" "maxz"]]
      writehtmlrow "Current z lower limit switch" [client::getdata "secondary" "zlowerlimit"]
      writehtmlrow "Current z upper limit switch" [client::getdata "secondary" "zupperlimit"]
    }

    putshtml "</table>"

  }

  proc writesensors {} {
  
    variable sensors

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "sensors"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "sensors"] "ok"]} {
      foreach name [dict keys $sensors] {
        set value [join [client::getdata "sensors" "$name"] " "]
        set timestamp [client::getdata "sensors" "${name}-timestamp"]
        if {[string equal $value ""] || [string equal $timestamp ""]} {
          writehtmlfullrowwithemph $name "warning" "unknown"
        } else {
          set timestamp [utcclock::format $timestamp 0]
          if {[utcclock::diff now $timestamp] > 600} {
            set emphasis "warning"
          } else {
            set emphasis ""
          }
          set unit [dict get $sensors $name "unit"]
          switch -glob "$name:$unit" {
            *-temperature:C {
              writehtmlfullrowwithemph $name $emphasis "$timestamp [format "%+.1f C" $value]"
            }
            *-detector-cooler-power: -
            *-humidity: -
            *-light-level: -
            *-disk-space-used: {      
              writehtmlfullrowwithemph $name $emphasis "$timestamp [format "%.0f%%" [expr {$value * 100}]]"
            }
            *: {
              writehtmlfullrowwithemph $name $emphasis "$timestamp $value"
            }
            default {
              writehtmlfullrowwithemph $name $emphasis "$timestamp $value $unit"
            }
          }
        }
      }
    }

    putshtml "</table>"

  }
  
  proc writetelescope {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "telescope"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "telescope"] "ok"]} {
      writehtmlrow "Pointing mode" \
        [client::getdata "telescope" "pointingmode"]
      writehtmlrow "Pointing tolerance" \
        [format "%.1fas" [astrometry::radtoarcsec [client::getdata "telescope" "pointingtolerance"]]]
      writehtmlrow "Guiding mode" \
        [client::getdata "telescope" "guidingmode"]
    }

    putshtml "</table>"

  }

  proc writetemperatures {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "temperatures"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "weather"] "ok"]} {
      set E [client::getdata "weather" "temperature"]
    } else {
      set E ""
    }

    if {[string equal [client::getstatus "temperatures"] "ok"]} {
      set A1 [client::getdata "temperatures" "A1"]
    } else {
      set A1 ""
    }

    if {[string equal [client::getstatus "temperatures"] "ok"]} {
      writehtmlrow "P1 (Primary E)" \
        [format "%+.1f C" [client::getdata "temperatures" "P1"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P1"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P1"] $E]
      writehtmlrow "P2 (Primary N)" \
        [format "%+.1f C" [client::getdata "temperatures" "P2"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P2"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P2"] $E]
      writehtmlrow "P3 (Primary W)" \
        [format "%+.1f C" [client::getdata "temperatures" "P3"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P3"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P3"] $E]
      writehtmlrow "P4 (Primary S)" \
        [format "%+.1f C" [client::getdata "temperatures" "P4"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P4"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P4"] $E]
      writehtmlrow "P  (Primary)" \
        [format "%+.1f C" [client::getdata "temperatures" "P"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "P"] $E]
      writehtmlrow "A1 (Primary E)" \
        [format "%+.1f C" [client::getdata "temperatures" "A1"]] \
        "" \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A1"] $E]
      writehtmlrow "A2 (Intermediate E)" \
        [format "%+.1f C" [client::getdata "temperatures" "A2"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A2"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A2"] $E]
      writehtmlrow "A3 (Covers E)" \
        [format "%+.1f C" [client::getdata "temperatures" "A3"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A3"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A3"] $E]
      writehtmlrow "A4 (Lower struts E)"  \
        [format "%+.1f C" [client::getdata "temperatures" "A4"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A4"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A4"] $E]
      writehtmlrow "A5 (Middle struts E)" \
        [format "%+.1f C" [client::getdata "temperatures" "A5"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A5"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A5"] $E]
      writehtmlrow "A6 (Upper struts E)" \
        [format "%+.1f C" [client::getdata "temperatures" "A6"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A6"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A6"] $E]
      writehtmlrow "A7 (Upper top end)" \
        [format "%+.1f C" [client::getdata "temperatures" "A7"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A7"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A7"] $E]
      writehtmlrow "A8 (Lower top end)" \
        [format "%+.1f C" [client::getdata "temperatures" "A8"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A8"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "A8"] $E]
      writehtmlrow "S  (Secondary)" \
        [format "%+.1f C" [client::getdata "temperatures" "S"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "S"] $A1] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "temperatures" "S"] $E]
    }

    if {[string equal [client::getstatus "weather"] "ok"]} {
      writehtmlrow "E  (External)" \
        [formatifok "%+.1f C" [client::getdata "weather" "temperature"]] \
        [formatdifferenceifdouble "%+.1f C" [client::getdata "weather" "temperature"] $A1] \
        ""
    }

    putshtml "</table>"

  }

  proc writeweather {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "weather"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "weather"] "ok"]} {
      writehtmlrowwithemph "Must be closed" [alarmemph [client::getdata "weather" "mustbeclosed"]] [client::getdata "weather" "mustbeclosed"]
      writehtmlrow "Temperature" \
        [format "%+.1f C" [client::getdata "weather" "temperature"]] \
        [client::getdata "weather" "temperaturetrend"]
      writehtmlrow "Dewpoint" \
        [format "%+.1f C" [client::getdata "weather" "dewpoint"]] \
        [client::getdata "weather" "dewpointtrend"]
      writehtmlrow "Dewpoint depression" \
        [format "%+.1f C" [client::getdata "weather" "dewpointdepression"]] \
        [client::getdata "weather" "dewpointdepressiontrend"]
      writehtmlrow "Humidity" \
        [formatpercentifok "%.0f%%" [client::getdata "weather" "humidity"]] \
        [client::getdata "weather" "humiditytrend"]
      if {![string equal [client::getdata "weather" "windaveragespeed"] "unknown"]} {
        writehtmlrow "Wind average speed" \
          [format "%.0f km/h" [client::getdata "weather" "windaveragespeed"]] \
          [format "%.1f m/s" [expr {[client::getdata "weather" "windaveragespeed"] / 3.6}]]
      } else {
        writehtmlrow "Wind average speed"
      }
      if {![string equal [client::getdata "weather" "windgustspeed"] "unknown"]} {
        writehtmlrow "Wind gust speed" \
          [format "%.0f km/h" [client::getdata "weather" "windgustspeed"]] \
          [format "%.1f m/s" [expr {[client::getdata "weather" "windgustspeed"] / 3.6}]]        
      } else {
        writehtmlrow "Wind gust speed"
      }
      if {![string equal [client::getdata "weather" "windaverageazimuth"] "unknown"]} {
        writehtmlrow "Wind average azimuth" \
          [formatradtodegifdouble "%.1f°" [client::getdata "weather" "windaverageazimuth"]]
      } else {
        writehtmlrow "Wind average azimuth"
      }
      writehtmlrow "Wind average speed limit" \
        [formatifok "%.0f km/h" [client::getdata "weather" "windaveragespeedlimit"]]
      writehtmlrow "Wind average speed below limit" \
        [format "%.2f h" [expr {[client::getdata "weather" "lowwindspeedseconds"] / 3600.0}]]
      if {![string equal [client::getdata "weather" "rainrate"] "unknown"]} {
        writehtmlrow "Rain rate" \
          [format "%.1f mm/h" [client::getdata "weather" "rainrate"]]
      } else {
        writehtmlrow "Rain rate"
      }
      if {![string equal [client::getdata "weather" "pressure"] "unknown"]} {
        writehtmlrow "Pressure" \
          [format "%.1f mbar" [client::getdata "weather" "pressure"]] \
          [client::getdata "weather" "pressuretrend"]
      } else {
        writehtmlrow "Pressure"
      }
      if {![string equal [client::getdata "weather" "lightlevel"] "unknown"]} {
        writehtmlrow "Light level" [client::getdata "weather" "lightlevel"]
      } else {
        writehtmlrow "Light level"
      }
      if {![string equal [client::getdata "weather" "cloudiness"] "unknown"]} {
        writehtmlrow "Cloudiness" [client::getdata "weather" "cloudiness"]
      } else {
        writehtmlrow "Cloudiness"
      }
      writehtmlrow "Humidity limit" \
        [formatpercentifok "%.0f%%" [client::getdata "weather" "humiditylimit"]]
      writehtmlrowwithemph "Humidity alarm" [alarmemph [client::getdata "weather" "humidityalarm"]] [client::getdata "weather" "humidityalarm"]
      writehtmlrowwithemph "Wind alarm"     [alarmemph [client::getdata "weather" "windalarm"]]     [client::getdata "weather" "windalarm"]
      writehtmlrowwithemph "Rain alarm"     [alarmemph [client::getdata "weather" "rainalarm"]]      [client::getdata "weather" "rainalarm"]
    }

    putshtml "</table>"

  }

  proc writefinder {server} {
  
    putshtml "<table class=\"status\">"

    writehtmlstatusblock $server

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus $server] "ok"]} {
      writehtmlfullrow "Telescope"                 [client::getdata $server "telescopedescription"]
      writehtmlfullrow "Detector"                  [client::getdata $server "detectordescription"]
      writehtmlrow "Exposure time"                 [formatifok "%.3f seconds" [client::getdata $server "exposuretime"]]
      writehtmlfullrow "FITS file"                 [file tail [client::getdata $server "fitsfilename"]]
      writehtmlrow "Detector read mode"            [client::getdata $server "detectorreadmode"]
      writehtmlrow "Detector software gain"        [formatifok "%d" [client::getdata $server "detectorsoftwaregain"]]
      writehtmlrow "Detector binning"              [formatifok "%d" [client::getdata $server "detectorbinning"]]
      writehtmlrow "Detector temperature"          [formatifok "%+.1f C" [client::getdata $server "detectordetectortemperature"]]
      writehtmlrow "Housing temperature"           [formatifok "%+.1f C" [client::getdata $server "detectorhousingtemperature"]]
      writehtmlrow "Cooler state"                  [format "%s" [client::getdata $server "detectorcoolerstate"]]
      writehtmlrow "Cooler set temperature"        [formatifok "%+.1f C" [client::getdata $server "detectorcoolersettemperature"]]
      writehtmlrow "Cooler power"                  [formatifok "%.0f%%" [client::getdata $server "detectorcoolerpower"]]
      writehtmlfullrow "Filter wheel"              [client::getdata $server "filterwheeldescription"]
      writehtmlrow "Filter wheel position"         [formatifok "%d" [client::getdata $server "filterwheelposition"]]
      writehtmlrow "Filter wheel maximum position" [formatifok "%d" [client::getdata $server "filterwheelmaxposition"]]
      writehtmlfullrow "Focuser"                   [client::getdata $server "focuserdescription"]
      writehtmlrow "Focuser position"              [formatifok "%d" [client::getdata $server "focuserposition"]]
      writehtmlrow "Focuser minimum position"      [formatifok "%d" [client::getdata $server "focuserminposition"]]
      writehtmlrow "Focuser maximum position"      [formatifok "%d" [client::getdata $server "focusermaxposition"]]
      writehtmlrow "Solved position (α,δ)" \
        [formatalphaifdouble [client::getdata $server "solvedalpha"]] \
        [formatdeltaifdouble [client::getdata $server "solveddelta"] 1] \
        [formatifok "%.2f" [client::getdata $server "solvedequinox"]]
      writehtmlrow "Solved observed position (α,δ)" \
        [formatalphaifdouble [client::getdata $server "solvedobservedalpha"]] \
        [formatdeltaifdouble [client::getdata $server "solvedobserveddelta"] 1]
      writehtmlrow "Mount observed position (α,δ)" \
        [formatalphaifdouble [client::getdata $server "mountobservedalpha"]] \
        [formatdeltaifdouble [client::getdata $server "mountobserveddelta"] 1]
      writehtmltimestampedrow "Last correction" \
        [client::getdata $server "lastcorrectiontimestamp"]
      writehtmlrow "Last correction (E,N)" \
        [formatoffsetifdouble [client::getdata $server "lastcorrectioneastoffset"]] \
        [formatoffsetifdouble [client::getdata $server "lastcorrectionnorthoffset"]]
      writehtmlrow "FWHM" \
        [formatifok "%.2f pixels" [client::getdata $server "fwhm"]]
    }

    putshtml "</table>"

  }

  proc writenefinder {} {
    writefinder nefinder
  }

  proc writesefinder {} {
    writefinder sefinder
  }

  proc writenwfinder {} {
    writefinder nwfinder
  }

  proc writecryostattemperature {label emphasis temperature trend} {
    if {[string is double -strict $temperature]} {
      set K [format "%.3f K" $temperature]
      set C [format "%+.3f C" [expr {$temperature - 273.15}]]
    } else {
      set K $temperature
      set C $temperature
    }
    if {[string equal $trend "unknown"]} {
      set trend ""
    }
    writehtmlrowwithemph $label $emphasis $K "" $C "" $trend    
  }
  
  proc writecryostat {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "cryostat"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "cryostat"] "ok"]} {
      set alarm [client::getdata "cryostat" "alarm"]
      switch $alarm {
        "critical" {
          set emphasis "error"
        }
        "warning" {
          set emphasis "warning"
        }
        default {
          set emphasis ""
        }
      }
      writecryostattemperature "Cold Finger (A)"  $emphasis [client::getdata "cryostat" "A" ] [client::getdata "cryostat" "Atrend" ]
      writecryostattemperature "Cold Plate (B)"   ""        [client::getdata "cryostat" "B" ] [client::getdata "cryostat" "Btrend" ]
      writecryostattemperature "JADE 1 (C1)"      ""        [client::getdata "cryostat" "C1"] [client::getdata "cryostat" "C1trend"]
      writecryostattemperature "JADE 2 (C2)"      ""        [client::getdata "cryostat" "C2"] [client::getdata "cryostat" "C2trend"]
      writecryostattemperature "ASIC 1 (C3)"      ""        [client::getdata "cryostat" "C3"] [client::getdata "cryostat" "C3trend"]
      writecryostattemperature "ASIC 2 (C4)"      ""        [client::getdata "cryostat" "C4"] [client::getdata "cryostat" "C4trend"]
      writecryostattemperature "Detector 1 (D1)"  ""        [client::getdata "cryostat" "D1"] [client::getdata "cryostat" "D1trend"]
      writecryostattemperature "Detector 2 (D2)"  ""        [client::getdata "cryostat" "D2"] [client::getdata "cryostat" "D2trend"]
      writecryostattemperature "Cold Shield (D3)" ""        [client::getdata "cryostat" "D3"] [client::getdata "cryostat" "D3trend"]
      writecryostattemperature "Cold Shield (D4)" ""        [client::getdata "cryostat" "D4"] [client::getdata "cryostat" "D4trend"]

      set P      [client::getdata "cryostat" "P"     ]
      set Ptrend [client::getdata "cryostat" "Ptrend"]
      if {[string is double -strict $P]} {
        set P [format "%.2e mbar" $P]
      }
      if {[string equal $Ptrend "unknown"]} {
        set Ptrend ""
      }
      writehtmlrowwithemph "Pressure" "" $P "" "" "" $Ptrend
    }
    
    putshtml "</table>"
  }

  proc writepirani {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "pirani"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "pirani"] "ok"]} {
      set pressure      [client::getdata "pirani" "pressure"     ]
      set pressuretrend [client::getdata "pirani" "pressuretrend"]
      set alarm         [client::getdata "pirani" "alarm"]
      if {[string is double -strict $pressure]} {
        set pressure [format "%.1e Torr" $pressure]
      }
      if {[string equal $pressuretrend "unknown"]} {
        set pressuretrend ""
      }
      switch $alarm {
        "critical" {
          set emphasis "error"
        }
        "warning" {
          set emphasis "warning"
        }
        default {
          set emphasis ""
        }
      }
      writehtmlrowwithemph Pressure $emphasis $pressure "" "" "" $pressuretrend
    }

    putshtml "</table>"
    
  }

  proc writescheduler {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "scheduler"

    putshtml "</table>"

    putshtml "<table class=\"status\">"
    if {[string equal [client::getstatus "scheduler"] "ok"]} {
      writehtmlfullrow "Mode"              [client::getdata "scheduler" "mode"]
      writehtmlfullrow "Scheduler date"    [client::getdata "scheduler" "schedulerdate"]
      writehtmlfullrow "Block file"        [client::getdata "scheduler" "blockfile"]
      writehtmlfullrow "Alert file"        [client::getdata "scheduler" "alertfile"]
      writehtmlfullrow "Focused"           [formattimestamp [client::getdata "scheduler" "focustimestamp"]]
    }
    putshtml "</table>"

  }

  proc writeenclosure {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "enclosure"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "enclosure"] "ok"]} {
      writehtmlrow "Requested enclosure" [client::getdata "enclosure" "requestedenclosure"]
      writehtmlrow "Current enclosure" [client::getdata "enclosure" "enclosure"]
      if {[string equal [config::getvalue "enclosure" "type"] "arts"]} {
        writehtmlrow "Requested position" [client::getdata "enclosure" "requestedposition"]
        writehtmlrow "Mode" [client::getdata "enclosure" "mode"]
        writehtmlrow "Error flag" [client::getdata "enclosure" "errorflag"]
        writehtmlrow "Motor current flag" [client::getdata "enclosure" "motorcurrentflag"]
        writehtmlrow "Rain sensor flag" [client::getdata "enclosure" "rainsensorflag"]
        writehtmlrow "Safety rail flag" [client::getdata "enclosure" "safetyrailflag"]
        writehtmlrow "Emergency stop flag" [client::getdata "enclosure" "emergencystopflag"]
        writehtmlrow "Input channels" [client::getdata "enclosure" "inputchannels"]
        writehtmlrow "Output channels" [client::getdata "enclosure" "outputchannels"]
      }
    }
  
    putshtml "</table>"

  }

  proc writeexecutor {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "executor"

    putshtml "</table>"

    putshtml "<table class=\"status\">"
    if {[string equal [client::getstatus "executor"] "ok"]} {
      writehtmlfullrow "Block file"             [client::getdata "executor" "blockfile"]
      writehtmlfullrow "Project identifier"     [client::getdata "executor" "projectidentifier"]
      writehtmlfullrow "Block identifier"       [client::getdata "executor" "blockidentifier"]
      writehtmlfullrow "Visit identifier"       [client::getdata "executor" "visitidentifier"]
      writehtmlfullrow "Visit name"             [client::getdata "executor" "visitname"]
      writehtmlfullrow "Alert file"             [client::getdata "executor" "alertfile"]
      writehtmlfullrow "Alert type"             [client::getdata "executor" "alerttype"]
      writehtmlfullrow "Alert event identifier" [client::getdata "executor" "alerteventidentifier"]
      writehtmlfullrow "Alert event timestamp"  [formattimestamp [client::getdata "executor" "alerteventtimestamp"]]
      writehtmlrow "Alert coordinates" \
        [formatalphaifdouble [client::getdata "executor" "alertalpha"]] \
        [formatdeltaifdouble [client::getdata "executor" "alertdelta"]] \
        [formatifok "%.2f" [client::getdata "executor" "alertequinox"]]
      writehtmlfullrow "Alert uncertainty" \
        [formatarcsecifdouble "%.2fas" [client::getdata "executor" "alertuncertainty"]]
      writehtmlfullrow "Completed"     [client::getdata "executor" "completed"]
    }
    putshtml "</table>"

  }

  proc writefans {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "fans"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "fans"] "ok"]} {
      writehtmlrow "Requested fans" [client::getdata "fans" "requestedfans"]
      writehtmlrow "Current fans" [client::getdata "fans" "fans"]
    }
  
    putshtml "</table>"

  }

  proc writegcntan {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "gcntan"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "gcntan"] "ok"]} {
      writehtmlrow "Swift pointing (α,δ)" \
        [formatalphaifdouble [client::getdata "gcntan" "swiftalpha"]] \
        [formatdeltaifdouble [client::getdata "gcntan" "swiftdelta"] 1] \
        [formatifok "%.2f" [client::getdata "gcntan" "swiftequinox"]]
    
      writehtmlrow "Swift pointing (α,δ)"
    }
  
    putshtml "</table>"

  }

  proc writeheater {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "heater"

    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[string equal [client::getstatus "heater"] "ok"]} {
      writehtmlrow "Requested heater" [client::getdata "heater" "requestedheater"]
      writehtmlrow "Current heater" [client::getdata "heater" "heater"]
    } else {
      writehtmlrow "Requested heater"
      writehtmlrow "Current heater" 
    }
  
    putshtml "</table>"

  }

  proc writehtml {} {

    putshtml "<table class=\"status\">"

    writehtmlstatusblock "html"

    putshtml "</table>"

  }

  proc writeerror {} {
    writeinfo
  }

  proc writewarning {} {
    writeinfo
  }

  proc writesummary {} {
    writeinfo
  }  
    
  proc writeinfo {} {
  
    variable servers
    variable civiltimezone

    putshtml "<table class=\"status\">"
    set seconds [utcclock::seconds]
    set iseconds [expr {wide($seconds)}]
    set fseconds [expr {$seconds - $iseconds}]
    writehtmltimestampedrow "Current time (UTC)" [utcclock::combinedformat $seconds]
    set civiliseconds [clock scan [clock format $iseconds -timezone $civiltimezone -format "%Y-%m-%d %H:%M:%S"] -format "%Y-%m-%d %H:%M:%S"]
    set civilseconds [expr {$civiliseconds + $fseconds}]
    writehtmltimestampedrow "Current time (Civil)" [utcclock::combinedformat $civilseconds]
    putshtml "</table>"

    putshtml "<table class=\"status\">"

    if {[lsearch -exact $servers "supervisor"] != -1} {

      if {![string equal [client::getstatus "supervisor"] "ok"]} {
        set status "[client::getstatus "supervisor"]"
        set emph "error"
      } else {
        set status [client::getdata "supervisor" "mode"]
        if {[string equal $status "error"]} {
          set emph "error"
        } else {
          set emph ""
        }
      }
      writehtmlfullrowwithemph "Supervisor mode" $emph $status

      if {![string equal [client::getstatus "supervisor"] "ok"]} {
        set status "[client::getstatus "supervisor"]"
        set emph "error"
      } else {
        if {[client::getdata "supervisor" "maybeopen"]} {
          set status "may be open"
        } elseif {[client::getdata "supervisor" "maybeopentocool"]} {
          set status "may be open to cool"
        } else {
          set status "must be closed"
        }
        set why [client::getdata "supervisor" "why"]
        if {![string equal $why ""]} {
          set status "$status ($why)"
          set emph "warning"
        } else {
          set emph ""
        }
      }
      writehtmlfullrowwithemph "Supervisor" $emph $status
    }

    if {[lsearch -exact $servers "weather"] != -1} {

      if {![string equal [client::getstatus "weather"] "ok"]} {
        set text "[client::getstatus "weather"]"
        set emph "error"
      } else {
        if {[client::getdata "weather" "mustbeclosed"]} {
          set text "must be closed"
          set emph "warning"
        } else {
          set text "may be open"
          set emph ""
        }
        if {![string equal [client::getdata "weather" "windaveragespeed"] "unknown"]} {
          set text [format "%s (%.0f%% %s and %.0f km/h)" \
            $text \
            [expr {[client::getdata "weather" "humidity"] * 100}] \
            [client::getdata "weather" "humiditytrend"] \
            [client::getdata "weather" "windaveragespeed"]]
        } else {
          set text [format "%s (%.0f%% %s)" \
            $text \
            [expr {[client::getdata "weather" "humidity"] * 100}] \
            [client::getdata "weather" "humiditytrend"]]
        }
      }
      writehtmlfullrowwithemph "Weather" $emph $text
    }
    
    if {[lsearch -exact $servers "plc"] != -1} {
      if {![string equal [client::getstatus "plc"] "ok"]} {
        set text "[client::getstatus "plc"]"
        set emph "error"
      } else {
        if {[client::getdata "plc" "mustbeclosed"]} {
          set text "must be closed"
          set emph "warning"
        } else {
          set text "may be open"
          set emph ""
        }
      }
      writehtmlfullrowwithemph "PLC" $emph $text
    }

    if {[lsearch -exact $servers "sun"] != -1} {
      if {[string equal [client::getstatus "sun"] "ok"]} {
        set skystate [client::getdata "sun" "skystate"]
        writehtmlfullrow "Sky State" $skystate
        set seconds [utcclock::seconds]
        set startofdayseconds   [utcclock::scan [client::getdata "sun" "startofday"  ]]
        set endofdayseconds     [utcclock::scan [client::getdata "sun" "endofday"    ]]
        set startofnightseconds [utcclock::scan [client::getdata "sun" "startofnight"]]
        set endofnightseconds   [utcclock::scan [client::getdata "sun" "endofnight"  ]]
        if {[string equal $skystate "daylight"]} {
          writehtmlfullrow "End of day (UTC)" \
            "[utcclock::format $endofdayseconds     0] (in [utcclock::formattime [expr {$endofdayseconds     - $seconds}] 0])"
        } elseif {[string equal $skystate "night"]} {
          writehtmlfullrow "End of night (UTC)" \
          "[utcclock::format $endofnightseconds   0] (in [utcclock::formattime [expr {$endofnightseconds   - $seconds}] 0])"
        } elseif {$startofnightseconds < $startofdayseconds} {
          writehtmlfullrow "Start of night (UTC)" \
            "[utcclock::format $startofnightseconds 0] (in [utcclock::formattime [expr {$startofnightseconds - $seconds}] 0])"
        } else {
          writehtmlfullrow "Start of day (UTC)" \
            "[utcclock::format $startofdayseconds   0] (in [utcclock::formattime [expr {$startofdayseconds   - $seconds}] 0])"
        }
      } else {
        writehtmlfullrow "Sky State"
      }
    }

    if {[lsearch -exact $servers "shutters"] != -1} {
      if {[string equal [client::getstatus "shutters"] "ok"]} {
        set uppershutter [client::getdata "shutters" "uppershutter"]
        set lowershutter [client::getdata "shutters" "lowershutter"]
        if {[string equal "open" $lowershutter] && [string equal "open" $uppershutter]} {
          set shutters "open"
        } elseif {[string equal "closed" $lowershutter] && [string equal "closed" $uppershutter]} {
          set shutters "closed"
        } else {
          set shutters "intermediate"
        }
        writehtmlrow "Shutters" $shutters
      } else {
        writehtmlrow "Shutters"
      }
    }
    
    if {[lsearch -exact $servers "enclosure"] != -1} {
      if {[string equal [client::getstatus "enclosure"] "ok"]} {
        writehtmlrow "Enclosure" [client::getdata "enclosure" "enclosure"]
      } else {
        writehtmlrow "Enclosure" 
      }
    }

    if {[lsearch -exact $servers "covers"] != -1} {
      if {[string equal [client::getstatus "covers"] "ok"]} {
        writehtmlrow "Covers" [client::getdata "covers" "covers"]
      } else {
        writehtmlrow "Covers" 
      }
    }

    putshtml "</table>"

    putshtml "<table class=\"status\">"
    
    set serverprettynamedict {
      C0            {C0}
      C1            {C1}
      C2            {C2}
      C3            {C3}
      C4            {C4}
      C5            {C5}
      covers        {Covers}
      cryostat      {Cryostat}
      dome          {Dome}
      enclosure     {Enclosure}
      executor      {Executor}
      fans          {Fans}
      gcntan        {GCN/TAN}
      guider        {Guider}
      heater        {Heater}
      html          {HTML}
      power         {Power}
      inclinometers {Inclinometers}
      instrument    {Instrument}
      lights        {Lights}
      moon          {Moon}
      mount         {Mount}
      nefinder      {NE Finder}
      nwfinder      {NW Finder}
      plc           {PLC}
      secondary     {Secondary}
      sefinder      {SE Finder}
      scheduler     {Scheduler}
      sensors       {Sensors}
      shutters      {Shutters}
      sun           {Sun}
      supervisor    {Supervisor}
      target        {Target}
      telescope     {Telescope}
      weather       {Weather}
    }
    variable servers
    foreach server $servers {
      if {[lsearch -exact $servers $server] != -1} {
        writehtmlstatusline [dict get $serverprettynamedict $server] $server
      }
      set status [client::getstatus $server]
      variable lastserverstatus
      if {[dict exists $lastserverstatus $server]} {
        set laststatus [dict get $lastserverstatus $server]
        if {![string equal $status $laststatus]} {
          switch $status {
            "error" -
            "unknown" {
              log::error "status of $server server changed from \"$laststatus\" to \"$status\"."
            } 
            default {
              log::info "status of $server server changed from \"$laststatus\" to \"$status\"."
            }
          }
        }
      }
      dict set lastserverstatus $server [client::getstatus $server]
    }
    
    putshtml "</table>"

  }

  ######################################################################

  proc writehtmlloop {} {
  
    variable wwwdirectory
    variable servers
  
    while {true} {
    
      log::debug "updating data."

      foreach server $servers {
        if {[catch {client::update $server}]} {
          catch {client::update $server}
        }
      }
      server::setdata "timestamp" [utcclock::combinedformat now]
      server::setdata "activity" [server::getdata "requestedactivity"]
      server::setstatus "ok"

      log::debug "finished updating data."

      log::debug "writing HTML status files."

      foreach server [concat "info" "summary" "warning" "error" $servers] {
        coroutine::after 1
        set filename "$wwwdirectory/status/$server.html"
        if {[catch {
          openhtml "$filename.[pid]"
          write$server
          closehtml
          file rename -force -- "$filename.[pid]" "$filename"
        } message]} {
          log::warning "unable to generate HTML status file for \"$server\": $message"
        }
      }
      
      log::debug "finished writing HTML status log files."

      log::debug "writing HTML log files."

      file mkdir "$wwwdirectory/log/"
      
      set script [file join [directories::prefix] "lib" "tcs" "html-log.sh"]

      foreach server [concat "info" "summary" "warning" "error" $servers] {     

        coroutine::after 1

        set filename "$wwwdirectory/log/$server.html"

        if {[catch {
          exec "/bin/sh" "$script" "-p" "[directories::prefix]" "$server" >$filename.[pid]
        } message]} {
          log::warning "unable to generate HTML log file for \"$server\": $message"
          continue
        }

        file rename -force -- "$filename.[pid]" "$filename"
         
      }
      
      log::debug "finished writing HTML log files."

      coroutine::after 100

    }

  }

  ######################################################################

  set server::datalifeseconds 0

  proc start {} {
    server::setrequestedactivity "idle"
    after idle {
      coroutine ::server::writehtmlloopcoroutine html::writehtmlloop
    }
  }

}
