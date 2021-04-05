########################################################################

# This file is part of the UNAM telescope control system.

# $Id: detectorh2rg.tcl 3588 2020-05-26 23:41:05Z Alan $

########################################################################

# Copyright © 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "directories"

package provide "detectorh2rg" 0.0

load [file join [directories::prefix] "lib" "detectorh2rg.so"] "detector"

namespace eval "detector" {

  variable bscale 1.0
  variable bzero  0.0

  ######################################################################

  variable rawfitspath
  variable identifier

  proc detectorrawstart {} {
    set identifier [server::getdata "identifier"]
    set rawfitsdirectory [file join [directories::var] $identifier]
    file mkdir $rawfitsdirectory
    variable rawfitspath
    set rawfitspath [file join $rawfitsdirectory "raw.fits"]
    global env
    set env(RAWFITSPATH) $rawfitspath    
  }
  
  ######################################################################
  
  proc reset {} {
    return
    log::info "h2rg: resetting."
    log::debug "h2rg: writing true to /data?/kill_hxrg files."
    foreach path {
      /data1/kill_hxrg
      /data2/kill_hxrg
    } {
      set channel [::open $path "w"]
      puts $channel "true"
      ::close $channel
    }
    log::debug "h2rg: waiting for /data?/kill_hxrg files to change to false."
    foreach path {
      /data1/kill_hxrg
      /data2/kill_hxrg
    } {
      while {true} {
        set channel [::open $path "r"]
        set line [gets $channel]
        ::close $channel
        if {[string equal $line "false"]} {
          break
        }
        coroutine::after 1000
      }
    }
    log::debug "h2rg: waiting extra 60 seconds."
    coroutine::after 60000
    log::info "h2rg: finished resetting."
  }
  
  ######################################################################

  proc detectorrawaugmentfitsheader {channel} {

    variable readmode
    fitsheader::writekeyandvalue $channel "NREADS" integer $readmode
    
    fitsheader::writecomment $channel "Start of Teledyne section."
    variable rawfitspath
    set rawchannel [::open $rawfitspath]
    chan configure $rawchannel -translation "binary" -encoding "binary"    
    while {true} {
      set record [read $rawchannel 80]
      if {[string length $record] != 80} {
        break
      }
      set key [string trimright [string range $record 0 7] " "]
      if {[string equal $key "END"]} {
        break
      }
      switch $key {
        "ACQTIME"  -
        "ACQTYPE"  -
        "UNITS"    -
        "LONGSTRN" -
        "NEXTRAP"  -
        "NEXTRAL"  -
        "ASIC_NUM" -
        "SCA_ID"   -
        "MUXTYPE"  -
        "NOUTPUTS" -
        "NADCS"    -
        "PDDECTOR" -
        "CLKOFF"   -
        "WARMTST"  -
        "CLOCKING" -
        "GLBRESET" -
        "FRMODE"   -
        "EXPMODE"  -
        "NRESETS"  -
        "FRMTIME"  -
        "DATAMODE" -
        "DATLEVEL" -
        "ASICGAIN" -
        "NOMGAIN"  -
        "AMPRESET" -
        "KTCREMOV" -
        "SRCCUR"   -
        "AMPINPUT" -
        "V4V3V2V1" -
        "TSTATION" -
        "HXRGVER"  -
        "MCLK "    -
        "FITSFILE" -
        "CONTINUE" {
          puts -nonewline $channel $record
        }    
        "ACQTIME1" {
          set newrecord [string replace $record 21 21 "T"]
          puts -nonewline $channel $newrecord
        }
      }
    }
    ::close $rawchannel
    fitsheader::writecomment $channel "End of Teledyne section."

  }

  ######################################################################
  
  proc detectorrawgetdetectortemperature {} {
    return ""
  }
  
  ######################################################################

  proc detectorrawgethousingtemperature {} {
    return ""
  }

  ######################################################################

  proc detectorrawgetcoolerstate {} {
    return ""
  }

  ######################################################################

  proc detectorrawgetcoolersettemperature {} {
    return ""
  }

  ######################################################################

  proc detectorrawgetcoolerpower {} {
    return ""
  }

  ######################################################################
  
}

source [file join [directories::prefix] "lib" "tcs" "detector.tcl"]
