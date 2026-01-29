########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "server"
package require "log"

if {[catch {info coroutine}]} {
  log::fatalerror "this Tcl does not have coroutines."
}

namespace eval "detector" {

  ######################################################################

  variable identifier

  proc open {identifierarg} {
    variable identifier
    set identifier $identifierarg
    log::info "opening detector \"$identifier\"."
    if {[detectorrawgetisopen]} {
      error "a detector is already open."
    }
    set result [detectorrawopen $identifier]
    if {![string equal $result ok]} {
      error $result
    }
    variable description
    set description [detectorrawgetvalue "description"]
    log::info "detector is \"$description\"."
    detectorrawsetreadmode ""
    updatestatus
    return
  }

  proc close {} {
    log::info "closing detector."
    checkisopen
    variable description
    set description {}
    set result [detectorrawclose]
    if {![string equal $result ok]} {
      error $result
    }
    return
  }

  proc reopen {} {
    log::warning "reopening detector."
    variable identifier
    while {[catch {
      coroutine::after 500
      if {[detectorrawgetisopen]} {
        close
      }
      open $identifier
    } result]} {
      log::error "unable to reopen detector: $result"
    }
    return $result
  }

  proc checkisopen {} {
    if {![isopen]} {
      error "no detector is currently open."
    }
  }

  proc isopen {} {
    return [detectorrawgetisopen]
  }

  ######################################################################

  proc reset {} {
    set result [detectorrawreset]
    if {![string equal $result ok]} {
      error $result
    }
    return
  }

  ######################################################################

  proc rawcall {args} {
    set result [eval $args]
    if {![string equal $result "ok"]} {
      reopen
      set result [eval $args]
    }
    return $result
  }

  ######################################################################

  proc setreadmode {mode} {
    log::debug "setting detector read mode to \"$mode\"."
    checkisopen
    set result [detectorrawsetreadmode $mode]
    if {![string equal $result ok]} {
      error $result
    }
    detectorrawsetunbinnedwindow 0 0 0 0
  }

  ######################################################################

  proc setsoftwaregain {detectorsoftwaregain} {
    log::debug "setting detector software gain to $detectorsoftwaregain."
    checkisopen
    set result [detectorrawsetsoftwaregain $detectorsoftwaregain]
    if {![string equal $result ok]} {
      error $result
    }
    return
  }

  ######################################################################

  proc getnframe {} {
    return [detectorrawgetpixnframe]
  }

  ######################################################################

  variable fullunbinneddatawindow ""
  variable fullunbinnedbiaswindow ""

  proc setfullunbinneddatawindow {window} {
    variable fullunbinneddatawindow
    set fullunbinneddatawindow $window
  }

  proc setfullunbinnedbiaswindow {window} {
    variable fullunbinnedbiaswindow
    set fullunbinnedbiaswindow $window
  }

  proc getfullunbinneddatawindow {} {
    variable fullunbinneddatawindow
    return $fullunbinneddatawindow
  }

  proc getfullunbinnedbiaswindow {} {
    variable fullunbinnedbiaswindow
    return $fullunbinnedbiaswindow
  }

  variable unbinneddatawindow ""
  variable unbinnedbiaswindow ""

  proc setunbinneddatawindow {window} {
    variable unbinneddatawindow
    set unbinneddatawindow $window
  }

  proc setunbinnedbiaswindow {window} {
    variable unbinnedbiaswindow
    set unbinnedbiaswindow $window
  }

  proc getunbinneddatawindow {} {
    variable unbinneddatawindow
    return $unbinneddatawindow
  }

  proc getunbinnedbiaswindow {} {
    variable unbinnedbiaswindow
    return $unbinnedbiaswindow
  }

  variable datawindow ""
  variable biaswindow ""

  proc setdatawindow {window} {
    variable datawindow
    set datawindow $window
    set sx [dict get $window "sx"]
    set sy [dict get $window "sy"]
    set nx [dict get $window "nx"]
    set ny [dict get $window "ny"]
    set result [detectorrawsetpixdatawindow $sx $sy $nx $ny]
    if {![string equal $result ok]} {
      error $result
    }
  }

  proc setbiaswindow {window} {
    variable biaswindow
    set biaswindow $window
  }

  proc getdatawindow {} {
    variable datawindow
    return $datawindow
  }

  proc getbiaswindow {} {
    variable biaswindow
    return $biaswindow
  }

  proc makebinnedwindow {window binning} {
    if {[string equal $window ""]} {
      return ""
    } else {
      set unbinnedsx [dict get $window "sx"]
      set unbinnedsy [dict get $window "sy"]
      set unbinnednx [dict get $window "nx"]
      set unbinnedny [dict get $window "ny"]
      set sx [expr {int(ceil($unbinnedsx / $binning))}]
      set sy [expr {int(ceil($unbinnedsy / $binning))}]
      set nx [expr {int(floor(($unbinnedsx + $unbinnednx) / $binning) - $sx)}]
      set ny [expr {int(floor(($unbinnedsy + $unbinnedny) / $binning) - $sy)}]
      return [dict create "sx" $sx "sy" $sy "nx" $nx "ny" $ny]
    }
  }

  proc makeoverlappedwindow {window fullwindow} {

    # Determine the corners of the two windows in the global frame.

    set llx0 [dict get $window "sx"]
    set lly0 [dict get $window "sy"]
    set urx0 [expr {[dict get $window "sx"] + [dict get $window "nx"]}]
    set ury0 [expr {[dict get $window "sy"] + [dict get $window "ny"]}]

    set llx1 [dict get $fullwindow "sx"]
    set lly1 [dict get $fullwindow "sy"]
    set urx1 [expr {[dict get $fullwindow "sx"] + [dict get $fullwindow "nx"]}]
    set ury1 [expr {[dict get $fullwindow "sy"] + [dict get $fullwindow "ny"]}]

    # Determine the corners of the overlapped window in the global frame.

    set llx [expr {max($llx0,$llx1)}]
    set lly [expr {max($lly0,$lly1)}]
    set urx [expr {min($urx0,$urx1)}]
    set ury [expr {min($ury0,$ury1)}]

    # Shift the origin to the windowed frame and calculate the overlapped window size

    set sx [expr {$llx - $llx0}]
    set sy [expr {$lly - $lly0}]
    set nx [expr {$urx - $llx}]
    set ny [expr {$ury - $lly}]

    if {$nx > 0 && $ny > 0} {
      return [dict create "sx" $sx "sy" $sy "nx" $nx "ny" $ny]
    } else {
      return ""
    }

  }

  proc setunbinnedwindow {window} {
    log::debug "setting detector window to \"$window\"."
    checkisopen
    if {[string equal $window "full"]} {
      set sx 0
      set sy 0
      set nx 0
      set ny 0
    } else {
      set sx [dict get $window "sx"]
      set sy [dict get $window "sy"]
      set nx [dict get $window "nx"]
      set ny [dict get $window "ny"]
    }
    set result [detectorrawsetunbinnedwindow $sx $sy $nx $ny]
    if {![string equal $result ok]} {
      error $result
    }
    if {[string equal $window "full"]} {
      setunbinneddatawindow [getfullunbinneddatawindow]
      setunbinnedbiaswindow [getfullunbinnedbiaswindow]
    } else {
      setunbinneddatawindow [makeoverlappedwindow $window [getfullunbinneddatawindow]]
      setunbinnedbiaswindow [makeoverlappedwindow $window [getfullunbinnedbiaswindow]]
    }
    setbinning 1
    return
  }

  proc setbinning {binning} {
    log::debug "setting detector binning to $binning."
    checkisopen
    set result [detectorrawsetbinning $binning]
    if {![string equal $result ok]} {
      error $result
    }
    setdatawindow [makebinnedwindow [getunbinneddatawindow] $binning]
    setbiaswindow [makebinnedwindow [getunbinnedbiaswindow] $binning]
    return
  }

  ######################################################################

  proc setcooler {setting} {
    if {![string equal "current" $setting]} {
      log::debug "setting cooler to $setting."
      checkisopen
      set result [detectorrawsetcooler $setting]
      if {![string equal $result ok]} {
        error $result
      }
    }
    return
  }

  ######################################################################

  proc startexposure {exposuretime shutter {fitscubepixfilename ""}} {
    log::debug "starting the exposure."
    checkisopen
    set result [detectorrawexpose $exposuretime $shutter]
    if {![string equal $result ok]} {
      error "unable to start the exposure: $result."
    }
    detectorrawpixstart
    if {![string equal $fitscubepixfilename ""]} {
      detectorrawcubepixstart $fitscubepixfilename
    }
  }

  proc cancelexposure {} {
    log::debug "cancelling the exposure."
    checkisopen
    set result [detectorrawcancel]
    if {![string equal $result "ok"] && ![string equal $result "wait"]} {
      error "unable to cancel the exposure."
    }
    return $result
  }

  proc continueexposure {} {
    checkisopen
    return [expr {![detectorrawgetreadytoberead]}]
  }

  proc waitforexposure {} {
    log::debug "waiting for the end of the exposure."
    checkisopen
    while {![detectorrawgetreadytoberead]} {
      coroutine::after 100
    }
    return
  }

  proc readexposure {} {
    log::debug "waiting to read the exposure."
    checkisopen
    # This is a hack to allow the instrument time to notice the detector is
    # being read.
    variable readdelaymilliseconds
    set delaymilliseconds 0
    while {$delaymilliseconds < $readdelaymilliseconds} {
      coroutine::after 100
      set delaymilliseconds [expr {$delaymilliseconds + 100}]
    }
    while {![detectorrawgetreadytoberead]} {
      coroutine::after 100
    }
    log::debug "reading the exposure."
    set result [detectorrawread]
    if {![string equal $result "ok"]} {
      error "error while reading the pixel data: $result"
    }
    detectorrawupdatestatistics
    variable average
    variable standarddeviation
    set average           [detectorrawgetvalue "average"]
    set standarddeviation [detectorrawgetvalue "standarddeviation"]
    log::info [format "level is %.1f ± %.1f DN." $average $standarddeviation]
    log::debug "finished reading the exposure."
    return
  }

  ######################################################################

  proc openfitsheader {fitsfilename} {
    variable bscale
    variable bzero
    set nx [detectorrawgetpixnx]
    set ny [detectorrawgetpixny]
    set naxis [list $nx $ny]
    return [fitsheader::open $fitsfilename 16 $naxis $bscale $bzero]
  }

  proc openfitscubeheader {fitsfilename} {
    variable bscale
    variable bzero
    set nx [detectorrawgetpixnx]
    set ny [detectorrawgetpixny]
    set nz [getnframe]
    set naxis [list $nx $ny $nz]
    return [fitsheader::open $fitsfilename 16 $naxis $bscale $bzero]
  }

  proc closefitsheader {channel} {
    detectorrawaugmentfitsheader $channel
    return [fitsheader::close $channel]
  }

  proc writeexposure {partialfitsfilename finalfilename {latestfilename ""} {currentfilename ""} {partialfitscubehdrfilename ""}  {finalcubehdrfilename ""}  {partialfitscubepixfilename ""}  {finalcubepixfilename ""} {fork false}} {
    log::debug "writing the exposure."
    checkisopen
    if {[string equal $partialfitsfilename ""]} {
      error "the partial FITS file name is \"\"."
    }
    if {![file exists $partialfitsfilename]} {
      error "the partial FITS file \"$partialfitsfilename\" does not exist."
    }
    if {[string equal $finalfilename ""]} {
      error "the final FITS file name is \"\"."
    }
    if {[catch {file mkdir [file dirname $finalfilename]}]} {
      error "unable to write the exposure data: cannot create the directory \"[file dirname $finalfilename]\"."
    }
    if {![string equal $latestfilename ""]} {
      if {[catch {file mkdir [file dirname $latestfilename]}]} {
        error "unable to write the exposure data: cannot create the directory \"[file dirname $latestfilename]\"."
      }
    }
    if {![string equal $currentfilename ""]} {
      if {[catch {file mkdir [file dirname $currentfilename]}]} {
        error "unable to write the exposure data: cannot create the directory \"[file dirname $currentfilename]\"."
      }
    }
    if {![string equal $partialfitscubehdrfilename ""] && ![file exists $partialfitscubehdrfilename]} {
      error "the partial FITS cube hdr file \"$partialfitscubehdrfilename\" does not exist."
    }
    if {![string equal $partialfitscubepixfilename ""] && ![file exists $partialfitscubepixfilename]} {
      error "the partial FITS cube pix file \"$partialfitscubepixfilename\" does not exist."
    }
    if {![string equal $finalcubehdrfilename ""]} {
      if {[catch {file mkdir [file dirname $finalcubehdrfilename]}]} {
        error "unable to write the exposure data: cannot create the directory \"[file dirname $finalcubehdrfilename]\"."
      }
    }
    if {![string equal $finalcubepixfilename ""]} {
      if {[catch {file mkdir [file dirname $finalcubepixfilename]}]} {
        error "unable to write the exposure data: cannot create the directory \"[file dirname $finalcubepixfilename]\"."
      }
    }
    variable bscale
    variable bzero
    if {$fork} {
      set dofork 1
    } else {
      set dofork 0
    }
    detectorrawpixend
    if {![string equal $partialfitscubehdrfilename ""]} {
      file rename -force $partialfitscubehdrfilename $finalcubehdrfilename
    }
    if {![string equal $partialfitscubepixfilename ""]} {
      detectorrawcubepixend
      file rename -force $partialfitscubepixfilename $finalcubepixfilename
    }
    set result [detectorrawappendfitsdata $partialfitsfilename $finalfilename $latestfilename $currentfilename $dofork $bscale $bzero]
    if {![string equal $result "ok"]} {
      error "unable to write the exposure data: $result"
    }
    log::debug "finished writing the exposure."
    return
  }

  ######################################################################

  variable description              {}
  variable readmode                 {}
  variable adc                      {}
  variable amplifier                {}
  variable vsspeed                  {}
  variable hsspeed                  {}
  variable gain                     {}
  variable emgain                   {}
  variable frametime                {}
  variable cycletime                {}
  variable minexposuretime          {}
  variable maxexposuretime          {}
  variable softwaregain             {}
  variable rawsaturationlevel       65535
  variable saturationlevel          {}
  variable unbinnedwindow           {}
  variable binning                  {}
  variable detectortemperature      {}
  variable housingtemperature       {}
  variable coldendtemperature       {}
  variable powersupplytemperature   {}
  variable chamberpressure          {}
  variable compressorsupplypressure {}
  variable compressorreturnpressure {}
  variable compressorcurrent        {}
  variable detectorheatercurrent    {}
  variable coldendheatercurrent     {}
  variable coolerstate              {}
  variable coolersettemperature     {}
  variable coolerpower              {}
  variable average                  {}
  variable standarddeviation        {}
  variable saasigmax                {}
  variable saasigmay                {}

  proc getdescription {} {
    variable description
    return $description
  }

  proc getreadmode {} {
    variable readmode
    return $readmode
  }

  proc getamplifier {} {
    variable amplifier
    return $amplifier
  }

  proc getadc {} {
    variable adc
    return $adc
  }

  proc getvsspeed {} {
    variable vsspeed
    return $vsspeed
  }

  proc gethsspeed {} {
    variable hsspeed
    return $hsspeed
  }

  proc getgain {} {
    variable gain
    return $gain
  }

  proc getemgain {} {
    variable emgain
    return $emgain
  }

  proc getframetime {} {
    variable frametime
    return $frametime
  }

  proc getcycletime {} {
    variable cycletime
    return $cycletime
  }

  proc getminexposuretime {} {
    variable minexposuretime
    return $minexposuretime
  }

  proc getmaxexposuretime {} {
    variable maxexposuretime
    return $maxexposuretime
  }

  proc getsoftwaregain {} {
    variable softwaregain
    return $softwaregain
  }

  proc getsaturationlevel {} {
    variable saturationlevel
    return $saturationlevel
  }

  proc getunbinnedwindow {} {
    variable unbinnedwindow
    return $unbinnedwindow
  }

  proc getbinning {} {
    variable binning
    return $binning
  }

  proc getdetectortemperature {} {
    variable detectortemperature
    return $detectortemperature
  }

  proc gethousingtemperature {} {
    variable housingtemperature
    return $housingtemperature
  }

  proc getcoldendtemperature {} {
    variable coldendtemperature
    return $coldendtemperature
  }

  proc getpowersupplytemperature {} {
    variable powersupplytemperature
    return $powersupplytemperature
  }

  proc getchamberpressure {} {
    variable chamberpressure
    return $chamberpressure
  }

  proc getcompressorsupplypressure {} {
    variable compressorsupplypressure
    return $compressorsupplypressure
  }

  proc getcompressorreturnpressure {} {
    variable compressorreturnpressure
    return $compressorreturnpressure
  }

  proc getcompressorcurrent {} {
    variable compressorcurrent
    return $compressorcurrent
  }

  proc getdetectorheatercurrent {} {
    variable detectorheatercurrent
    return $detectorheatercurrent
  }

  proc getcoldendheatercurrent {} {
    variable coldendheatercurrent
    return $coldendheatercurrent
  }

  proc getcoolerstate {} {
    variable coolerstate
    return $coolerstate
  }

  proc getcoolerlowflow {} {
    variable coolerlowflow
    return $coolerlowflow
  }

  proc getcoolersettemperature {} {
    variable coolersettemperature
    return $coolersettemperature
  }

  proc getcoolerpower {} {
    variable coolerpower
    return $coolerpower
  }

  proc getaverage {} {
    variable average
    return $average
  }

  proc getstandarddeviation {} {
    variable standarddeviation
    return $standarddeviation
  }

  proc getsaasigmax {} {
    variable saasigmax
    return $saasigmax
  }

  proc getsaasigmay {} {
    variable saasigmay
    return $saasigmay
  }

  proc updatestatus {} {

    variable readmode
    variable adc
    variable amplifier
    variable vsspeed
    variable hsspeed
    variable gain
    variable emgain
    variable frametime
    variable cycletime
    variable minexposuretime
    variable maxexposuretime
    variable softwaregain
    variable saturationlevel
    variable unbinnedwindow
    variable binning
    variable detectortemperature
    variable detectorheatercurrent
    variable housingtemperature
    variable coldendtemperature
    variable coldendheatercurrent
    variable powersupplytemperature
    variable chamberpressure
    variable compressorsupplypressure
    variable compressorreturnpressure
    variable compressorcurrent
    variable coolersettemperature
    variable coolerpower
    variable coolerstate
    variable coolerlowflow
    variable saasigmax
    variable saasigmay

    set readmode                 {}
    set adc                      {}
    set amplifier                {}
    set vsspeed                  {}
    set hsspeed                  {}
    set gain                     {}
    set emgain                   {}
    set frametime                {}
    set cycletime                {}
    set minexposuretime          {}
    set maxexposuretime          {}
    set softwaregain             {}
    set saturationlevel          {}
    set window                   {}
    set binning                  {}
    set detectortemperature      {}
    set housingtemperature       {}
    set coldendtemperature       {}
    set powersupplytemperature   {}
    set chamberpressure          {}
    set compressorsupplypressure {}
    set compressorreturnpressure {}
    set compressorcurrent        {}
    set coolerstate              {}
    set coolersettemperature     {}
    set coolerpower              {}
    set coolerlowflow            {}
    set saasigmax                {}
    set saasigmay                {}

    checkisopen

    set result [rawcall detectorrawupdatestatus]
    if {![string equal $result "ok"]} {
      log::warning "unable to update the detector: $result"
      return
    }

    set unbinnedwindow [dict create \
      "sx" [detectorrawgetvalue "unbinnedwindowsx"] \
      "sy" [detectorrawgetvalue "unbinnedwindowsy"] \
      "nx" [detectorrawgetvalue "unbinnedwindownx"] \
      "ny" [detectorrawgetvalue "unbinnedwindowny"] \
    ]
    set readmode                 [detectorrawgetvalue "readmode"]
    set adc                      [detectorrawgetvalue "adc"]
    set amplifier                [detectorrawgetvalue "amplifier"]
    set vsspeed                  [detectorrawgetvalue "vsspeed"]
    set hsspeed                  [detectorrawgetvalue "hsspeed"]
    set gain                     [detectorrawgetvalue "gain"]
    set emgain                   [detectorrawgetvalue "emgain"]
    set frametime                [detectorrawgetvalue "frametime"]
    set cycletime                [detectorrawgetvalue "cycletime"]
    set minexposuretime          [detectorrawgetvalue "minexposuretime"]
    set maxexposuretime          [detectorrawgetvalue "maxexposuretime"]
    set binning                  [detectorrawgetvalue "binning"]
    set detectortemperature      [detectorrawgetvalue "detectortemperature"]
    set detectorheatercurrent    [detectorrawgetvalue "detectorheatercurrent"]
    set housingtemperature       [detectorrawgetvalue "housingtemperature"]
    set coldendtemperature       [detectorrawgetvalue "coldendtemperature"]
    set coldendheatercurrent     [detectorrawgetvalue "coldendheatercurrent"]
    set powersupplytemperature   [detectorrawgetvalue "powersupplytemperature"]
    set chamberpressure          [detectorrawgetvalue "chamberpressure"]
    set compressorreturnpressure [detectorrawgetvalue "compressorreturnpressure"]
    set compressorsupplypressure [detectorrawgetvalue "compressorsupplypressure"]
    set compressorcurrent        [detectorrawgetvalue "compressorcurrent"]
    set coolerstate              [detectorrawgetvalue "cooler"]
    set coolerlowflow            [detectorrawgetvalue "coolerlowflow"]
    set coolersettemperature     [detectorrawgetvalue "coolersettemperature"]
    set coolerpower              [detectorrawgetvalue "coolerpower"]
    set softwaregain             [detectorrawgetvalue "softwaregain"]
    set saasigmax                [detectorrawgetvalue "saasigmax"]
    set saasigmay                [detectorrawgetvalue "saasigmay"]

    variable rawsaturationlevel
    set saturationlevel [expr {int($rawsaturationlevel / $softwaregain)}]

  }

######################################################################

}
