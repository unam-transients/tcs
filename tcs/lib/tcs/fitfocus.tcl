########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "fitfocus" 0.0

namespace eval "fitfocus" {

  ######################################################################
  
  # This code estimates the minmum of a function y = f(x).
  
  # It first finds the least-squares fitting parabola, with 2-sigma rejection.
  # It then determines the turning point. If the turning point is a minimum, it
  # returns the value of x at the minimum. Otherwise, it finds the least-squares
  # fitting line, with 2-sigma rejection, and returns the x value at the
  # intercept with y = 0.

  # The least-square parabola is determined as follows. Given a parabola
  #
  # y = a + b * x + c * x * x, 
  # 
  # the least-squares fitting coefficients are given by:
  #
  # S01 = S00 * a + S10 * b + S20 * c,
  # S11 = S10 * a + S20 * b + S30 * c, and
  # S21 = S20 * a + S30 * b + S40 * c.
  #
  # in which Smn is the sum of x^m * y^n. This set of equations can be 
  # reduced to:
  #
  # A0 = B0 * b + C0 * c
  # A1 = B1 * b + C1 * c
  #
  # in which
  #
  # A0 = S01 * S10 - S11 * S00,
  # B0 = S10 * S10 - S20 * S00,
  # C0 = S20 * S10 - S30 * S00,
  #
  # A1 = S11 * S20 - S21 * S10,
  # B1 = S20 * S20 - S30 * S10, and
  # C1 = S30 * S20 - S40 * S10.
  #
  # Solving these, we have:
  #
  # c = (A0 * B1 - A1 * B0) / (B1 * C0 - B0 * C1),
  # b = (A0 - C0 * c) / B0, and
  # a = (S01 - S10 * b - S20 * c) / S00.
  #
  # The turning point is a minimum if c > 0.
  
  # The least-square line is determined as follows. Given a line
  #
  #   y = a + b x,
  #
  # the least-squares fitting coefficients are given by:
  #
  # b = (S00 * S11 - S10 * S01) / (S00 * S20 - S10 * S10)
  # a = S01 / S00 - b * S10 / S00
  
  
  variable maxabschi 2.0
  variable maxfwhm 15.0
  
  proc fit2 {xlist ylist chilist detector} {
    variable maxabschi
    variable maxfwhm
    set S00 0.0
    set S10 0.0
    set S20 0.0
    set S30 0.0
    set S40 0.0
    set S01 0.0
    set S11 0.0
    set S21 0.0
    foreach x $xlist y $ylist chi $chilist {
      log::debug "fitfocus $detector: x = $x y = $y chi = $chi."
      if {$y <= $maxfwhm && abs($chi) <= $maxabschi} {
        set S00 [expr {$S00 + 1}]
        set S10 [expr {$S10 + $x}]
        set S20 [expr {$S20 + $x * $x}]
        set S30 [expr {$S30 + $x * $x * $x}]
        set S40 [expr {$S40 + $x * $x * $x * $x}]
        set S01 [expr {$S01 + $y}]
        set S11 [expr {$S11 + $x * $y}]
        set S21 [expr {$S21 + $x * $x * $y}]
      }
    }
    set A0 [expr {$S01 * $S10 - $S11 * $S00}]
    set B0 [expr {$S10 * $S10 - $S20 * $S00}]
    set C0 [expr {$S20 * $S10 - $S30 * $S00}]
    set A1 [expr {$S11 * $S20 - $S21 * $S10}]
    set B1 [expr {$S20 * $S20 - $S30 * $S10}]
    set C1 [expr {$S30 * $S20 - $S40 * $S10}]
    set c [expr {($A0 * $B1 - $A1 * $B0) / ($B1 * $C0 - $B0 * $C1)}]
    set b [expr {($A0 - $C0 * $c) / $B0}]
    set a [expr {($S01 - $S10 * $b - $S20 * $c) / $S00}]
    return [list $a $b $c]
  }
  
  proc fit1 {xlist ylist chilist detector} {
    variable maxabschi
    variable maxfwhm
    set S00 0.0
    set S10 0.0
    set S20 0.0
    set S30 0.0
    set S40 0.0
    set S01 0.0
    set S11 0.0
    set S21 0.0
    foreach x $xlist y $ylist chi $chilist {
      log::debug "fitfocus $detector: x = $x y = $y chi = $chi."
      if {$y <= $maxfwhm && abs($chi) <= $maxabschi} {
        set S00 [expr {$S00 + 1}]
        set S10 [expr {$S10 + $x}]
        set S20 [expr {$S20 + $x * $x}]
        set S01 [expr {$S01 + $y}]
        set S11 [expr {$S11 + $x * $y}]
      }
    }
    set b [expr {($S00 * $S11 - $S10 * $S01) / ($S00 * $S20 - $S10 * $S10)}]
    set a [expr {($S01 - $S10 * $b) / $S00}]
    return [list $a $b]
  }
  
  proc findmin {xlist ylist {detector ""}} {
    # For brevity, we use x for z0 and y for FWHM.
    variable maxabschi
    variable maxfwhm
    log::debug "fitfocus $detector: maxabschi = $maxabschi."
    log::debug "fitfocus $detector: maxfwhm = $maxfwhm."
    if {[llength $xlist] != [llength $ylist]} {
      error "xlist and ylist do not have the same length."
    }
    set n [llength $xlist]
    log::debug "fitfocus $detector: n = $n."
    log::info "fitfocus $detector: performing quadratic fit."
    set chilist [lrepeat $n 0.0]
    foreach iteration {0 1 2} {
      set coeffientslist [fit2 $xlist $ylist $chilist $detector]
      set a [lindex $coeffientslist 0]
      set b [lindex $coeffientslist 1]
      set c [lindex $coeffientslist 2]
      log::debug "fitfocus $detector: iteration $iteration: a = $a b = $b c = $c."
      set sdyy 0.0
      foreach x $xlist y $ylist {
        set dy [expr {$y - ($a + $b * $x + $c * $x * $x)}]
        set sdyy [expr {$sdyy + $dy * $dy}]
      }
      set sigma [expr {sqrt($sdyy / ($n - 1))}]
      log::debug "fitfocus $detector: iteration $iteration: sigma = $sigma."
      set chilist {}
      foreach x $xlist y $ylist {
        set dy [expr {$y - ($a + $b * $x + $c * $x * $x)}]
        if {$sigma != 0} {
          lappend chilist [expr {$dy / $sigma}]
        } else {
          lappend chilist 0
        }
      }
    }
    if {$c < 0} {
      log::info "fitfocus $detector: quadratic fit has maximum."
      set dolinearfit true
    } else {
      set minx [expr {int(-$b / (2 * $c))}]
      set miny [expr {$a + $b * $minx + $c * $minx * $minx}]
      if {$miny < 0} {
        log::info "fitfocus $detector: quadratic fit has negative minimum."
        set dolinearfit true
      } else {
        log::info "fitfocus $detector: quadratic fit has positive minimum."
        set dolinearfit false
      }
    }
    if {$dolinearfit} {
      log::info "fitfocus $detector: performing linear fit."
      set chilist [lrepeat $n 0.0]
      foreach iteration {0 1 2} {
        set coeffientslist [fit1 $xlist $ylist $chilist $detector]
        set a [lindex $coeffientslist 0]
        set b [lindex $coeffientslist 1]
        log::debug "fitfocus $detector: iteration $iteration: a = $a b = $b."
        set sdyy 0.0
        foreach x $xlist y $ylist {
          set dy [expr {$y - ($a + $b * $x)}]
          set sdyy [expr {$sdyy + $dy * $dy}]
        }
        set sigma [expr {sqrt($sdyy / ($n - 1))}]
        log::debug "fitfocus $detector: iteration $iteration: sigma = $sigma."
        set chilist {}
        foreach x $xlist y $ylist {
          set dy [expr {$y - ($a + $b * $x)}]
          if {$sigma != 0} {
            lappend chilist [expr {$dy / $sigma}]
          } else {
            lappend chilist 0
          }
        }
      }
      log::info "fitfocus $detector: linear fit found intercept."
      set minx [expr {int(-$a / $b)}]
      set miny 0
    }
    foreach x $xlist y $ylist chi $chilist {
      if {$y <= $maxfwhm && abs($chi) <= $maxabschi} {
        log::info [format "fitfocus $detector: FWHM = %4.2fas at %d (chi = %+6.2f)" [astrometry::radtoarcsec $y] $x $chi]
      } else {
        log::info [format "fitfocus $detector: FWHM = %4.2fas at %d (chi = %+6.2f rejected)" [astrometry::radtoarcsec $y] $x $chi]
      }
    }
    log::info [format "fitfocus $detector: model minimum: FWHM = %.2fas at %d." [astrometry::radtoarcsec $miny] $minx]
    return $minx
  }
  
  ######################################################################
    
}
