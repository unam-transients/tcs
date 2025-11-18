########################################################################

# This file is part of the UNAM telescope control system.

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

package require "alert"
package require "astrometry"
package require "config"
package require "fromjson"
package require "log"
package require "client"
package require "utcclock"
package require "server"

package provide "html" 0.0

namespace eval "html" {

  ######################################################################

  variable servers [concat \
    { "html" } \
    [config::getvalue "html" "servers"] \
    [config::getvalue "instrument" "monitoreddetectors"] \
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

variable htmlfilename
variable htmlchannel

proc openhtml {filename} {
  variable htmlfilename
  variable htmlchannel
  set htmlfilename $filename
  file mkdir [file dirname $htmlfilename]
  set htmlchannel [open "$htmlfilename.[pid]" "w"]
  chan configure $htmlchannel -translation "crlf"
  chan configure $htmlchannel -encoding "utf-8"
}

proc closehtml {} {
  variable htmlfilename
  variable htmlchannel
  close $htmlchannel
  file rename -force -- "$htmlfilename.[pid]" "$htmlfilename"
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

proc formatifdouble {formatstring value} {
  if {[string is double -strict $value]} {
    return [format $formatstring $value]
  } else {
    return $value
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
  if {[string is double -strict $offset]} {
    return [astrometry::formatoffset $offset]
  } else {
    return $offset
  }
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
    " -7" " &minus;7"
    " -8" " &minus;8"
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

proc writealarm {name value {disabled ""}} {
  if {[string equal $disabled ""]} {
    writehtmlrowwithemph $name  [alarmemph $value] $value
  } elseif {$disabled} {
    writehtmlrowwithemph $name  [alarmemph $value] $value "warning" "disabled"
  } else {
    writehtmlrowwithemph $name  [alarmemph $value] $value "" "enabled"
  }
}

proc bypassemph {alarm} {
  if {$alarm} {
    return "warning"
  } else {
    return ""
  }
}

proc writebypass {name value} {
  writehtmlrowwithemph $name  [bypassemph $value] $value
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
    writehtmlrow "Exposure time"                 [formatifok "%.3f s" [client::getdata $server "exposuretime"]]
    writehtmlfullrow "FITS file"                 [file tail [client::getdata $server "fitsfilename"]]
    if {![string equal "" [client::getdata $server "detectorreadmode"]]} {
      writehtmlfullrow "Detector read mode"            [client::getdata $server "detectorreadmode"]
    }
    if {![string equal "" [client::getdata $server "detectoradc"]]} {
      writehtmlrow "Detector ADC"                 "[client::getdata $server "detectoradc"]"
    }
    if {![string equal "" [client::getdata $server "detectoramplifier"]]} {
      writehtmlrow "Detector amplifier"           "[client::getdata $server "detectoramplifier"]"
    }
    if {![string equal "" [client::getdata $server "detectorvsspeed"]]} {
      writehtmlrow "Detector VS speed"            "[client::getdata $server "detectorvsspeed"]"
    }
    if {![string equal "" [client::getdata $server "detectorhsspeed"]]} {
      writehtmlrow "Detector HS speed"            "[client::getdata $server "detectorhsspeed"]"
    }
    if {![string equal "" [client::getdata $server "detectorgain"]]} {
      writehtmlrow "Detector gain"                "[client::getdata $server "detectorgain"]"
    }
    if {![string equal "" [client::getdata $server "detectoremgain"]]} {
      writehtmlrow "Detector EM gain"             "[client::getdata $server "detectoremgain"]"
    }
    if {![string equal "" [client::getdata $server "detectorframetime"]]} {
      writehtmlrow "Detector frame time" [format "%.1f ms" [expr {1e3 * [client::getdata $server "detectorframetime"]}]]
    }
    if {![string equal "" [client::getdata $server "detectorcycletime"]]} {
      writehtmlrow "Detector cycle time" [format "%.1f ms" [expr {1e3 * [client::getdata $server "detectorcycletime"]}]]
    }
    writehtmlrow "Detector software gain"        [formatifok "%d" [client::getdata $server "detectorsoftwaregain"]]
    writehtmlfullrow "Detector window"           [client::getdata $server "detectorunbinnedwindow"]
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
    writehtmlfullrow "Filter"                    [client::getdata $server "filter"]
    writehtmlrow "Filter wheel position"         [client::getdata $server "filterwheelposition"]
    writehtmlrow "Filter wheel maximum position" [client::getdata $server "filterwheelmaxposition"]
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
      [formatarcsecifdouble "%.2fas" [client::getdata $server "fwhm"]]
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
    if {![catch {client::getdata "covers" "primarycover"}]} {
      set cover [client::getdata "covers" "primarycover"]
      writehtmlrow "Current primary cover" $cover
    }
    if {![catch {client::getdata "covers" "portnames"}]} {
      foreach portname [client::getdata "covers" "portnames"] {
        writehtmlrow "Current $portname cover" [client::getdata "covers" "${portname}cover"]
      }
    }
  }

  putshtml "</table>"

}

proc writedome {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "dome"

  putshtml "</table>"

  putshtml "<table class=\"status\">"

  if {[string equal [client::getstatus "dome"] "ok"]} {
    writehtmlrow "Requested shutters"             [client::getdata "dome" "requestedshutters"]
    writehtmlrow "Current shutters"               [client::getdata "dome" "shutters"]
    writehtmlrow "Requested azimuth"              [formatradtodegifdouble "%.1f°" [client::getdata "dome" "requestedazimuth"]]
    writehtmlrow "Current azimuth"                [formatradtodegifdouble "%.1f°" [client::getdata "dome" "azimuth"]]
    writehtmlrow "Current azimuth error"          [formatradtodegifdouble "%+.1f°" [client::getdata "dome" "azimutherror"]]
    writehtmlrow "Maximum absolute azimuth error" [formatradtodegifdouble "%+.1f°" [client::getdata "dome" "maxabsazimutherror"]]
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
    writehtmlrow "Observed rate (A,z)" \
      [formatrateifdouble [client::getdata "target" "observedazimuthrate"]] \
      [formatrateifdouble [client::getdata "target" "observedzenithdistancerate"]]
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

proc writelouvers {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "louvers"

  putshtml "</table>"

  putshtml "<table class=\"status\">"

  if {[string equal [client::getstatus "louvers"] "ok"]} {

    set mustbeclosed [client::getdata "louvers" "mustbeclosed"]
    if {![string equal "" $mustbeclosed] && $mustbeclosed} {
      set emph "warning"
    } else {
      set emph ""
    }
    writehtmlrow "Mode" [client::getdata "louvers" "mode"]
    writehtmlrow "Requested louvers" [client::getdata "louvers" "requestedlouvers"]
    writehtmlrow "Current louvers" [client::getdata "louvers" "louvers"]
    foreach louver [client::getdata "louvers" "activelouvers"] {
      writehtmlrow "Current louver$louver" [client::getdata "louvers" "louver$louver"]
    }
    writehtmlfullrowwithemph "Must be closed" $emph [client::getdata "louvers" "mustbeclosed"]
    writehtmlrow "External temperature" [formatifdouble "%+.1f C" [client::getdata "louvers" "externaltemperature"]]
    writehtmlrow "Internal temperature" [formatifdouble "%+.1f C" [client::getdata "louvers" "internaltemperature"]]
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

proc writewatchdog {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "watchdog"

  putshtml "</table>"

  putshtml "<table class=\"status\">"

  writehtmlrow "Enabled" [client::getdata "watchdog" "enabled"]
  writehtmlfullrow "Problem servers" [join [client::getdata "watchdog" "problemservers"] " "]
  set problemtimestamp [client::getdata "watchdog" "problemtimestamp"]
  if {[string equal "" $problemtimestamp]} {
    writehtmlfullrow "Problems since" ""
  } else {
    set timestamp [utcclock::format $problemtimestamp 0]
    set interval [utcclock::formatinterval [utcclock::diff now $problemtimestamp] false]
    writehtmlfullrow "Problems since" "$timestamp ($interval ago)"
  }

  putshtml "</table>"

}



proc writetelescopecontroller {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "telescopecontroller"

  putshtml "</table>"

  putshtml "<table class=\"status\">"

  if {[string equal [client::getstatus "telescopecontroller"] "ok"]} {
    if {[string equal "operational" [client::getdata "telescopecontroller" "errorstate"]]} {
      writehtmlfullrow "Error state"     [client::getdata "telescopecontroller" "errorstate"]
    } elseif {[string equal "warning" [client::getdata "telescopecontroller" "errorstate"]]} {
      writehtmlfullrowwithemph "Error state" "warning" [client::getdata "telescopecontroller" "errorstate"]
    } else {
      writehtmlfullrowwithemph "Error state" "error" [client::getdata "telescopecontroller" "errorstate"]
    }
    writehtmlfullrow "Ready state"     [client::getdata "telescopecontroller" "readystate"]
    writehtmlrow "Ambient temperature" [formatifok "%.1f C"    [client::getdata "telescopecontroller" "ambienttemperature"]]
    writehtmlrow "Ambient pressure"    [formatifok "%.1f mbar" [client::getdata "telescopecontroller" "ambientpressure"   ]]
  }

  putshtml "</table>"

}

proc writeplc {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "plc"

  putshtml "</table>"

  putshtml "<table class=\"status\">"

  set type [config::getvalue "plc" "type"]

  if {[string equal [client::getstatus "plc"] "ok"]} {
    switch $type {
      "colibri" {

        writehtmlfullrow "Mode"                      [client::getdata "plc" "mode"]
        writehtmlrow     "Safety delay"              [format "%d s" [client::getdata "plc" "unsafeseconds"]]

        writealarm       "Must not operate"          [client::getdata "plc" "mustnotoperate"]
        writealarm       "Must be closed"            [client::getdata "plc" "mustbeclosed"]
        writehtmlrow     "Key switch"                [client::getdata "plc" "keyswitch"]
        writehtmlrow     "Local confirmation"        [client::getdata "plc" "localconfirmation"]
        writehtmlrow     "Access requested"          [client::getdata "plc" "accessrequested"]

        writehtmlfullrow "Telescope cabinet power"   [client::getdata "plc" "telescopecabinetpower"]
        writehtmlfullrow "Requested telescope mode"  [client::getdata "plc" "requestedtelescopemode"]
        writehtmlfullrow "Telescope mode"            [client::getdata "plc" "telescopemode"]
        writehtmlfullrow "Dome mode"                 [client::getdata "plc" "domemode"]

        writehtmlfullrow "Requested park"            [client::getdata "plc" "requestedpark"]
        writehtmlfullrow "Requested close shutters"  [client::getdata "plc" "requestedclose"]

        writealarm   "Rain alarm"                    [client::getdata "plc" "rainalarm"                    ] [client::getdata "plc" "rainalarmdisabled"]
        writealarm   "Wind alarm"                    [client::getdata "plc" "windalarm"                    ] [client::getdata "plc" "windalarmdisabled"]
        writealarm   "Cloud alarm"                   [client::getdata "plc" "cloudalarm"                   ] [client::getdata "plc" "cloudalarmdisabled"]
        writealarm   "Humidity alarm"                [client::getdata "plc" "humidityalarm"                ] [client::getdata "plc" "humidityalarmdisabled"]
        writealarm   "Daylight alarm"                [client::getdata "plc" "daylightalarm"                ] [client::getdata "plc" "daylightalarmdisabled"]
        writealarm   "UPS alarm"                     [client::getdata "plc" "upsalarm"                     ] [client::getdata "plc" "upsalarmdisabled"]
        writealarm   "TCS alarm"                     [client::getdata "plc" "tcsalarm"                     ] [client::getdata "plc" "tcsalarmdisabled"]
        writealarm   "Emergency stop alarm"          [client::getdata "plc" "emergencystopalarm"           ] [client::getdata "plc" "emergencystopalarmdisabled"]
        writealarm   "Intrusion alarm"               [client::getdata "plc" "intrusionalarm"               ] [client::getdata "plc" "intrusionalarmdisabled"]
        writealarm   "RIO communication alarm"       [client::getdata "plc" "riocommunicationalarm"        ] [client::getdata "plc" "riocommunicationalarmdisabled"]
        writealarm   "Vaisala communication alarm"   [client::getdata "plc" "riovaisalacommunicationalarm" ] [client::getdata "plc" "riovaisalacommunicationalarmdisabled"]
        writealarm   "Boltwood communication alarm"  [client::getdata "plc" "rioboltwoodcommunicationalarm"] [client::getdata "plc" "rioboltwoodcommunicationalarmdisabled"]

        writealarm   "Vaisala rain alarm"            [client::getdata "plc" "vaisalarainalarm"]
        writealarm   "Boltwood rain alarm"           [client::getdata "plc" "boltwoodrainalarm"]
        writealarm   "Blet rain alarm"               [client::getdata "plc" "bletrainalarm"]

        catch {
          writehtmlrow "OAN wind average speed" \
            [formatifok "%.0f km/h" [client::getdata "sensors" "oan-wind-average-speed"]]
          writehtmlrow "OAN wind gust speed" \
            [formatifok "%.0f km/h" [client::getdata "sensors" "oan-wind-gust-speed"]]
        }
        writehtmlrow "Vaisala wind average speed" \
          [formatifok "%.0f km/h" [client::getdata "plc" "vaisalawindaveragespeed"]]
        writehtmlrow "Vaisala wind gust speed" \
          [formatifok "%.0f km/h" [client::getdata "plc" "vaisalawindmaxspeed"]]
        writehtmlrow "Boltwood wind speed" \
          [formatifok "%.0f km/h" [client::getdata "plc" "boltwoodwindspeed"]]
        writehtmlrow "Wind speed limit" \
          [formatifok "%.0f km/h" [client::getdata "plc" "windspeedlimit"]]

        writehtmlrow "PLC cabinet temperature"       [format "%+.1f C" [client::getdata "plc" "plccabinettemperature"]]
        writehtmlrow "Weather cabinet temperature"   [format "%+.1f C" [client::getdata "plc" "weathercabinettemperature"]]
        writehtmlrow "Seeing cabinet temperature"    [format "%+.1f C" [client::getdata "plc" "seeingcabinettemperature"]]

        writehtmlrow "American UPS battery charge level"   [format "%.0f%%" [expr {[client::getdata "plc" "americanupsbatterychargelevel"] * 100}]]
        writehtmlrow "European UPS battery charge level"   [format "%.0f%%" [expr {[client::getdata "plc" "europeanupsbatterychargelevel"] * 100}]]

      }
    }
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
    writehtmlrow "Mode"                     [client::getdata "supervisor" "mode"]
    writehtmlrow "May be open"              [client::getdata "supervisor" "maybeopen"]
    writehtmlrow "May be open to ventilate" [client::getdata "supervisor" "maybeopentoventilate"]
    writehtmlrow "Must not operate"         [client::getdata "supervisor" "mustnotoperate"]
    writehtmlrow "Open"                     [client::getdata "supervisor" "open"]
    writehtmlrow "Open to ventilate"        [client::getdata "supervisor" "opentoventilate"]
    writehtmlrow "Closed"                   [client::getdata "supervisor" "closed"]
    writehtmlfullrow "Why"                  [client::getdata "supervisor" "why"]
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


    writehtmlrow "Requested standard position (α,HA,δ)" \
      [formatalphaifdouble [client::getdata "mount" "requestedstandardalpha"]] \
      "" \
      [formatdeltaifdouble [client::getdata "mount" "requestedstandarddelta"]]
    writehtmlrow "Requested standard rate (α,δ)" \
      [formatrateifdouble [client::getdata "mount" "requestedstandardalpharate"]] \
      "" \
      [formatrateifdouble [client::getdata "mount" "requestedstandarddeltarate"]]
    writehtmlrow "Requested standard equinox" \
      [formatifok "%.2f" [client::getdata "mount" "requestedstandardequinox"]]

    writehtmlrow "Requested observed position (α,HA,δ)" \
      [formatalphaifdouble [client::getdata "mount" "requestedobservedalpha"]] \
      [formathaifdouble    [client::getdata "mount" "requestedobservedha"]] \
      [formatdeltaifdouble [client::getdata "mount" "requestedobserveddelta"]]
    writehtmlrow "Requested observed rate (α,δ)" \
      [formatrateifdouble [client::getdata "mount" "requestedobservedalpharate"]] \
      "" \
      [formatrateifdouble [client::getdata "mount" "requestedobserveddeltarate"]]
    writehtmlrow "Requested observed position (A,z)" \
      [formatradtodegifdouble "%.2f°" [client::getdata "mount" "requestedobservedazimuth"]] \
      [formatradtodegifdouble "%.2f°" [client::getdata "mount" "requestedobservedzenithdistance"]]

    if {![string equal "" [client::getdata "mount" "port"]]} {
      writehtmlrow "Requested port" \
        [client::getdata "mount" "requestedport"] \
        [client::getdata "mount" "requestedportposition"]
    }
    writehtmlrow "Requested mount rotation" \
      [formatradtodegifdouble "%.2f°"  [client::getdata "mount" "requestedmountrotation"]]
    writehtmlrow "Requested mount position (α,HA,δ)" \
      [formatalphaifdouble [client::getdata "mount" "requestedmountalpha"]] \
      [formathaifdouble    [client::getdata "mount" "requestedmountha"]] \
      [formatdeltaifdouble [client::getdata "mount" "requestedmountdelta"]]
    writehtmlrow "Requested mount rate (α,δ)" \
      [formatrateifdouble [client::getdata "mount" "requestedmountalpharate"]] \
      "" \
      [formatrateifdouble [client::getdata "mount" "requestedmountdeltarate"]]

    if {![string equal "" [client::getdata "mount" "port"]]} {
      writehtmlrow "Current port" \
        [client::getdata "mount" "port"] \
        [client::getdata "mount" "portposition"]
    }
    writehtmlrow "Current mount rotation" \
      [formatradtodegifdouble "%.2f°"  [client::getdata "mount" "mountrotation"]]
    writehtmlrow "Current mount position (α,HA,δ)" \
      [formatalphaifdouble [client::getdata "mount" "mountalpha"]] \
      [formathaifdouble    [client::getdata "mount" "mountha"]] \
      [formatdeltaifdouble [client::getdata "mount" "mountdelta"]]

    writehtmlrow "Current mount position (A,z,derotator)" \
      [formatradtodegifdouble "%.2f°" [client::getdata "mount" "mountazimuth"]] \
      [formatradtodegifdouble "%.2f°" [client::getdata "mount" "mountzenithdistance"]] \
      [formatradtodegifdouble "%+.2f°" [client::getdata "mount" "mountderotatorangle"]]

    if {[string equal [client::getdata "mount" "configuration"] "equatorial"]} {

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

    }

    writehtmlrow "Unparked" \
      [client::getdata "mount" "unparked"]

    writehtmlrow "Pupil tracking" \
      [client::getdata "mount" "pupiltracking"]
  
    writehtmltimestampedrow "Last correction" \
      [client::getdata "mount" "lastcorrectiontimestamp"]
    writehtmlrow "Last correction (α,δ)" \
      [formatoffsetifdouble [client::getdata "mount" "lastcorrectiondalpha"]] \
      "" \
      [formatoffsetifdouble [client::getdata "mount" "lastcorrectionddelta"]]
    writehtmlfullrow "Tracking remaining" \
      [formatifdouble "%.0f seconds" [client::getdata "mount" "remainingtrackingseconds"]]
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
    writehtmlfullrow "Monitored detectors" [join [client::getdata "instrument" "monitoreddetectors"]]
    writehtmlfullrow "Active detectors" [join [client::getdata "instrument" "activedetectors"]]
    writehtmlfullrow "Active focusers" [join [client::getdata "instrument" "activefocusers"]]
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
      set current [client::getdata "power" "$host-current"]
      if {![string equal "" $current]} {
        writehtmlfullrow "Host $host current" [format "%.1f A" $current]
      }
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
    if {![catch {client::getdata "secondary" "state"}]} {
      writehtmlrow "State" [client::getdata "secondary" "state"]
    }
    writehtmlrow "Requested position (z0)" [formatifok "%d" [client::getdata "secondary" "requestedz0"]]
    writehtmlfullrow "Temperature sensor " [client::getdata "secondary" "temperaturesensor"]
    writehtmlrow "Temperature" [formatifok "%+.1f C" [client::getdata "secondary" "temperature"]]
    writehtmlrow "Temperature correction " [formatifok "%+d" [client::getdata "secondary" "dztemperature"]]
    writehtmlrow "Position correction" [formatifok "%+d" [client::getdata "secondary" "dzposition"]]
    writehtmlrow "Filter correction" [formatifok "%+d" [client::getdata "secondary" "dzfilter"]]
    writehtmlrow "Offset" [formatifok "%+d" [client::getdata "secondary" "dzoffset"]]
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

    set referencetemperaturename [config::getvalue "sensors" "environmental-sensor-reference"]
    if {![string equal $referencetemperaturename ""]} {
      set referencetemperature [client::getdata "sensors" $referencetemperaturename]
    }

    foreach name [dict keys $sensors] {
      if {[catch {
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
          set group [dict get $sensors $name "group"]
          switch -glob "$name:$unit:$group" {
            *-temperature:C:environmental-temperature {
              if {[string equal $referencetemperaturename ""]} {
                writehtmlfullrowwithemph $name $emphasis "$timestamp [format "%+4.1f C" $value]"
              } elseif {[string equal $name $referencetemperaturename]} {
                writehtmlfullrowwithemph $name $emphasis "$timestamp [format "%+4.1f C" $value] reference"
              } else {
                set difference [expr {$value - $referencetemperature}]
                writehtmlfullrowwithemph $name $emphasis "$timestamp [format "%+5.1f C" $value] [format "%+5.1f C" $difference]"
              }
            }
            *-temperature:C:* {
              writehtmlfullrowwithemph $name $emphasis "$timestamp [format "%+5.1f C" $value]"
            }
            *-detector-cooler-power::* -
            *-humidity::* -
            *-light-level::* -
            *-charge-level::* -
            *-disk-space-used::* {
              writehtmlfullrowwithemph $name $emphasis "$timestamp [format "%.0f%%" [expr {$value * 100}]]"
            }
            *::* {
              writehtmlfullrowwithemph $name $emphasis "$timestamp $value"
            }
            default {
              writehtmlfullrowwithemph $name $emphasis "$timestamp $value $unit"
            }
          }
        }
      }]} {
        writehtmlfullrowwithemph $name "warning" ""
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
  }

  putshtml "</table>"

}

proc writeweather {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "weather"

  putshtml "</table>"

  putshtml "<table class=\"status\">"

  if {[string equal [client::getstatus "weather"] "ok"]} {
    writealarm "Must be closed" [client::getdata "weather" "mustbeclosed"]
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
      writehtmlrowwithemph "Wind average speed" "warning" "unknown"
    }
    if {![string equal [client::getdata "weather" "windgustspeed"] "unknown"]} {
      writehtmlrow "Wind gust speed" \
        [format "%.0f km/h" [client::getdata "weather" "windgustspeed"]] \
        [format "%.1f m/s" [expr {[client::getdata "weather" "windgustspeed"] / 3.6}]]
    } else {
      writehtmlrowwithemph "Wind gust speed" "warning" "unknown"
    }
    if {![string equal [client::getdata "weather" "windaverageazimuth"] "unknown"]} {
      writehtmlrow "Wind average azimuth" \
        [formatradtodegifdouble "%.1f°" [client::getdata "weather" "windaverageazimuth"]]
    } else {
      writehtmlrowwithemph "Wind average azimuth" "warning" "unknown"
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
    if {![string equal [client::getdata "weather" "skytemperature"] "unknown"]} {
      writehtmlrow "Sky temperature" \
        [format "%+.1f C" [client::getdata "weather" "skytemperature"]] \
        [client::getdata "weather" "skytemperaturetrend"]
    } else {
      writehtmlrow "Sky temperature"
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
    writealarm   "Humidity alarm" [client::getdata "weather" "humidityalarm"]
    writealarm   "Wind alarm"     [client::getdata "weather" "windalarm"]
    writealarm   "Rain alarm"     [client::getdata "weather" "rainalarm"]
  }

  putshtml "</table>"

}

proc writeseeing {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "seeing"

  putshtml "</table>"

  putshtml "<table class=\"status\">"

  if {[string equal [client::getstatus "seeing"] "ok"]} {

    set seeing    [client::getdata "seeing" "seeing"]
    set flux      [client::getdata "seeing" "flux"]
    set timestamp [client::getdata "seeing" "timestamp"]
    set diff      [format "%.0f" [utcclock::diff now $timestamp]]

    if {$diff > 600} {
      set emphasis "warning"
      set seeing "stale"
      set flux   "stale"
    } else {
      set emphasis ""
    }
    writehtmlfullrowwithemph "Seeing" $emphasis "[utcclock::format $timestamp] [formatarcsecifdouble "%.2fas" $seeing]"
    writehtmlfullrowwithemph "Flux"   $emphasis "[utcclock::format $timestamp] [formatifdouble "%.0f" $flux]"

  }

  putshtml "</table>"

}

proc writeselector {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "selector"

  putshtml "</table>"

  putshtml "<table class=\"status\">"
  if {[string equal [client::getstatus "selector"] "ok"]} {
    writehtmlfullrow "Mode"              [client::getdata "selector" "mode"]
    writehtmlfullrow "File type"         [client::getdata "selector" "filetype"]
    writehtmlfullrow "File name"         [client::getdata "selector" "filename"]
    writehtmlfullrow "Priority"          [client::getdata "selector" "priority"]
    writehtmlfullrow "Focused"           [formattimestamp [client::getdata "selector" "focustimestamp"]]
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
      writehtmlfullrow "Input channels" [client::getdata "enclosure" "inputchannels"]
      writehtmlfullrow "Output channels" [client::getdata "enclosure" "outputchannels"]
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
    writehtmlfullrow "File type"              [client::getdata "executor" "filetype"]
    writehtmlfullrow "File name"              [client::getdata "executor" "filename"]
    writehtmlfullrow "Project identifier"     [client::getdata "executor" "projectidentifier"]
    writehtmlfullrow "Block identifier"       [client::getdata "executor" "blockidentifier"]
    writehtmlfullrow "Visit identifier"       [client::getdata "executor" "visitidentifier"]
    writehtmlfullrow "Visit name"             [client::getdata "executor" "visitname"]
    writehtmlfullrow "Alert origin"           [client::getdata "executor" "alertorigin"]
    writehtmlfullrow "Alert identifier"       [client::getdata "executor" "alertidentifier"]
    writehtmlfullrow "Alert type"             [client::getdata "executor" "alerttype"]
    writehtmlfullrow "Alert event timestamp"  [formattimestamp [client::getdata "executor" "alerteventtimestamp"]]
    writehtmlfullrow "Alert alert timestamp"  [formattimestamp [client::getdata "executor" "alertalerttimestamp"]]
    writehtmlrow "Alert coordinates" \
      [formatalphaifdouble [client::getdata "executor" "alertalpha"]] \
      [formatdeltaifdouble [client::getdata "executor" "alertdelta"]] \
      [formatifok "%.2f" [client::getdata "executor" "alertequinox"]]
    writehtmlfullrow "Alert uncertainty" \
      [formatarcsecifdouble "%.2fas" [client::getdata "executor" "alertuncertainty"]]
    writehtmlfullrow "Completed"             [client::getdata "executor" "completed"]
    writehtmlfullrow "Alert priority"        [client::getdata "executor" "alertpriority"]
  }
  putshtml "</table>"

}

proc writefans {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "fans"

  putshtml "</table>"

  putshtml "<table class=\"status\">"

  if {[string equal [client::getstatus "fans"] "ok"]} {
    set mustbeoff [client::getdata "fans" "mustbeoff"]
    if {![string equal "" $mustbeoff] && $mustbeoff} {
      set emph "warning"
    } else {
      set emph ""
    }
    writehtmlrow "Mode" [client::getdata "fans" "mode"]
    writehtmlrow "Requested fans" [client::getdata "fans" "requestedfans"]
    writehtmlrow "Current fans" [client::getdata "fans" "fans"]
    writehtmlfullrowwithemph "Must be off" $emph [client::getdata "fans" "mustbeoff"]
  }

  putshtml "</table>"

}

proc writegcn {} {

  putshtml "<table class=\"status\">"

  writehtmlstatusblock "gcn"

  putshtml "</table>"

  putshtml "<table class=\"status\">"
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
  } else {
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
      } elseif {[client::getdata "supervisor" "maybeopentoventilate"]} {
        set status "may be open to ventilate"
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

  if {[lsearch -exact $servers "plc"] != -1} {

    if {![string equal [client::getstatus "plc"] "ok"]} {
      set value "[client::getstatus "plc"]"
      set emph "error"
    } else {
      set value [client::getdata "plc" "mode"]
      set emph ""
    }
    writehtmlfullrowwithemph "PLC mode" $emph $value

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

  if {[lsearch -exact $servers "seeing"] != -1} {

    if {[string equal [client::getstatus "seeing"] "ok"]} {

      set seeing    [client::getdata "seeing" "seeing"]
      set timestamp [client::getdata "seeing" "timestamp"]
      set diff      [format "%.0f" [utcclock::diff now $timestamp]]

      if {$diff > 600} {
        set emphasis "warning"
        set seeing "stale"
      } else {
        set emphasis ""
      }
      writehtmlfullrowwithemph "Seeing" $emphasis "[formatarcsecifdouble "%.2fas" $seeing]"

    }

  }

  if {false} {
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

  if {[lsearch -exact $servers "dome"] != -1} {
    set internalhumiditysensor [config::getvalue "supervisor" "internalhumiditysensor"]
    if {[string equal $internalhumiditysensor ""]} {
      set internalhumidity ""
    } else {
      set internalhumidity [formatpercentifok "%.0f%%" [client::getdata "sensors" $internalhumiditysensor]]
    }
    if {![string equal [client::getstatus "dome"] "ok"]} {
      writehtmlfullrow "Dome"
    } else {
      set shutters [client::getdata "dome" "shutters"]
      if {[string equal "$internalhumidity" ""]} {
        writehtmlfullrow "Dome" "$shutters"
      } else {
        writehtmlfullrow "Dome" "$shutters ($internalhumidity)"
      }
    }
  }

  if {[lsearch -exact $servers "enclosure"] != -1} {
    set internalhumiditysensor [config::getvalue "supervisor" "internalhumiditysensor"]
    if {[string equal $internalhumiditysensor ""]} {
      set internalhumidity ""
    } else {
      set internalhumidity [formatpercentifok "%.0f%%" [client::getdata "sensors" $internalhumiditysensor]]
    }
    if {![string equal [client::getstatus "enclosure"] "ok"]} {
      writehtmlfullrow "Enclosure"
    } elseif {[string equal "$internalhumidity" ""]} {
      writehtmlfullrow "Enclosure" [client::getdata "enclosure" "enclosure"]
    } else {
      writehtmlfullrow "Enclosure" "[client::getdata "enclosure" "enclosure"] ($internalhumidity)"
    }
  }

  if {[lsearch -exact $servers "louvers"] != -1} {
    if {[string equal [client::getstatus "louvers"] "ok"]} {
      writehtmlfullrow "Louvers" [client::getdata "louvers" "louvers"]
    } else {
      writehtmlfullrow "Louvers"
    }
  }

  if {[lsearch -exact $servers "fans"] != -1} {
    if {[string equal [client::getstatus "fans"] "ok"]} {
      writehtmlfullrow "Fans" [client::getdata "fans" "fans"]
    } else {
      writehtmlfullrow "Fans"
    }
  }

  if {[lsearch -exact $servers "covers"] != -1} {
    if {[string equal [client::getstatus "covers"] "ok"]} {
      writehtmlfullrow "Covers" [client::getdata "covers" "covers"]
    } else {
      writehtmlfullrow "Covers"
    }
  }

  putshtml "</table>"

  putshtml "<table class=\"status\">"

  set serverprettynamedict {
    C0                  {C0}
    C1                  {C1}
    C2                  {C2}
    C3                  {C3}
    C4                  {C4}
    C5                  {C5}
    covers              {Covers}
    dome                {Dome}
    enclosure           {Enclosure}
    executor            {Executor}
    fans                {Fans}
    gcn                 {GCN}
    gcntan              {GCN/TAN}
    heater              {Heater}
    html                {HTML}
    telescopecontroller {Telescope Controller}
    power               {Power}
    instrument          {Instrument}
    lights              {Lights}
    louvers             {Louvers}
    moon                {Moon}
    mount               {Mount}
    watchdog            {Watchdog}
    plc                 {PLC}
    seeing              {Seeing}
    secondary           {Secondary}
    selector            {Selector}
    sensors             {Sensors}
    shutters            {Shutters}
    sun                 {Sun}
    supervisor          {Supervisor}
    target              {Target}
    telescope           {Telescope}
    weather             {Weather}
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

  set pollmilliseconds 1000

  while {true} {

    log::debug "updating data."

    set startmilliseconds [utcclock::milliseconds]

    foreach server $servers {
      log::debug "updating data for $server."
      if {[catch {client::update $server}]} {
        catch {client::update $server}
      }
    }
    server::setdata "timestamp" [utcclock::combinedformat now]
    server::setdata "activity" [server::getdata "requestedactivity"]
    server::setstatus "ok"

    log::debug "finished updating data."

    log::debug "writing status files."

    foreach server [concat "info" "summary" "warning" "error" $servers] {
      coroutine::after 1
      if {[catch {
        openhtml "$wwwdirectory/status/$server.html"
        write$server
        closehtml
      } message]} {
        log::warning "unable to generate status file for \"$server\": $message"
      }
    }

    log::debug "finished writing status log files."

    log::debug "writing log files."

    file mkdir "$wwwdirectory/log/"

    set script [file join [directories::prefix] "lib" "tcs" "html-log.sh"]

    foreach server [concat "info" "summary" "warning" "error" "gcn" $servers] {

      coroutine::after 1

      set filename "$wwwdirectory/log/$server.html"

      if {[catch {
        exec "/bin/sh" "$script" "-p" "[directories::prefix]" "$server" >$filename.[pid]
      } message]} {
        log::warning "unable to generate log file for \"$server\": $message"
        continue
      }

      file rename -force -- "$filename.[pid]" "$filename"

    }

    log::debug "finished writing log files."

    set endmilliseconds [utcclock::milliseconds]
    set durationmilliseconds [expr {$endmilliseconds - $startmilliseconds}]
    if {$durationmilliseconds < $pollmilliseconds} {
      coroutine::after [expr {int($pollmilliseconds - $durationmilliseconds)}]
    }

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

######################################################################

}
