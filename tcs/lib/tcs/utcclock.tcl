########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2017, 2018, 2019, 2023 Alan M. Watson <alan@astro.unam.mx>
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

package require coroutine
package require directories
package require log

namespace eval "utcclock" {

  ######################################################################
  
  # taiminusutclist is a list that contains triples of entries corresponding to
  # leap seconds being added or removed. The first member of each pair is the
  # number of POSIX seconds, the seconds is the corresponding number of UTC
  # seconds, and the third is the TAI-UTC offset valid from that moment. The
  # list is in reverse order, with the latest entry being first.
  
  variable taiminusutclist {}
  
  proc parseleapsecondlines {lines} {
    # The data lines have an NTP timestamp followed the value of TAI-UTC that is
    # valid from that point. NTP timestamps are second since 1900-01-01
    # 00:00:00, ignoring leap seconds and other adjustments. 
    log::debug "creating the TAI-UTC list."
    variable taiminusutclist
    set posixoffset [expr {(70 * 365 + 70/4) * 24 * 60 * 60}]
    set taiminusutclist {}
    foreach line $lines {
      if {[::scan $line "%d %d" ntpseconds taiminusutc] == 2} {
        set posixseconds [expr {$ntpseconds - $posixoffset}]
        set utcseconds   [expr {$posixseconds + $taiminusutc - 10}]
        lappend taiminusutclist $taiminusutc
        lappend taiminusutclist $utcseconds
        lappend taiminusutclist $posixseconds
      }
    }
    set taiminusutclist [lreverse $taiminusutclist]  
    foreach {posixseconds utcseconds taiminusutc} $taiminusutclist {
      log::debug "from [format $utcseconds] UTC the value of TAI-UTC is $taiminusutc seconds."
    }
    log::debug "finished creating the TAI-UTC list."
  }
  
  proc updatetaiminusutclist {} {
    set path "[directories::var]/iers/leapseconds"
    log::debug "updating the TAI-UTC list from \"$path\"."
    if {[file exists $path]} {
      set lines {}
      if {[catch {
        set channel [open $path "r"]
        while {![eof $channel]} {
          set line [gets $channel]
          lappend lines $line
        }
        catch {close $channel}
      } message]} {
        catch {log::error "while reading TAI-UTC: $message"}
        return
      }
      parseleapsecondlines $lines
    }    
    log::debug "finished updating the TAI-UTC list."
  }
  
  proc posixtoutcseconds {seconds} {
    variable taiminusutclist
    foreach {posixseconds utcseconds taiminusutc} $taiminusutclist {
      if {$seconds >= $posixseconds} {
        return [expr {$seconds + $taiminusutc - 10}]
      }
    }
    return $seconds
  }
  
  proc utctoposixseconds {seconds} {
    variable taiminusutclist
    foreach {posixseconds utcseconds taiminusutc} $taiminusutclist {
      if {$seconds >= $utcseconds} {
        return [expr {$seconds - $taiminusutc + 10}]
      }
    }
    return $seconds
  }
  
  proc gettaiminusutc {{seconds "now"}} {
    if {[string equal $seconds now]} {
      set seconds [seconds]
    }
    variable taiminusutclist
    foreach {posixseconds utcseconds taiminusutc} $taiminusutclist {
      if {$seconds >= $utcseconds} {
        return $taiminusutc
      }
    }
    return 10
  }
    
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

  # The posixseconds and posixmilliseconds procedures return the number of POSIX
  # seconds since 1970-01-01 00:00:00 UTC. There are 86400 POSIX seconds in each
  # UTC day.

  proc posixseconds {} {
    variable resolution
    if {$resolution == 1.0} {
      set seconds [expr {double([clock seconds])}]
    } else {
      set seconds [expr {[clock milliseconds] * 1e-3}]
    }
    return $seconds
  }
  
  proc posixmilliseconds {} {
    variable resolution
    if {$resolution == 1.0} {
      set milliseconds [expr {double([clock seconds]) * 1e3}]
    } else {
      set milliseconds [expr {double([clock milliseconds])}]
    }
    return $milliseconds
  }
  
  ######################################################################
  
  # The seconds and milliseconds procedures return the number of UTC seconds and
  # milliseconds since 1970-01-01 00:00:00 UTC, including leap seconds.
  
  proc seconds {} {
    return [posixtoutcseconds [posixseconds]]
  }
  
  proc milliseconds {} {
    set posixmilliseconds [posixmilliseconds]
    set posixseconds [expr {floor($posixmilliseconds / 1000)}]
    set utcseconds [posixtoutcseconds $posixseconds]
    return [expr {$utcseconds * 1000 + ($posixmilliseconds - $posixseconds * 1000)}]
  }

  ######################################################################

  variable epochmjd   40587.0
  variable epochjd  2440587.5
  
  proc frommjd {mjd} {
    variable epochmjd
    set seconds [expr {($mjd - $epochmjd) * (24.0 * 60.0 * 60.0)}]
    set seconds [posixtoutcseconds $seconds]
    return $seconds
  }
  
  proc mjd {{seconds "now"}} {
    variable epochmjd
    if {[string equal $seconds now]} {
      set seconds [seconds]
    } elseif {![string is double -strict $seconds]} {
      set seconds [scan $seconds]
    }    
    set seconds [utctoposixseconds $seconds]
    expr {$seconds / (24.0 * 60.0 * 60.0) + $epochmjd}
  }

  proc fromjd {jd} {
    variable epochjd
    set seconds [expr {($jd - $epochjd) * (24.0 * 60.0 * 60.0)}]
    set seconds [posixtoutcseconds $seconds]
    return $seconds
  }
  
  proc jd {seconds} {
    variable epochjd
    if {[string equal $seconds now]} {
      set seconds [seconds]
    } elseif {![string is double -strict $seconds]} {
      set seconds [scan $seconds]
    }    
    set seconds [utctoposixseconds $seconds]
    return [expr {$seconds / (24.0 * 60.0 * 60.0) + $epochjd}]
  }
  
  proc epoch {{seconds "now"}} {
    # See Lieske (1979, A&A, 73, 282).
    set jd [jd $seconds]
    return [expr {2000.0 + ($jd - 2451545.0) / 365.25}]
  }

  ######################################################################
  
  # These format procedures return the UTC time corresponding to a given number
  # of UTC seconds after 1970-01-01 00:00:00 UTC.

  proc generalformat {seconds precision format} {
    if {[string equal $seconds now]} {
      set seconds [seconds]
    } elseif {![string is double -strict $seconds]} {
      set seconds [scan $seconds]
    }    
    set seconds [utctoposixseconds $seconds]
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
  
  proc formatinterval {seconds {extended true}} {
    if {$seconds < 60} {
      return [::format "%.1f seconds" $seconds]
    } elseif {$seconds < 3600} {
      if {$extended} {
        return [::format "%.1f seconds (%.1f minutes)" $seconds [expr {$seconds / 60.0}]]
      } else {
        return [::format "%.1f minutes" [expr {$seconds / 60.0}]]
      }
    } else {
      if {$extended} {
        return [::format "%.1f seconds (%.1f hours)" $seconds [expr {$seconds / 3600.0}]]
      } else {
        return [::format "%.1f hours" [expr {$seconds / 3660.0}]]
      }
    }
  }

  ######################################################################

  # These scan procedure returns the number of UTC seconds between the given UTC
  # time and 1970-01-01 00:00:00 UTC.

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
      set seconds [posixtoutcseconds $seconds]
      return $seconds
    } else {
      error "invalid ISO 8601 time format: \"$text\"."
    }
  }

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

  proc diff {a {b "now"}} {
    set now [seconds]
    if {[string is double -strict $a]} {
      set aseconds $a
    } elseif {[string equal $a "now"]} {
      set aseconds $now
    } else {
      set aseconds [scan $a]
    }
    if {[string is double -strict $b]} {
      set bseconds $b
    } elseif {[string equal $b "now"]} {
      set bseconds $now
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

  # Extract from https://www.ietf.org/timezones/data/leap-seconds.list on 2023 July 22.
  parseleapsecondlines {
    "2272060800	10	# 1 Jan 1972"
    "2287785600	11	# 1 Jul 1972"
    "2303683200	12	# 1 Jan 1973"
    "2335219200	13	# 1 Jan 1974"
    "2366755200	14	# 1 Jan 1975"
    "2398291200	15	# 1 Jan 1976"
    "2429913600	16	# 1 Jan 1977"
    "2461449600	17	# 1 Jan 1978"
    "2492985600	18	# 1 Jan 1979"
    "2524521600	19	# 1 Jan 1980"
    "2571782400	20	# 1 Jul 1981"
    "2603318400	21	# 1 Jul 1982"
    "2634854400	22	# 1 Jul 1983"
    "2698012800	23	# 1 Jul 1985"
    "2776982400	24	# 1 Jan 1988"
    "2840140800	25	# 1 Jan 1990"
    "2871676800	26	# 1 Jan 1991"
    "2918937600	27	# 1 Jul 1992"
    "2950473600	28	# 1 Jul 1993"
    "2982009600	29	# 1 Jul 1994"
    "3029443200	30	# 1 Jan 1996"
    "3076704000	31	# 1 Jul 1997"
    "3124137600	32	# 1 Jan 1999"
    "3345062400	33	# 1 Jan 2006"
    "3439756800	34	# 1 Jan 2009"
    "3550089600	35	# 1 Jul 2012"
    "3644697600	36	# 1 Jul 2015"
    "3692217600	37	# 1 Jan 2017"
  }
  
  updatetaiminusutclist
  after idle {
    coroutine::afterandevery 3600000 catch utcclock::updatetaiminusutclist
  }  

  ######################################################################

}
