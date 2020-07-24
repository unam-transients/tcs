########################################################################

# This file is part of the UNAM telescope control system.

# $Id: utcclock.tcl 3595 2020-06-10 16:38:40Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "utcclock" 0.0

namespace eval "utcclock" {

  variable svnid {$Id: utcclock.tcl 3595 2020-06-10 16:38:40Z Alan $}

  ######################################################################

  variable resolution
  variable precision

  if {[catch {clock milliseconds}]} {
    set resolution 1.0
    set precision 0
  } else {
    set resolution 1.0e-3
    set precision 3
  }

  proc getresolution {} {
    variable resolution
    return $resolution
  }

  proc getprecision {} {
    variable precision
    return $precision
  }

  ######################################################################

  proc seconds {} {
    variable resolution
    if {$resolution == 1.0} {
      set seconds [expr {double([clock seconds])}]
    } else {
      set seconds [expr {[clock milliseconds] * 1e-3}]
    }
    return $seconds
  }

  proc mjd {{seconds "now"}} {
    if {[string equal $seconds now]} {
      set seconds [seconds]
    }
    # We rely on the absence of leap seconds.
    set epochmjd 40587.0
    expr {$seconds / (24.0 * 60.0 * 60.0) + $epochmjd}
  }

  proc jd {{seconds "now"}} {
    if {[string equal $seconds now]} {
      set seconds [seconds]
    }
    # We rely on the absence of leap seconds.
    set epochjd 2440587.5
    expr {$seconds / (24.0 * 60.0 * 60.0) + $epochjd}
  }
  
  proc epoch {{seconds "now"}} {
    # See Lieske (1979, A&A, 73, 282).
    set jd [jd $seconds]
    return [expr {2000.0 + ($jd - 2451545.0) / 365.25}]
  }

  ######################################################################

  proc generalformat {seconds precision format} {
    if {[string equal $seconds now]} {
      set seconds [seconds]
    } elseif {![string is double -strict $seconds]} {
      set seconds [scan $seconds]
    }    
    set iseconds [expr {int(floor($seconds))}]
    set fseconds [expr {$seconds - $iseconds}]
    set fscale   [expr {pow(10,$precision)}]
    set fdigits [expr {int(floor($fseconds * $fscale))}]
    if {$fdigits == $fscale} {
      set iseconds [expr {$iseconds + 1}]
      set fdigits 0
    }
    set itext [clock format $iseconds -format $format -gmt true]
    if {$precision == 0} {
      set ftext ""
    } else {
      set ftext [::format ".%0*d" $precision $fdigits]
    }
    set text "$itext$ftext"
    return $text
  }

  proc format {{seconds "now"} {precision 3} {extended true}} {
    if {$extended} {
      generalformat $seconds $precision "%Y-%m-%d %H:%M:%S"
    } else {
      generalformat $seconds $precision "%Y%m%d %H%M%S"
    }
  }

  proc combinedformat {{seconds "now"} {precision 3} {extended true}} {
    if {$extended} {
      generalformat $seconds $precision "%Y-%m-%dT%H:%M:%S"
    } else {
      generalformat $seconds $precision "%Y%m%dT%H%M%S"
    }
  }

  proc formatdate {{seconds "now"} {extended true}} {
    if {$extended} {
      generalformat $seconds 0 "%Y-%m-%d"
    } else {
      generalformat $seconds 0 "%Y%m%d"
    }
  }

  proc formattime {{seconds "now"} {precision 3} {extended true}} {
    if {$extended} {
      generalformat $seconds $precision "%H:%M:%S"
    } else {
      generalformat $seconds $precision "%H%M%S"
    }
  }
  
  proc formatinterval {seconds} {
    if {$seconds < 60} {
      return [::format "%.1f seconds" $seconds]
    } elseif {$seconds < 3600} {
      return [::format "%.1f seconds (%.1f minutes)" $seconds [expr {$seconds / 60}]]
    } else {
      return [::format "%.1f seconds (%.1f hours)" $seconds [expr {$seconds / 3600}]]
    }
  }

  ######################################################################

  proc scaninterval {interval} {
    if {[string is double -strict $interval]} {
      set newinterval $interval
    } elseif {[::scan $interval "%f%\[hms\]" value unit] == 2} {
      switch -nocase $unit {
        "h" {
          set newinterval [expr {$value * 3600}]
        }
        "m" {
          set newinterval [expr {$value * 60}]
        }
        "s" {
          set newinterval $value
        }
        default {
          error "invalid interval: \"$interval\"."
        }
      }
    } elseif {[::scan $interval "%d%*\[^0-9\]%d%*\[^0-9\]%f" d0 d1 d2] == 3} {
      if {$d1 < 0 || $d1 >= 60 || $d2 < 0 || $d2 >= 60} {
        error "invalid interval: \"$interval\"."
      }
      set value [expr {abs($d0) * 3600 + $d1 * 60 + $d0}]
      ::scan $interval "%1s" sign
      if {[string equal $sign "-"]} {
        set value [expr {-$value}]
      }
      set newinterval $value
    } else {
      error "invalid interval: \"$interval\"."
    }
    return $newinterval
  }
  
  ######################################################################

  proc scan {text} {
    if {[::scan $text "%4d-%2d-%2d %2d:%2d:%f" years months days hours minutes seconds] == 6 || \
        [::scan $text "%4d-%2d-%2dT%2d:%2d:%f" years months days hours minutes seconds] == 6 || \
        [::scan $text "%4d%2d%2d %2d%2d%f" years months days hours minutes seconds] == 6 || \
        [::scan $text "%4d%2d%2dT%2d%2d%f" years months days hours minutes seconds] == 6 } {
      set iseconds [expr {int(floor($seconds))}]
      set fseconds [expr {$seconds - $iseconds}]
      set itext [::format "%04d-%02d-%02d %02d:%02d:%02d" $years $months $days $hours $minutes $iseconds]
      set iseconds [clock scan $itext -gmt true]
      set seconds [expr {$iseconds + $fseconds}]
      return $seconds
    } else {
      error "invalid ISO 8601 time format: \"$text\"."
    }
  }

  ######################################################################

  proc diff {a {b "now"}} {
    if {[string is double -strict $a]} {
      set aseconds $a
    } elseif {[string equal $a "now"]} {
      set aseconds [seconds]
    } else {
      set aseconds [scan $a]
    }
    if {[string is double -strict $b]} {
      set bseconds $b
    } elseif {[string equal $b "now"]} {
      set bseconds [seconds]
    } else {
      set bseconds [scan $b]
    }
    expr {$aseconds - $bseconds}
  }

  ######################################################################

  proc semester {} {
    ::scan [utcclock::format now] "%d-%d" year month
    if {$month <= 6} {
      return [::format "%04dA" $year]
    } else {
      return [::format "%04dB" $year]
    }
  }

  ######################################################################

}
