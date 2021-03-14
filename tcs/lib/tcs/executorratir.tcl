########################################################################

# This file is part of the UNAM telescope control system.

# $Id: executorratir.tcl 3597 2020-06-10 18:38:53Z Alan $

########################################################################

# Copyright © 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "executorratir" 0.0

namespace eval "executor" {

  variable svnid {$Id}

  ######################################################################

  proc focusfinders {exposuretime} {
    log::summary "focusing finders."
    client::request "telescope" "focusfinders $exposuretime"
    client::wait "telescope"     
    log::summary "finished focusing finders."
  }
  
  proc focusccd {exposuretime detector {positionrange 1000} {positionstep 100}} {
    log::summary "focusing $detector."
    client::request $detector "focus $exposuretime $positionrange $positionstep"
    client::wait $detector
    log::summary "finished focusing $detector."
  }

  proc ratirfocussecondary {exposuretimeC01 exposuretimeC23 detector {z0range 300} {z0step 20}} {
    log::summary "focusing secondary on $detector."
    client::update "secondary"
    set z0 [client::getdata "secondary" "requestedz0"]
    set originalz0 $z0
    while {true} {
      set z0min [expr {int($z0 - 0.5 * $z0range)}]
      set z0max [expr {int($z0 + 0.5 * $z0range)}]
      log::info "focusing secondary on $detector from $z0min to $z0max in steps of $z0step."
      set z0 $z0max
      set z0list   {}
      set fwhmlist {}
      while {$z0 >= $z0min} {
        client::request "telescope" "movesecondary $z0"
        client::wait "telescope"
        exposefocus $exposuretimeC01 $exposuretimeC23
        client::update $detector
        set fwhm [client::getdata $detector "fwhm"]
        set fitsfilename [file tail [client::getdata $detector "fitsfilename"]]
        log::info "$fitsfilename: FWHM is $fwhm pixels at $z0."
        if {![string equal "$fwhm" "unknown"]} {
          lappend z0list   $z0
          lappend fwhmlist $fwhm
        }
        set z0 [expr {$z0 - $z0step}]
      }
      if {[catch {
        set z0 [fitfocus::findmin $z0list $fwhmlist]
      } message]} {
        log::warning "fitting failed: $message"
        set z0 $originalz0
        break
      } elseif {$z0 < $z0min} {
        set z0 $z0min
      } elseif {$z0 > $z0max} {
        set z0 $z0max
      } else {
        break
      }
      log::info "focusing secondary again around $z0."
    }
    client::request "telescope" "movesecondary $z0"
    client::wait "telescope"
    exposeobject $exposuretimeC01 $exposuretimeC01 $exposuretimeC23 $exposuretimeC23 1 1
    client::update $detector
    set fwhm [client::getdata $detector "fwhm"]
    set fitsfilename [file tail [client::getdata $detector "fitsfilename"]]
    log::summary "$fitsfilename: witness FWHM is $fwhm pixels at $z0 in $exposuretimeC01/$exposuretimeC23 seconds."
    log::summary "finished focusing secondary."
  }
  
  ######################################################################

  proc ratirtrack {pointingaperture eastoffset northoffset pointingmode {guidingmode "none"}} {
    setpointingaperture $pointingaperture
    setpointingmode $pointingmode
    setguidingmode $guidingmode
    client::request "telescope" [format "ratirtrack %s %s %.2f %+.1fas %+.1fas %s %+.5fas %+.5fas" \
      [astrometry::radtohms [visit::alpha] 2 false] \
      [astrometry::radtodms [visit::delta] 1 true] \
      [visit::equinox] \
      [astrometry::radtoarcsec [astrometry::parseangle $eastoffset]] \
      [astrometry::radtoarcsec [astrometry::parseangle $northoffset]] \
      [visit::epoch] \
      [astrometry::radtoarcsec [visit::alpharate]] \
      [astrometry::radtoarcsec [visit::deltarate]] \
    ]
    client::wait "telescope" 
  }
  
  proc ratirtracktopocentric {pointingaperture pointingmode {guidingmode "none"}} {
    setpointingaperture $pointingaperture
    setpointingmode $pointingmode
    setguidingmode $guidingmode
    client::request "telescope" [format "ratirtracktopocentric %s %s" \
      [astrometry::radtohms [visit::observedha] 2 true] \
      [astrometry::radtodms [visit::observeddelta] 1 true] \
    ]
    client::wait "telescope" 
  }
  
  proc ratiroffset {pointingaperture eastoffset northoffset guidingmode} {
    setpointingaperture $pointingaperture
    setguidingmode $guidingmode
    client::request "telescope" [format "ratiroffset %+.1fas %+.1fas" \
      [astrometry::radtoarcsec [astrometry::parseangle $eastoffset]] \
      [astrometry::radtoarcsec [astrometry::parseangle $northoffset]] \
    ]
    client::wait "telescope" 
  } 
  
  proc correct {{exposuretime 10} {detector C1}} {
    log::summary "attempting to correct pointing model."
    ratiroffset ricenter 0 0 finder
    if {[catch {exposeastrometry $detector $exposuretime} message]} {
      log::warning "failed to solve: $message"
      client::resetifnecessary "telescope"
      client::resetifnecessary "instrument"
      client::request "telescope" "correct unknown unknown unknown"
      client::wait "telescope"
      log::summary "unable to correct pointing model."
    } else {
      log::summary "solved."
      client::update $detector
      set alpha   [client::getdata $detector "solvedalpha"]
      set delta   [client::getdata $detector "solveddelta"]
      set equinox [client::getdata $detector "solvedequinox"]
      client::request "telescope"  "correct $alpha $delta $equinox"
      client::wait "telescope"
      log::summary "finished correcting pointing model."
    }
  }

  ######################################################################

  proc exposeloop {n C0exposuretime C1exposuretime C2exposuretime C3exposuretime C2nreads C3nreads type} {

    variable exposure

    log::info "exposing $type images (exposure $exposure)."

    if {$C2nreads == 0} {
      set C2exposuretime "none"
    }
    if {$C3nreads == 0} {
      set C3exposuretime "none"
    }

    if {[string equal [getguidingmode] "C0"] || [string equal [getguidingmode] "C0donuts"]} {
      set C0exposuretime "none"
    }
    if {[string equal [getguidingmode] "C1"] || [string equal [getguidingmode] "C1donuts"]} {
      set C1exposuretime "none"
    }

    set seconds [utcclock::seconds]
    set date [utcclock::formatdate $seconds false]
    set projectidentifier [project::identifier]
    set visitidentifier [visit::identifier]
    set prefix "/images/test/$date/$projectidentifier/$visitidentifier"
    log::info "prefix is \"[directories::prefix]\"."
    file mkdir [file dirname [directories::prefix]]

    client::request "instrument" "exposeloop $n $C0exposuretime $C1exposuretime $C2exposuretime $C3exposuretime $C2nreads $C3nreads $type [directories::prefix]"
    client::wait "instrument"

    log::info "finished exposing (exposure $exposure)."

    set exposure [expr {$exposure + 1}]
  }
  
  proc ratirexpose {C0exposuretime C1exposuretime C2exposuretime C3exposuretime C2nreads C3nreads type} {

    variable exposure

    log::info "exposing $type images (exposure $exposure)."

    if {$C2nreads == 0} {
      set C2exposuretime "none"
    }
    if {$C3nreads == 0} {
      set C3exposuretime "none"
    }

    if {[string equal [getguidingmode] "C0"] || [string equal [getguidingmode] "C0donuts"]} {
      set C0exposuretime "none"
    }
    if {[string equal [getguidingmode] "C1"] || [string equal [getguidingmode] "C1donuts"]} {
      set C1exposuretime "none"
    }

    set seconds [utcclock::seconds]
    set date [utcclock::formatdate $seconds false]
    set dateandtime [utcclock::combinedformat $seconds 0 false]
    set projectidentifier [project::identifier]
    set visitidentifier [visit::identifier]
    set prefix "/images/test/$date/$projectidentifier/$visitidentifier/$dateandtime"
    log::info "prefix is \"[directories::prefix]\"."
    file mkdir [file dirname [directories::prefix]]

    client::request "instrument" "expose $C0exposuretime $C1exposuretime $C2exposuretime $C3exposuretime $C2nreads $C3nreads $type [directories::prefix]"
    client::wait "instrument"

    log::info "finished exposing (exposure $exposure)."

    set exposure [expr {$exposure + 1}]
  }
  
  proc exposeobject {C0exposuretime C1exposuretime C2exposuretime C3exposuretime C2nreads C3nreads} {
    expose $C0exposuretime $C1exposuretime $C2exposuretime $C3exposuretime $C2nreads $C3nreads "object"
  }

  proc exposefocus {exposuretimeC01 exposuretimeC23} {
    expose $exposuretimeC01 $exposuretimeC01 $exposuretimeC23 $exposuretimeC23 1 1 "focus"
  }

  proc exposeastrometry {detector exposuretime} {
    switch $detector {
      C0 {
        expose $exposuretime "none" "none" "none" 0 0 "astrometry"
      }
      C1 {
        expose "none" $exposuretime "none" "none" 0 0 "astrometry"
      }
      C2 {
        expose "none" "none" $exposuretime "none" 1 0 "astrometry"
      }
      C3 {
        expose "none" "none" "none" $exposuretime 0 1 "astrometry"
      }
      C4 {
        expose "none" $exposuretime "none" "none" 0 0 "astrometry"
      }
    }
  }

  proc exposeflat {C01exposuretime C23exposuretime} {
    expose $C01exposuretime $C01exposuretime $C23exposuretime $C23exposuretime 1 1  "flat"
  }

  proc exposedark {C01exposuretime} {
    expose $C01exposuretime $C01exposuretime "none" "none" 0 0 "dark"
  }

  proc exposebias {} {
    expose 0 0 "none" "none" 0 0  "bias"
  }

  proc ratirmovefilterwheel {filter} {
   log::info "moving filter wheel to filter \"$filter\"."
   client::request "instrument" "movefilterwheel $filter"
   client::wait "instrument"
   log::info "finished moving filter wheel."
  }

  ######################################################################

}
