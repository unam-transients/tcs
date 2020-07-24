########################################################################

# This file is part of the UNAM telescope control system.

# $Id: pointing.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2010, 2011, 2013, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "pointing" 0.0

namespace eval "pointing" {

  variable svnid {$Id}

  ######################################################################
  
  variable apertures [config::getvalue "target" "pointingapertures"]
  
  ######################################################################

  variable phi [astrometry::latitude]

  proc getparameter {parameters name} {
    if {[dict exists $parameters $name]} {
      return [dict get $parameters $name]
    } else {
      return 0
    }
  }

  proc modeldha {parameters ha delta} {
    variable phi
    set sgnha [expr {($ha >= 0) ? 1.0 : -1.0}]
    set dha 0
    set dha [expr {$dha + [getparameter $parameters IH   ]}]
    set dha [expr {$dha + [getparameter $parameters CH   ] / cos($delta)}]
    set dha [expr {$dha + [getparameter $parameters CHS  ] / cos($delta) * $sgnha}]
    set dha [expr {$dha + [getparameter $parameters NP   ] * tan($delta)}]
    set dha [expr {$dha + [getparameter $parameters NPS  ] * tan($delta) * $sgnha}]
    set dha [expr {$dha - [getparameter $parameters MA   ] * cos($ha) * tan($delta)}]
    set dha [expr {$dha + [getparameter $parameters ME   ] * sin($ha) * tan($delta)}]
    set dha [expr {$dha + [getparameter $parameters TF   ] * cos($phi) * sin($ha) / cos($delta)}]
    set dha [expr {$dha - [getparameter $parameters DAF  ] * (cos($phi) * cos($ha) + sin($phi) * tan($delta))}]

    set dha [expr {$dha + [getparameter $parameters HHSH ] * sin($ha)}]
    set dha [expr {$dha + [getparameter $parameters HHCH ] * cos($ha)}]

    set dha [expr {$dha + [getparameter $parameters HHSH2] * sin(2 * $ha)}]
    set dha [expr {$dha + [getparameter $parameters HHCH2] * cos(2 * $ha)}]

    set dha [expr {$dha + [getparameter $parameters PXD  ] / cos($delta) * ($delta - $phi)}]
    set dha [expr {$dha + [getparameter $parameters PXH  ] / cos($delta) * $ha}]

    set dha [expr {$dha + [getparameter $parameters PXD2 ] / cos($delta) * pow($delta - $phi, 2)}]
    set dha [expr {$dha + [getparameter $parameters PXDH ] / cos($delta) * ($delta - $phi) * $ha}]
    set dha [expr {$dha + [getparameter $parameters PXH2 ] / cos($delta) * pow($ha, 2)}]

    set dha [expr {$dha + [getparameter $parameters PXD3 ] / cos($delta) * pow($delta - $phi, 3)}]
    set dha [expr {$dha + [getparameter $parameters PXH3 ] / cos($delta) * pow($ha, 3)}]

    set dha [expr {$dha + [getparameter $parameters PXD4 ] / cos($delta) * pow($delta - $phi, 4)}]
    set dha [expr {$dha + [getparameter $parameters PXH4 ] / cos($delta) * pow($ha, 4)}]

    return $dha
  }

  proc modeldalpha {parameters ha delta} {
    return [expr {-[modeldha $parameters $ha $delta]}]
  }

  proc modelddelta {parameters ha delta} {
    variable phi
    set ddelta 0
    set ddelta [expr {$ddelta + [getparameter $parameters ID]}]
    set ddelta [expr {$ddelta + [getparameter $parameters MA] * sin($ha)}]
    set ddelta [expr {$ddelta + [getparameter $parameters ME] * cos($ha)}]
    set ddelta [expr {$ddelta + [getparameter $parameters TF] * (cos($phi) * cos($ha) * sin($delta) - sin($phi) * cos($delta))}]
    set ddelta [expr {$ddelta + [getparameter $parameters FO] * cos($ha)}]
    
    set ddelta [expr {$ddelta + [getparameter $parameters HDSD] * sin($delta)}]
    set ddelta [expr {$ddelta + [getparameter $parameters HDCD] * cos($delta)}]

    set ddelta [expr {$ddelta + [getparameter $parameters HDSD2] * sin(2 * $delta)}]
    set ddelta [expr {$ddelta + [getparameter $parameters HDCD2] * cos(2 * $delta)}]

    set ddelta [expr {$ddelta + [getparameter $parameters PDD  ] * ($delta - $phi)}]
    set ddelta [expr {$ddelta + [getparameter $parameters PDH  ] * $ha}]

    set ddelta [expr {$ddelta + [getparameter $parameters PDD2 ] * pow($delta - $phi, 2)}]
    set ddelta [expr {$ddelta + [getparameter $parameters PDDH ] * ($delta - $phi) * $ha}]
    set ddelta [expr {$ddelta + [getparameter $parameters PDH2 ] * pow($ha, 2)}]

    set ddelta [expr {$ddelta + [getparameter $parameters PDD3 ] * pow($delta - $phi, 3)}]
    set ddelta [expr {$ddelta + [getparameter $parameters PDH3 ] * pow($ha, 3)}]

    set ddelta [expr {$ddelta + [getparameter $parameters PDD4 ] * pow($delta - $phi, 4)}]
    set ddelta [expr {$ddelta + [getparameter $parameters PDH4 ] * pow($ha, 4)}]

    return $ddelta
  }

  ######################################################################
  
  proc setparameter {parameters name value} {
    dict set parameters $name $value
    return $parameters
  }
  
  proc updateparameter {parameters name dvalue} {
    if {![dict exists $parameters $name]} {
      set parameters [setparameter $parameters $name 0]
    }
    set oldvalue [dict get $parameters $name]
    set newvalue [expr {$oldvalue + $dvalue}]
    return [setparameter $parameters $name $newvalue]
  }

  proc updateabsolutemodel {parameters dIH dID} {
    set parameters [updateparameter $parameters IH $dIH]
    set parameters [updateparameter $parameters ID $dID]
    return $parameters
  }

  proc updaterelativemodel {parameters dCH dID} {
    set parameters [updateparameter $parameters CH $dCH]
    set parameters [updateparameter $parameters ID $dID]
    return $parameters
  }
  
  ######################################################################
  
  proc checkaperture {aperture} {
    variable apertures
    if {![dict exists $apertures $aperture]} {
      error "invalid aperture \"$aperture\"."
    }
  }
  
  proc getaperturealphaoffset {aperture} {
    variable apertures
    checkaperture $aperture
    return [astrometry::parseangle [lindex [dict get $apertures $aperture] 0] dms]
  }

  proc getaperturedeltaoffset {aperture} {
    variable apertures
    checkaperture $aperture
    return [astrometry::parseangle [lindex [dict get $apertures $aperture] 1] dms]
  }

  ######################################################################
  
}
