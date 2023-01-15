########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "config"
package require "client"
package require "utcclock"

package provide "fitsheader" 0.0

namespace eval "fitsheader" {

  ######################################################################

  variable servers [config::getvalue "fitsheader" "servers"]   

  ######################################################################

  proc open {filename bitpix naxis {bscale 1} {bzero 0} {nframe 1} {frametime 0.0}} {
  
    if {[catch {set channel [::open $filename "w"]} message]} {
      error "unable to open FITS file \"$filename\": $message"
    }
    chan configure $channel -translation "binary" -encoding "binary"    

    writekeyandvalue $channel SIMPLE boolean true
    writekeyandvalue $channel BITPIX integer $bitpix
    writekeyandvalue $channel NAXIS  integer [llength $naxis]
    for {set i 0} {$i < [llength $naxis]} {incr i} {
      writekeyandvalue $channel NAXIS[expr {$i + 1}] integer [lindex $naxis $i]
    }
    writekeyandvalue $channel BSCALE double  $bscale
    writekeyandvalue $channel BZERO  double  $bzero
    
    set seconds [utcclock::seconds]
    writekeyandvalue $channel "DATE" date   $seconds
    writekeyandvalue $channel "MJD"  double [format "%.8f" [utcclock::mjd $seconds]]
    
    return $channel
  }  
  
  proc close {channel} {
    puts -nonewline $channel [format "%-8.8s%-72.72s" END ""]
    set n [tell $channel]
    while {$n % 2880 != 0} {
      puts -nonewline $channel [format "%80.80s" ""]
      set n [expr {$n + 80}]
    }
    ::close $channel
  }

  proc writecomment {channel comment} {
    puts -nonewline $channel [format "%-8.8s%-72.72s" "COMMENT" $comment]            
  }
  
  proc writemissing {channel key {comment ""}} {
    if {![string equal $comment ""]} {
      set value [format "%-27s / %s" "no $key value" $comment]
    }
    puts -nonewline $channel [format "%-8.8s%-72.72s" "COMMENT" $value]            
  }

  proc writekeyandvalue {channel key type value {comment ""}} {
    
    # Use fized format for boolean and integer values, as this is
    # required for SIMPLE, BITPIX, NAXIS, and NAXISn. Use free format
    # for everything else, in particular because as fixed format cannot
    # represent a 64-bit double with full accuracy.

    switch $type {
      "boolean" {
        if {![string equal $value "true"] && ![string equal $value "false"]} {
          set value ""
        } elseif {$value} {
          set value [format "= %20.20s" "T"]
        } else {
          set value [format "= %20.20s" "F"]
        }
      }
      "integer" {
        if {![string is integer -strict $value]} {
          set value ""
        } else {
          set value "= [format "%20.20s" $value]"
        }
      }
      "double" {
        if {![string is double -strict $value]} {
          set value ""
        } else {
          set value "= [string toupper $value]"
        }
      }
      "string" {
        set value [string map {"'" "''"} $value]
        # Make sure the final value will not overflow one 80-byte record.
        if {[string length $value] > 68} {
          set value [string range $value 0 67]
        }
        set value "= '$value'"
      }
      "date" {
        if {[string equal $value ""]} {
          set value ""
        } else {
          if {[string is double -strict $value]} {
            set seconds $value
          } elseif {[string equal $value "now"]} {
            set seconds [utcclock::seconds]
          } else {
            set seconds [utcclock::scan $value]
          }
          set value "= '[utcclock::combinedformat $seconds 3]'"
        }
      }
      "angle" {
        if {![string is double -strict $value]} {
          set value ""
        } else {
          set value "= [string toupper [astrometry::radtodeg $value]]"
        }
      }
      default {
        error "invalid FITS value type: $type."
      }
    }
    if {[string equal $value ""]} {
      writemissing $channel $key $comment
    } else {
      if {![string equal $comment ""]} {
        set value [format "%-27s / %s" $value $comment]
      }
      puts -nonewline $channel [format "%-8.8s%-72.72s" $key $value]            
    }  
  }

  proc writekeysandvaluesforcomponent {channel component prefix componentprefix keylist} {
  
   if {[catch {client::update $component} message]} {
     log::debug "unable to update data for \"$component\": $message"
   }
    
   set standardkeylist {
      status                      ST    string
      statustimestamp             STT   date
      requestedactivity           RQAC  string
      requestedactivitytimestamp  RQACT date
      activity                    AC    string
      activitytimestamp           ACT   date
      timestamp                   T     date
   }

   foreach {key fitskey fitstype} [concat $standardkeylist $keylist] {
     set comment "$component $key"
     if {![catch {client::getdata $component $key} value]} {
       writekeyandvalue $channel "$prefix$componentprefix$fitskey" $fitstype $value $comment
     } else {
       writemissing $channel "$prefix$componentprefix$fitskey" $comment
     }
   }

  }

  proc writekeysandvaluesforproject {channel} {

     if {[catch {client::update "executor"} message]} {
       log::debug "unable to update data for executor: $message"
     }

    foreach {key fitskey fitstype} {
      filetype               FLTP  string
      filename               FLNM  string
      projectidentifier      PRPID string
      blockidentifier        BLKID integer
      visitidentifier        VSTID integer
      projectname            PRKNM string
      blockname              BLKNM string
      visitname              VSTNM string
      alertfile              ALFL  string
      alertname              ALNM  string
      alertorigin            ALOR  string
      alertidentifier        ALID  string
      alerttype              ALTY  string
      alertalerttimestamp    ALALT date
      alerteventtimestamp    ALEVT date
      alertalpha             ALRA  angle
      alertdelta             ALDE  angle
      alertequinox           ALEQ  double
      alertuncertainty       ALUN  angle
    } {
      set comment "executor $key"
      if {![catch {client::getdata "executor" $key} value]} {
        writekeyandvalue $channel $fitskey $fitstype $value $comment
      } else {
        writemissing $channel $fitskey $comment
      }
    }
  }


  proc writekeysandvaluesforccd {channel ccd prefix componentprefix} {
    writekeysandvaluesforcomponent $channel $ccd $prefix $componentprefix {
      identifier                     ID    string
      detectorwidth                  DTWD  angle
      detectorframetime              DTFT  double
      detectorreadmode               DTRM  string
      detectorsoftwaregain           DTSG  double
      detectorbinning                DTBN  integer
      detectorfullunbinneddatawindow DTFDW string
      detectorfullunbinnedbiaswindow DTFBW string
      detectordatawindow             DTDW  string
      detectorbiaswindow             DTBW  string
      detectordetectortemperature    DTTM  double
      detectorhousingtemperature     HSTM  double
      detectorcoolerstate            CLST  string
      detectorcoolersettemperature   CLTM  double
      detectorcoolerpower            CLPW  double
      filterwheelposition            FWPS  string
      filterwheelmaxposition         FWMX  string
      filter                         FL    string
      focuserposition                FCPS  integer
      focuserminposition             FCMN  integer
      focusermaxposition             FCMX  integer
      focuserpositionerror           FCE   integer
    }
  }
  
  ######################################################################

  proc writekeysandvaluesforC0 {channel prefix} {
    writekeysandvaluesforccd $channel C0 $prefix "C0"
  }
  
  proc writekeysandvaluesforC1 {channel prefix} {
    writekeysandvaluesforccd $channel C1 $prefix "C1"
  }
  
  proc writekeysandvaluesforC2 {channel prefix} {
    writekeysandvaluesforccd $channel C2 $prefix "C2"
  }
  
  proc writekeysandvaluesforC3 {channel prefix} {
    writekeysandvaluesforccd $channel C3 $prefix "C3"
  }
  
  proc writekeysandvaluesforcovers {channel prefix} {
    writekeysandvaluesforcomponent $channel covers $prefix "CV" {
      requestedcovers       RQCV  string
      covers                CV    string
      settled               SE    boolean
      settledtimestamp      SET   date
    }
  }
  
  proc writekeysandvaluesforexecutor {channel prefix} {
    writekeysandvaluesforcomponent $channel executor $prefix "EX" {
      filetype               FLTP  string
      filename               FLNM  string
      projectidentifier      PRPID string
      blockidentifier        BLKID integer
      visitidentifier        VSTID integer
      visitname              VSTNM string
      alertfile              ALFL  string
      alerttype              ALTY  string
      alerteventidentifier   ALID  integer
      alertalerttimestamp    ALALT date
      alerteventtimestamp    ALTRT date
      alerteventtimestamp    ALEVT date
      alertalpha             ALRA  angle
      alertdelta             ALDE  angle
      alertequinox           ALEQ  double
      alertuncertainty       ALUN  angle
    }
  }
  
  proc writekeysandvaluesformoon {channel prefix} {
    writekeysandvaluesforcomponent $channel moon $prefix "MN" {
      observedalpha          RA angle
      observedha             HA angle
      observeddelta          DE angle
      observedazimuth        AZ angle
      observedzenithdistance ZD angle
      illuminatedfraction    IL double
      skystate               SK string
      observedtargetdistance TD angle
    }
  }
  
  proc writekeysandvaluesformount {channel prefix} {
    writekeysandvaluesforcomponent $channel mount $prefix "MT" {
      mountlst                    LS    angle
      mountlsterror               LSE   angle
      mounttracking               TR    boolean
      requestedobservedalpha      RORA  angle
      requestedobservedha         ROHA  angle
      requestedobserveddelta      RODE  angle
      requestedobservedalpharate  RORAR angle
      requestedobserveddeltarate  RODER angle
      requestedmountalpha         RMRA  angle
      requestedmountha            RMHA  angle
      requestedmountdelta         RMDE  angle
      requestedmountalpharate     RMRAR angle
      requestedmountdeltarate     RMDER angle
      mountalpha                  MRA   angle
      mountha                     MHA   angle
      mountdelta                  MDE   angle
      mountalphaerror             MRAE  angle
      mounthaerror                MHAE  angle
      mountdeltaerror             MDEE  angle
      mountrotation               MRO   angle
      mountmeaneasttrackingerror  MNETE angle
      mountmeannorthtrackingerror MNNTE angle
      mountrmseasttrackingerror   RMETE angle
      mountrmsnorthtrackingerror  RMNTE angle
      mountpveasttrackingerror    PVETE angle
      mountpvnorthtrackingerror   PVNTE angle
      lastcorrectiontimestamp     LCT   date
      lastcorrectiondalpha        LCRA  angle
      lastcorrectionddelta        LCDE  angle
      mountclockutcoffset         CKOF  double
    }
  }
  
  proc writekeysandvaluesforowsensors {channel prefix} {
    if {
      [catch {client::update "owsensors"} message] ||
      [catch {client::getdata "owsensors" "names"} names] ||
      [catch {client::getdata "owsensors" "keywords"} keywords]
    } {
      set names {}
      set keywords {}
    }
    set args {}
    foreach name $names keyword $keywords {
      lappend args $name
      lappend args $keyword
      lappend args "double"
    }
    writekeysandvaluesforcomponent $channel owsensors $prefix "OW" $args
  }


  proc writekeysandvaluesforsecondary {channel prefix} {
    writekeysandvaluesforcomponent $channel secondary $prefix "SC" {
      requestedz0       RQZ0  double
      requestedz        RQZ   double
      dztemperature     DZT   double
      dzposition        DZP   double
      dzoffset          DZO   double
      dzfilter          DZF   double
      z                 Z     double
      zerror            ZE    double
      zlowerlimit       ZLL   boolean
      zupperlimit       ZUL   boolean
      stoppedtimestamp  SPT   date
      settled           SE    boolean
      settledtimestamp  SET   date
    }
  }
  
  proc writekeysandvaluesforsensors {channel prefix} {
    if {
      [catch {client::update "sensors"} message] ||
      [catch {client::getdata "sensors" "names"} names] ||
      [catch {client::getdata "sensors" "keywords"} keywords]
    } {
      set names {}
      set keywords {}
    }
    set args {}
    foreach name $names keyword $keywords {
      if {![string equal $keyword ""]} {
        lappend args $name
        lappend args $keyword
        set value [client::getdata "sensors" "$name"]
        if {[string is integer -strict $value]} {
          lappend args "integer"
        } elseif {[string is double -strict $value]} {
          lappend args "double"
        } else {
          lappend args "string"
        }
        lappend args "${name}-timestamp"
        lappend args "${name}T"
        lappend args "date"
      }
    }
    writekeysandvaluesforcomponent $channel sensors $prefix "SE" $args
  }

  proc writekeysandvaluesforsun {channel prefix} {
    writekeysandvaluesforcomponent $channel sun $prefix "SN" {
      observedalpha           RA   angle
      observedha              HA   angle
      observeddelta           DE   angle
      observedazimuth         AZ   angle
      observedzenithdistance  ZD   angle
      skystate                SK   string
      observedtargetdistance  TD   angle
      startofday              STDY date
      endofday                ENDY date
      startofnight            STNG date
      endofnight              ENNG date
      mustbeclosed            MBC  boolean
    }
  }
  
  proc writekeysandvaluesfortarget {channel prefix} {
    writekeysandvaluesforcomponent $channel target $prefix "TR" {
      last                      LS    angle
      requestedalpha            RQRA  angle
      requestedha               RQHA  angle
      requesteddelta            RQDE  angle
      requestedequinox          RQEQ  double
      requestedalphaoffset      RQRAO angle
      requesteddeltaoffset      RQDEO angle
      requestedepochtimestamp   RQEPT date
      requestedalpharate        RQRAR angle
      requesteddeltarate        RQDER angle
      requestedaperture         RQAP  string
      aperturealphaoffset       APRAO angle
      aperturedeltaoffset       APDEO angle
      currentalpha              CURA  angle
      currentha                 CUHA  angle
      currentdelta              CUDE  angle
      currentequinox            CUEQ  double
      standardalpha             STRA  angle
      standarddelta             STDE  angle
      standardequinox           STEQ  double
      observedalpha             OBRA  angle
      observedha                OBHA  angle
      observeddelta             OBDE  angle
      observedalpharate         OBRAR angle
      observedharate            OBHAR angle
      observeddeltarate         OBDER angle
      observedazimuth           OBAZ  angle
      observedzenithdistance    OBZ   angle
      observedairmass           OBAM  double
      withinlimits              WL    boolean
    }
  }
  
  proc writekeysandvaluesfortelescope {channel prefix} {
    writekeysandvaluesforcomponent $channel telescope $prefix "TL" {
      operationmode         OPMD  string
    }
  }
  
  proc writekeysandvaluesforweather {channel prefix} {
    writekeysandvaluesforcomponent $channel weather $prefix "WT" {
      temperature             TM   double
      temperaturetrend        TMTR string
      dewpoint                DW   double
      dewpointtrend           DWTR string
      dewpointdepression      DD   double
      dewpointdepressiontrend DDTR string
      humidity                HM   double
      humiditytrend           HMTR string
      pressure                PR   double
      pressuretrend           PRTR string
      windaveragespeed        WDAS double
      windgustspeed           WDGS double
      windaverageazimuth      WDAZ double
      lowwindspeedseconds     WDLW double
      rainrate                RR   double
      humidityalarm           HMAL boolean
      windalarm               WDAL boolean
      rainalarm               RNAL boolean
      mustbeclosed            MBC  boolean
    }
  }
  
  ######################################################################

  proc writetcsfitsheader {channel prefix} {
    set seconds [utcclock::seconds]
    writecomment $channel "Start of TCS section \"$prefix\"."
    writekeyandvalue $channel "${prefix}DATE" date   $seconds "date TCS section written"
    writekeyandvalue $channel "${prefix}MJD"  double [format "%.8f" [utcclock::mjd $seconds]] "MJD TCS section written"
    variable servers
    foreach server $servers {
      writekeysandvaluesfor$server $channel $prefix
    }
    writecomment $channel "End of TCS section \"$prefix\"."
  }
  
  ######################################################################

  proc writeccdfitsheader {channel ccd prefix} {
    writecomment $channel "Start of CCD section \"$prefix\"."
    writekeysandvaluesforccd $channel $ccd $prefix ""
    writecomment $channel "End of CCD section \"$prefix\"."
  }
  
  ######################################################################

}
