########################################################################

# This file is part of the UNAM telescope control system.

# $Id: guider.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "client"
package require "coroutine"
package require "server"
package require "utcclock"
package require "config"

package require "finders"

package provide "guider" 0.0

config::setdefaultvalue "guider" "eastgain"       -0.50
config::setdefaultvalue "guider" "northgain"      -0.50
config::setdefaultvalue "guider" "deadzonewidth"  0.5as
config::setdefaultvalue "guider" "warningradius"  2.0as

namespace eval "guider" {

  variable svnid {$Id}

  ######################################################################

  variable eastgain       [config::getvalue "guider" "eastgain"]
  variable northgain      [config::getvalue "guider" "northgain"]
  variable deadzonewidth [astrometry::parseangle [config::getvalue "guider" "deadzonewidth"]]
  variable warningradius  [astrometry::parseangle [config::getvalue "guider" "warningradius"]]
  
  ######################################################################
  
  proc resetstatistics {} {
    server::setdata "guidingtime"         ""
    server::setdata "finder"              ""
    server::setdata "exposuretime"        ""
    server::setdata "meancadence"         ""
    server::setdata "deadzonefraction"    ""
    server::setdata "alpha"               ""
    server::setdata "delta"               ""
    server::setdata "initialalpha"        ""
    server::setdata "initialdelta"        ""
    server::setdata "easterror"           ""
    server::setdata "northerror"          ""
    server::setdata "totalerror"          ""
    server::setdata "meaneasterror"       ""
    server::setdata "meannortherror"      ""
    server::setdata "meantotalerror"      ""
    server::setdata "rmseasterror"        ""
    server::setdata "rmsnortherror"       ""
    server::setdata "rmstotalerror"       ""
    server::setdata "totaleastoffset"     ""
    server::setdata "totalnorthoffset"    ""
    server::setdata "totaltotaloffset"    ""
    server::setdata "meaneastoffsetrate"  ""
    server::setdata "meannorthoffsetrate" ""
    server::setdata "meantotaloffsetrate" ""
  }

  proc startactivitycommand {} {
    log::info "starting."
  }
  
  proc initializeactivitycommand {} {
    resetstatistics
  }
  
  proc stopactivitycommand {lastactivity} {
    set guidingmode [server::getdata "guidingmode"]
    if {[string equal $lastactivity "guiding"]} {
      log::info "stopping guiding."
      switch -glob $guidingmode {
        *finder {
          set finder $guidingmode
          client::request $finder "stop"
          client::wait $finder
        }
        C0 -
        C1 {
          set ccd $guidingmode
          client::request $ccd "stop"
          client::wait $ccd
        }
      }
      if {[server::getdata "guidingtime"] > 0} {
        catch {
          log::info [format "after %.1f seconds the mean error is %+.2fas E, %+.2fas N, and %.2fas total." \
            [server::getdata "guidingtime"] \
            [astrometry::radtoarcsec [server::getdata "meaneasterror"]] \
            [astrometry::radtoarcsec [server::getdata "meannortherror"]] \
            [astrometry::radtoarcsec [server::getdata "meantotalerror"]]]
          log::info [format "after %.1f seconds the RMS error about the mean is %.2fas E, %.2fas N, and %.2fas total." \
            [server::getdata "guidingtime"] \
            [astrometry::radtoarcsec [server::getdata "rmseasterror"]] \
            [astrometry::radtoarcsec [server::getdata "rmsnortherror"]] \
            [astrometry::radtoarcsec [server::getdata "rmstotalerror"]]]
          log::info [format "after %.1f seconds the exposure time is %.1f seconds and the mean cadence is %.1f seconds." \
            [server::getdata "guidingtime"] \
            [server::getdata "exposuretime"] \
            [server::getdata "meancadence"]]
          log::info [format "after %.1f seconds dead-zone fraction is %.2." \
            [server::getdata "guidingtime"] \
            [server::getdata "deadzonefraction"]]
        }
      }
    }
    resetstatistics
  }

  proc errorstart {guidingmode} {
    server::setdata "alpha"        "unknown"
    server::setdata "delta"        "unknown"
    server::setdata "initialalpha" "unknown"
    server::setdata "initialdelta" "unknown"
    server::setdata "easterror"    "unknown"
    server::setdata "northerror"   "unknown"
    server::setdata "exposuretime" "unknown"
    switch -glob $guidingmode {
      finder {
        if {
          [catch {finders::getfinderastrometry}] ||
          [string equal [finders::getsolvedfinder] ""]
        } {
          error "unable to guide with the finders."
        }
        set finder       [finders::getsolvedfinder]
        set exposuretime [finders::getexposuretime]
        log::info "guiding with $finder."
        server::setdata "guidingmode"  $finder
        server::setdata "exposuretime" $exposuretime
        set alpha [client::getdata $finder "mountobservedalpha"]
        set delta [client::getdata $finder "mountobserveddelta"]
        server::setdata "alpha"        $alpha
        server::setdata "delta"        $delta
        server::setdata "initialalpha" $alpha
        server::setdata "initialdelta" $delta
      }
      C0 -
      C1 {
        set ccd $guidingmode
        set exposuretime 5
        if {
          [catch {
            client::request $ccd "stop"
            client::request $ccd "expose $exposuretime guidestart"
            client::wait $ccd
            client::request $ccd "analyse guidestart"
            client::wait $ccd
          }]
        } {
          error "unable to obtain start guiding with $ccd."
        }
        log::info "guiding with $ccd."
        server::setdata "guidingmode"  $guidingmode
        server::setdata "exposuretime" $exposuretime
      }
    }
  }
  
  proc errornext {} {
    set guidingmode [server::getdata "guidingmode"]
    switch -glob $guidingmode {
      *finder {
        set finder       $guidingmode
        set exposuretime [server::getdata "exposuretime"]
        if {
          [catch {
            client::request $finder "expose $exposuretime astrometry"
            client::wait $finder
          }] || 
          [string equal [client::getdata $finder "mountobservedalpha"] "unknown"]
        } {
          log::warning "unable to obtain error while guiding with $finder."
          server::setdata "alpha"      "unknown"
          server::setdata "delta"      "unknown"
          server::setdata "easterror"  "unknown"
          server::setdata "northerror" "unknown"
          return
        }
        set alpha [client::getdata $finder "mountobservedalpha"]
        set delta [client::getdata $finder "mountobserveddelta"]
        set alphaerror [expr {($alpha - [server::getdata "initialalpha"])}]
        set deltaerror [expr {($delta - [server::getdata "initialdelta"])}]
        server::setdata "alpha"     $alpha
        server::setdata "delta"     $delta
        server::setdata "easterror" [expr {$alphaerror * cos($delta)}]
        server::setdata "northerror" $deltaerror
      }
      C0 -
      C1 {
        set ccd          $guidingmode
        set exposuretime [server::getdata "exposuretime"]
        if {
          [catch {
            client::request $ccd "expose $exposuretime guidenext"
            client::wait $ccd
            client::request $ccd "analyse guidenext"
            client::wait $ccd
          }]
        } {
          log::warning "unable to obtain error while guiding with $ccd."
          server::setdata "easterror"  "unknown"
          server::setdata "northerror" "unknown"
          return
        }
        server::setdata "easterror"  [client::getdata $ccd "guidestareasterror" ]
        server::setdata "northerror" [client::getdata $ccd "guidestarnortherror"]
      }
    }
  }
  
  proc guideactivitycommand {guidingmode} {
    variable eastgain
    variable northgain
    variable deadzonewidth
    variable warningradius
    resetstatistics
    server::setdata "guidingmode" ""
    server::setactivity "guiding"
    log::info "starting guiding with $guidingmode."
    server::clearactivitytimeout
    if {[catch {errorstart $guidingmode} message]} {
      log::warning "guiding cancelled: $message"
      return
    }
    set alpha [server::getdata "alpha"]
    set delta [server::getdata "delta"]
    if {![string equal $alpha "unknown"] && ![string equal $delta "unknown"]} {
      if {[catch {
        client::request "mount" "correct [astrometry::radtohms $alpha 2 false] [astrometry::radtodms $delta 1 true] observed"
      } message]} {
        log::error "unable to correct pointing: $message"
        return
      }
    }
    set sumeasterror 0.0
    set sumnortherror 0.0
    set sumeasterrorsquared 0.0
    set sumnortherrorsquared 0.0
    set totaleastoffset 0.0
    set totalnorthoffset 0.0
    set n 0
    set ndeadzone 0
    set startseconds [utcclock::seconds]
    server::setdata "guidingtime" 0
    while {true} {
      if {[catch {client::checkactivity "target" "tracking"} message]} {
        log::warning "guiding cancelled: $message"
        return
      }
      if {[catch {errornext} message]} {
        log::warning "guiding failed: $message"
        continue
      }
      set alpha [server::getdata "alpha"]
      set delta [server::getdata "delta"]
      if {![string equal $alpha "unknown"] && ![string equal $delta "unknown"]} {
        if {[catch {
          client::request "mount" "correct [astrometry::radtohms $alpha 2 false] [astrometry::radtodms $delta 1 true] observed"
        } message]} {
          log::error "unable to correct pointing: $message"
          return
        }
      }
      set easterror  [server::getdata "easterror" ]
      set northerror [server::getdata "northerror"]
      if {![string equal $easterror "unknown"] && ![string equal $northerror "unknown"]} {
        set totalerror [expr {sqrt($easterror * $easterror + $northerror * $northerror)}]
        log::debug [format "error is %+.2fas E and %+.2fas N." [astrometry::radtoarcsec $easterror] [astrometry::radtoarcsec $northerror]]
        set sumeasterror [expr {$sumeasterror + $easterror}]
        set sumnortherror [expr {$sumnortherror + $northerror}]
        set sumeasterrorsquared [expr {$sumeasterrorsquared + $easterror * $easterror}]
        set sumnortherrorsquared [expr {$sumnortherrorsquared + $northerror * $northerror}]
        set n [expr {$n + 1}]
        set meaneasterror [expr {$sumeasterror / $n}]
        set meannortherror [expr {$sumnortherror / $n}]
        set meantotalerror [expr {sqrt($meaneasterror * $meaneasterror + $meannortherror * $meannortherror)}]
        log::debug [format "mean error is %+.2fas E, %+.2fas N, and %.2fas total." \
          [astrometry::radtoarcsec $meaneasterror] \
          [astrometry::radtoarcsec $meannortherror] \
          [astrometry::radtoarcsec $meantotalerror]]
        set rmseasterror [expr {sqrt($sumeasterrorsquared / $n - $meaneasterror * $meaneasterror)}]
        set rmsnortherror [expr {sqrt($sumnortherrorsquared / $n - $meannortherror * $meannortherror)}]
        set rmstotalerror [expr {sqrt($rmseasterror * $rmseasterror + $rmsnortherror * $rmsnortherror)}]
        log::debug [format "RMS error about mean is %.2fas E, %.2fas N, and %.2fas total." \
          [astrometry::radtoarcsec $rmseasterror] \
          [astrometry::radtoarcsec $rmsnortherror] \
          [astrometry::radtoarcsec $rmstotalerror]]
        if {$totalerror > $warningradius} {
          log::warning [format "error is %+.1fas E, %+.1fas N, and %.1fas total." \
            [astrometry::radtoarcsec $easterror] \
            [astrometry::radtoarcsec $northerror] \
            [astrometry::radtoarcsec $totalerror]]
        }
        if {abs($easterror) > $warningradius} {
          set eastoffset [expr {-1.0 * $easterror}]
        } elseif {abs($easterror) > $deadzonewidth} {
          set eastoffset [expr {$eastgain  * $easterror}]
        } else {
          set eastoffset 0
        }
        if {abs($northerror) > $warningradius} {
          set northoffset [expr {-1.0 * $northerror}]
        } elseif {abs($northerror) > $deadzonewidth} {
          set northoffset [expr {$northgain * $northerror}]
        } else {
          set northoffset 0
        }
        set totaloffset [expr {sqrt($eastoffset * $eastoffset + $northoffset * $northoffset)}]
        set totaleastoffset  [expr {$totaleastoffset  + $eastoffset}]
        set totalnorthoffset [expr {$totalnorthoffset + $northoffset}]
        if {$eastoffset == 0 && $northoffset == 0} {
          set ndeadzone [expr {$ndeadzone + 1}]
        } elseif {[catch {
          client::request "mount" [format "guide %+.2fas %+.2fas" [astrometry::radtoarcsec $eastoffset] [astrometry::radtoarcsec $northoffset]]
        }]} {
          log::warning "guiding cancelled: $message"
          break            
        }
        set guidingtime         [expr {[utcclock::seconds] - $startseconds}]
        set meancadence         [expr {$guidingtime / $n}]
        set deadzonefraction    [expr {double($ndeadzone) / double($n)}]
        set totaltotaloffset    [expr {sqrt($totaleastoffset * $totaleastoffset + $totalnorthoffset * $totalnorthoffset)}]
        set meaneastoffsetrate  [expr {$totaleastoffset  / $guidingtime}]
        set meannorthoffsetrate [expr {$totalnorthoffset / $guidingtime}]
        set meantotaloffsetrate [expr {$totaltotaloffset / $guidingtime}]
        server::setdata "totalerror"          $totalerror
        server::setdata "meaneasterror"       $meaneasterror
        server::setdata "meannortherror"      $meannortherror
        server::setdata "meantotalerror"      $meantotalerror
        server::setdata "rmseasterror"        $rmseasterror
        server::setdata "rmsnortherror"       $rmsnortherror
        server::setdata "rmstotalerror"       $rmstotalerror
        server::setdata "meancadence"         $meancadence
        server::setdata "guidingtime"         $guidingtime
        server::setdata "deadzonefraction"    $deadzonefraction
        server::setdata "totaleastoffset"     $totaleastoffset
        server::setdata "totalnorthoffset"    $totalnorthoffset
        server::setdata "totaltotaloffset"    $totaltotaloffset
        server::setdata "meaneastoffsetrate"  $meaneastoffsetrate
        server::setdata "meannorthoffsetrate" $meannorthoffsetrate
        server::setdata "meantotaloffsetrate" $meantotaloffsetrate
        if {$eastoffset != 0 || $northoffset != 0} {
          coroutine::after 2000
        }
      }
    }
    server::setactivity "idle"
  }
  
  ######################################################################

  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" \
      guider::initializeactivitycommand
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] \
      "guider::stopactivitycommand [server::getactivity]"
  }
  
  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] \
      "guider::stopactivitycommand [server::getactivity]"
  }

  proc guide {guidingmode} {
    server::checkstatus
    server::checkactivity "idle"
    server::newactivitycommand "preparingtoguide" "guiding" \
      "guider::guideactivitycommand $guidingmode"
  }
  
  ######################################################################
  
  set server::datalifeseconds 0
  server::setdata "timestamp" [utcclock::combinedformat now]
  server::setdata "guidingmode"         ""
  server::setdata "guidingtime"         ""
  server::setdata "finder"              ""
  server::setdata "exposuretime"        ""
  server::setdata "meancadence"         ""
  server::setdata "eastgain"            $eastgain
  server::setdata "northgain"           $northgain
  server::setdata "deadzonewidth"       $deadzonewidth
  server::setdata "deadzonefraction"    ""
  server::setdata "easterror"           ""
  server::setdata "northerror"          ""
  server::setdata "totalerror"          ""
  server::setdata "meaneasterror"       ""
  server::setdata "meannortherror"      ""
  server::setdata "meantotalerror"      ""
  server::setdata "rmseasterror"        ""
  server::setdata "rmsnortherror"       ""
  server::setdata "rmstotalerror"       ""
  server::setdata "totaleastoffset"     ""
  server::setdata "totalnorthoffset"    ""
  server::setdata "totaltotaloffset"    ""
  server::setdata "meaneastoffsetrate"  ""
  server::setdata "meannorthoffsetrate" ""
  server::setdata "meantotaloffsetrate" ""

  proc start {} {
    server::setstatus "ok"
    server::newactivitycommand "starting" "idle" guider::startactivitycommand
  }

}
