########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2013, 2014, 2015, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "directories"
package require "fitfocus"
package require "fitsheader"
package require "log"
package require "pointing"
package require "server"
package require "target"

package require "detector[config::getvalue [config::getvalue "ccd" "identifier"] "detectortype"]"
package require "focuser[config::getvalue [config::getvalue "ccd" "identifier"] "focusertype"]"
package require "filterwheel[config::getvalue [config::getvalue "ccd" "identifier"] "filterwheeltype"]"

package provide "ccd" 0.0

namespace eval "ccd" {

  ######################################################################

  variable identifier [config::getvalue "ccd" "identifier"]
  
  config::setdefaultvalue $identifier "startoutletgroups" ""
  config::setdefaultvalue $identifier "lastcoolersetting" "off"

  variable telescopedescription            [config::getvalue $identifier "telescopedescription"           ]
  variable detectortype                    [config::getvalue $identifier "detectortype"                   ]
  variable detectoridentifier              [config::getvalue $identifier "detectoridentifier"             ]
  variable detectorinitialsoftwaregain     [config::getvalue $identifier "detectorinitialsoftwaregain"    ]
  variable detectorinitialbinning          [config::getvalue $identifier "detectorinitialbinning"         ]
  variable detectorfullunbinneddatawindow  [config::getvalue $identifier "detectorfullunbinneddatawindow" ]
  variable detectorfullunbinnedbiaswindow  [config::getvalue $identifier "detectorfullunbinnedbiaswindow" ]
  variable detectorwindows                 [config::getvalue $identifier "detectorwindows"                ]
  variable detectorreadmodes               [config::getvalue $identifier "detectorreadmodes"              ]
  variable coolerstartsetting              [config::getvalue $identifier "coolerstartsetting"             ]
  variable cooleropensetting               [config::getvalue $identifier "cooleropensetting"              ]
  variable coolerclosedsetting             [config::getvalue $identifier "coolerclosedsetting"            ]
  variable filterwheeltype                 [config::getvalue $identifier "filterwheeltype"                ]
  variable filterwheelidentifier           [config::getvalue $identifier "filterwheelidentifier"          ]
  variable filters                         [config::getvalue $identifier "filters"                        ]
  variable focusertype                     [config::getvalue $identifier "focusertype"                    ]
  variable focuseridentifier               [config::getvalue $identifier "focuseridentifier"              ]
  variable focuserinitialposition          [config::getvalue $identifier "focuserinitialposition"         ]
  variable focuserbacklashoffset           [config::getvalue $identifier "focuserbacklashoffset"          ]
  variable focuserdzmodel                  [config::getvalue $identifier "focuserdzmodel"                 ]
  variable allowedfocuserpositionerror     [config::getvalue $identifier "allowedfocuserpositionerror"    ]
  variable isstandalone                    [config::getvalue $identifier "isstandalone"                   ]
  variable detectorunbinnedpixelscale      [astrometry::parseangle [config::getvalue $identifier "detectorunbinnedpixelscale"]]
  variable pointingmodelparameters         [config::getvalue $identifier "pointingmodelparameters"        ]
  variable temperaturelimit                [config::getvalue $identifier "temperaturelimit"               ]
  variable temperaturelimitoutletgroup     [config::getvalue $identifier "temperaturelimitoutletgroup"    ]
  variable fitsfwhmargs                    [config::getvalue $identifier "fitsfwhmargs"                   ]
  variable startoutletgroups               [config::getvalue $identifier "startoutletgroups"              ]

  ######################################################################
  
  set server::datalifeseconds 10

  server::setdata "identifier"                        $identifier
  server::setdata "telescopedescription"              $telescopedescription
  server::setdata "detectortype"                      $detectortype
  server::setdata "detectoridentifier"                $detectoridentifier
  server::setdata "detectorwidth"                     ""
  server::setdata "filterwheeltype"                   $filterwheeltype
  server::setdata "filterwheelidentifier"             $filterwheelidentifier
  server::setdata "focusertype"                       $focusertype
  server::setdata "focuseridentifier"                 $focuseridentifier
  server::setdata "timestamp"                         ""
  server::setdata "filterwheelposition"               ""
  server::setdata "lastfilterwheelposition"           ""
  server::setdata "requestedfilterwheelposition"      ""
  server::setdata "filter"                            ""
  server::setdata "focuserposition"                   ""
  server::setdata "focuserrawposition"                ""
  server::setdata "requestedfocuserposition"          ""
  server::setdata "requestedfocuserrawposition"       ""
  server::setdata "focuserdz"                         0
  server::setdata "focuserdzfilter"                   0
  server::setdata "focuserdzposition"                 0
  server::setdata "exposuretime"                      ""
  server::setdata "fitsfilename"                      ""
  server::setdata "lastcorrectiontimestamp"           ""
  server::setdata "lastcorrectioneastoffset"          ""
  server::setdata "lastcorrectionnorthoffset"         ""
  server::setdata "solvedalpha"                       ""
  server::setdata "solveddelta"                       ""
  server::setdata "solvedequinox"                     ""
  server::setdata "solvedobservedalpha"               ""
  server::setdata "solvedobserveddelta"               ""
  server::setdata "mountobservedalpha"                ""
  server::setdata "mountobserveddelta"                ""
  server::setdata "fwhm"                              ""
  server::setdata "fwhmpixels"                        ""
  server::setdata "average"                           ""
  server::setdata "standarddeviation"                 ""
  
  proc updatedata {} {
  
    variable detectorunbinnedpixelscale

    set identifier [server::getdata "identifier"]
    
    if {![detector::isopen] || ![focuser::opened]} {
      return
    }
    
    if {[catch {detector::updatestatus} message]} {
      error "unable to update detector status: $message"
    }
    
    if {[catch {focuser::update} message]} {
      error "unable to update focuser data: $message"
    }
    
    set lasttimestamp                [server::getdata "timestamp"]
    set timestamp                    [utcclock::combinedformat now]

    set lastfilterwheelposition           [server::getdata "filterwheelposition"]
    set filterwheelposition               [filterwheel::getposition]
    set requestedfilterwheelposition      [server::getdata "requestedfilterwheelposition"]
    
    set lastfocuserrawposition [server::getdata "focuserrawposition"]
    set focuserrawposition     [focuser::getposition]
    set lastfocuserposition    [server::getdata "focuserposition"]
    set focuserdz              [server::getdata "focuserdz"]
    set focuserposition        [expr {$focuserrawposition - $focuserdz}]

    set requestedfocuserrawposition [server::getdata "requestedfocuserrawposition"]
    if {[catch {
      expr {$focuserrawposition - $requestedfocuserrawposition}
    } focuserpositionerror]} {
      set focuserpositionerror ""
    }

    set detectortemperature [detector::getdetectortemperature]
    set housingtemperature  [detector::gethousingtemperature]

    variable temperaturelimit
    if {![string equal "" $temperaturelimit]} {

      set toowarm false
  
      if {$detectortemperature > $temperaturelimit} {
        log::error [format "switching off cooling as the detector is too warm (%+.1f C)." $detectortemperature]
        set toowarm true
      }

      if {$housingtemperature > $temperaturelimit} {
        log::error [format "switching off cooling as the housing is too warm (%+.1f C)." $housingtemperature]
        set toowarm true
      }

      if {$toowarm} {
        setcoolerhelper "off"
        variable temperaturelimitoutletgroup
        if {![string equal "" $temperaturelimitoutletgroup]} {
          log::error "performing an emergency stop."
          exec "[directories::prefix]/bin/tcs" "emergencystop" $temperaturelimitoutletgroup
        }
        log::error "exiting."
        exit 1
      }
      
    }
    
    server::setstatus "ok"

    server::setdata "timestamp"                        [utcclock::combinedformat $timestamp]
    server::setdata "lasttimestamp"                    $lasttimestamp
    server::setdata "detectordescription"              [detector::getdescription]
    server::setdata "detectorsoftwaregain"             [detector::getsoftwaregain]
    server::setdata "detectorsaturationlevel"          [detector::getsaturationlevel]
    server::setdata "detectorunbinnedwindow"           [detector::getunbinnedwindow]
    server::setdata "detectorwidth"                    [getwidth]
    server::setdata "detectorbinning"                  [detector::getbinning]
    server::setdata "detectorfullunbinneddatawindow"   [detector::getfullunbinneddatawindow]
    server::setdata "detectorfullunbinnedbiaswindow"   [detector::getfullunbinnedbiaswindow]
    server::setdata "detectordatawindow"               [detector::getdatawindow]
    server::setdata "detectorbiaswindow"               [detector::getbiaswindow]
    server::setdata "detectorreadmode"                 [detector::getreadmode]
    server::setdata "detectoradc"                      [detector::getadc]
    server::setdata "detectoramplifier"                [detector::getamplifier]
    server::setdata "detectorvsspeed"                  [detector::getvsspeed]
    server::setdata "detectorhsspeed"                  [detector::gethsspeed]
    server::setdata "detectorgain"                     [detector::getgain]
    server::setdata "detectoremgain"                   [detector::getemgain]
    server::setdata "detectorframetime"                [detector::getframetime]
    server::setdata "detectorcycletime"                [detector::getcycletime]
    server::setdata "detectordetectortemperature"      $detectortemperature
    server::setdata "detectordetectorheatercurrent"    [detector::getdetectorheatercurrent]
    server::setdata "detectorhousingtemperature"       $housingtemperature
    server::setdata "detectorcoldendtemperature"       [detector::getcoldendtemperature]
    server::setdata "detectorcoldendheatercurrent"     [detector::getcoldendheatercurrent]
    server::setdata "detectorpowersupplytemperature"   [detector::getpowersupplytemperature]
    server::setdata "detectorchamberpressure"          [detector::getchamberpressure]
    server::setdata "detectorcompressorsupplypressure" [detector::getcompressorsupplypressure]
    server::setdata "detectorcompressorreturnpressure" [detector::getcompressorreturnpressure]
    server::setdata "detectorcompressorcurrent"        [detector::getcompressorcurrent]
    server::setdata "detectorcoolerstate"              [detector::getcoolerstate]
    server::setdata "detectorcoolersettemperature"     [detector::getcoolersettemperature]
    server::setdata "detectorcoolerpower"              [detector::getcoolerpower]
    server::setdata "detectorcoolerlowflow"            [detector::getcoolerlowflow]
    server::setdata "detectorsaasigmax"                [expr {[detector::getsaasigmax] * [detector::getbinning] * $detectorunbinnedpixelscale}]
    server::setdata "detectorsaasigmay"                [expr {[detector::getsaasigmay] * [detector::getbinning] * $detectorunbinnedpixelscale}]
    server::setdata "filterwheels"                     [llength [filterwheel::getdescription]]
    set i 0
    while {$i < [llength [filterwheel::getdescription]]} {
      server::setdata "filterwheeldescription$i"  [lindex [filterwheel::getdescription] $i]
      incr i
    }
    server::setdata "filterwheelposition"              $filterwheelposition
    server::setdata "lastfilterwheelposition"          $lastfilterwheelposition
    server::setdata "filterwheelmaxposition"           [filterwheel::getmaxposition]
    server::setdata "filter"                           [getfilter $filterwheelposition]
    server::setdata "focuserdescription"               [focuser::getdescription]
    server::setdata "focuserposition"                  $focuserposition
    server::setdata "focuserrawposition"               $focuserrawposition
    server::setdata "focuserminposition"               [focuser::getminposition]
    server::setdata "focusermaxposition"               [focuser::getmaxposition]
    server::setdata "focuserpositionerror"             $focuserpositionerror
    
    log::writedatalog $identifier {
      timestamp
      detectordetectortemperature 
      detectorhousingtemperature
      detectorcoolerpower
      detectorcoolerstate
      detectorcoolersettemperature 
      detectorcoldendtemperature
      detectorchamberpressure
      detectorcompressorsupplypressure
      detectorcompressorreturnpressure
      detectorpowersupplytemperature
    }
    
    foreach {sensorname dataname} {
      detector-detector-temperature       detectordetectortemperature 
      detector-housing-temperature        detectorhousingtemperature
      detector-cold-end-temperature       detectorcoldendtemperature
      detector-power-supply-temperature   detectorpowersupplytemperature
      detector-chamber-pressure           detectorchamberpressure
      detector-compressor-supply-pressure detectorcompressorsupplypressure
      detector-compressor-return-pressure detectorcompressorreturnpressure
      detector-cooler-power               detectorcoolerpower
      detector-cooler-state               detectorcoolerstate
      detector-cooler-set-temperature     detectorcoolersettemperature
      filter-wheel-position               filterwheelposition
      focuser-position                    focuserposition
      focuser-raw-position                focuserrawposition
    } {
      log::writesensorsfile "$identifier-$sensorname" [server::getdata $dataname] [server::getdata "timestamp"]
    }

  }
  
  proc getfilter {filterwheelposition} {
    variable filters
    foreach filter [dict keys $filters] {
      set position [dict get $filters $filter]
      if {[string equal $position $filterwheelposition]} {
        return $filter
      }
    }
    return ""
  }
  
  ######################################################################

  variable pollmilliseconds 1000

  proc updatedataloop {} {
    while {true} {
      if {[catch {updatedata} message]} {
        log::error "error while updating data: $message"
      }
      server::resumeactivitycommand
      variable pollmilliseconds
      coroutine::after $pollmilliseconds
    }
  }

  ######################################################################

  proc checkfocuserpositionerror {when} {
    updatedata
    set focuserpositionerror [server::getdata "focuserpositionerror"]
    variable allowedfocuserpositionerror
    if {abs($focuserpositionerror) > $allowedfocuserpositionerror} {
      log::warning [format "focuser position error is %+d $when." $focuserpositionerror]
    }
  }

  ######################################################################
  
  proc mountdalpha {alpha delta} {
    set ha [astrometry::ha $alpha]
    variable pointingmodelparameters
    return [pointing::modeldalpha $pointingmodelparameters $ha $delta]
  }

  proc mountddelta {alpha delta} {
    set ha [astrometry::ha $alpha]
    variable pointingmodelparameters
    return [pointing::modelddelta $pointingmodelparameters $ha $delta]
  }

  proc updatepointingmodel {dCH dID} {
    variable identifier
    variable pointingmodelparameters
    set pointingmodelparameters [pointing::updaterelativemodel $pointingmodelparameters $dCH $dID]
#    config::setvarvalue $identifier "pointingmodelparameters" $pointingmodelparameters
  }

  ######################################################################
  
  proc getfitsfilename {exposuretype fitsfileprefix} {
    variable identifier
    switch $exposuretype {
      "object" -
      "focus" -
      "astrometry" {
        set suffix "o"
      }
      "bias" {
        set suffix "b"
      }
      "dark" {
        set suffix "d"
      }
      "flat" {
        set suffix "f"
      }
      default {
        set suffix "x"
      }
    }
    return "$fitsfileprefix$identifier$suffix.fits"
  }

  proc getfitscubefilename {exposuretype fitsfileprefix} {
    variable identifier
    switch $exposuretype {
      "object" -
      "focus" -
      "astrometry" {
        set suffix "oc"
      }
      "bias" {
        set suffix "bc"
      }
      "dark" {
        set suffix "dc"
      }
      "flat" {
        set suffix "fc"
      }
      default {
        set suffix "xc"
      }
    }
    return "$fitsfileprefix$identifier$suffix.fits"
  }

  ######################################################################

  proc stopexposing {} {
    while {true} {
      if {[catch {detector::cancelexposure} result]} {
        log::warning $result
      }
      if {[string equal $result "ok"]} {
        break
      }
      coroutine::after 100
    }
  }

  variable solvingchannel {}

  proc stopsolving {} {
    variable solvingchannel
    if {![catch {pid $solvingchannel} solvingpid]} {
      if {[catch {exec "/bin/kill" "-TERM" "-$solvingpid"} message]} {
        log::warning "killing the solving process group failed: $message."
      }
    }
    catch {close $solvingchannel}
    set solvingchannel {}
  }

  proc startactivitycommand {} {
    set start [utcclock::seconds]
    log::info "starting."
    coroutine::yield
    variable startoutletgroups
    if {[llength $startoutletgroups] != 0} {
      foreach outletgroup $startoutletgroups {
        log::info "rebooting $outletgroup."
        client::waituntilstarted "power"
        client::wait "power"
        client::request "power" "reboot $outletgroup"
        client::wait "power"
      }
    }
    log::info "starting detector."
    if {[catch {detector::detectorrawstart} message]} {
      error "unable to start detector: $message"
    }
    variable detectoridentifier
    while {[catch {detector::open $detectoridentifier} message]} {
      log::warning "unable to open detector: $message"
      coroutine::after 5000
    }
    setcoolerhelper "start"
    variable filterwheelidentifier
    if {[catch {filterwheel::filterwheelrawstart} message]} {
      error "unable to start filter wheel: $message"
    }
    while {[catch {filterwheel::open $filterwheelidentifier} message]} {
      log::warning "unable to open filter wheel: $message"
      coroutine::after 5000
    }
    filterwheel::waitwhilemoving
    variable filters
    if {[llength $filters] == 0} {
      log::info "no filters installed."
    } else {
      foreach filter [dict keys $filters] {
        log::info "filter $filter is at position [dict get $filters $filter]."
      }
    }
    variable focuseridentifier
    while {[catch {focuser::open $focuseridentifier} message]} {
      log::warning "unable to open focuser: $message"
      coroutine::after 5000
    }
    focuser::waitwhilemoving
    log::info [format "finished starting after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc initializeactivitycommand {} {
    set start [utcclock::seconds]
    log::info "initializing."
    coroutine::yield
    stopexposing
    stopsolving
    variable detectorfullunbinneddatawindow
    detector::setfullunbinneddatawindow $detectorfullunbinneddatawindow
    variable detectorfullunbinnedbiaswindow
    detector::setfullunbinnedbiaswindow $detectorfullunbinnedbiaswindow
    variable detectorreadmodes
    set readmode "initial"
    while {[dict exists $detectorreadmodes $readmode]} {
      set readmode [dict get $detectorreadmodes $readmode]
    }
    detector::setreadmode $readmode
    variable detectorinitialsoftwaregain
    detector::setsoftwaregain $detectorinitialsoftwaregain
    variable detectorwindows
    set window "initial"
    while {[dict exists $detectorwindows $window]} {
      set window [dict get $detectorwindows $window]
    }
    detector::setunbinnedwindow $window
    variable detectorinitialbinning
    detector::setbinning $detectorinitialbinning
    setcoolerhelper "closed"
    variable focuserinitialposition
    movefocuseractivitycommand $focuserinitialposition
    checkfocuserpositionerror "after initializing"
    movefilterwheelactivitycommand "initial" true
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    coroutine::yield
    stopexposing
    stopsolving
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
    coroutine::yield
    stopexposing
    stopsolving
    detector::reset
    log::info [format "finished resetting after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc formatirafsection {window} {
    set sx [dict get $window sx]
    set sy [dict get $window sy]
    set nx [dict get $window nx]
    set ny [dict get $window ny]
    return [format "\[%d:%d,%d:%d\]" [expr {$sx + 1}] [expr {$sx + $nx}] [expr {$sy + 1}] [expr {$sy + $ny}]]
  }
  
  proc writefitsheaderprolog {channel seconds fitsfilename exposuretime exposuretype} {
    fitsheader::writekeyandvalue $channel "DATE-OBS" date    $seconds
    fitsheader::writekeyandvalue $channel "MJD-OBS"  double  [format "%.8f" [utcclock::mjd $seconds]]
    fitsheader::writekeyandvalue $channel "ORIGIN"   string  "OAN/SPM"
    fitsheader::writekeyandvalue $channel "TELESCOP" string  [server::getdata "telescopedescription"]
    fitsheader::writekeyandvalue $channel "INSTRUME" string  [server::getdata "identifier"]
    fitsheader::writekeyandvalue $channel "ORIGNAME" string  [file tail $fitsfilename]
    fitsheader::writekeyandvalue $channel "EXPTIME"  double  [expr {double($exposuretime)}]
    fitsheader::writekeyandvalue $channel "NFRM"     integer [detector::getnframe]
    if {![string equal "" [server::getdata "detectorframetime"]]} {
      fitsheader::writekeyandvalue $channel "FRMTIME"  double [server::getdata "detectorframetime"]
    }
    if {![string equal "" [server::getdata "detectorcycletime"]]} {
      fitsheader::writekeyandvalue $channel "CYCTIME"  double [server::getdata "detectorcycletime"]
    }
    fitsheader::writekeyandvalue $channel "EXPTYPE"  string $exposuretype
    fitsheader::writekeyandvalue $channel "CCD_NAME" string [server::getdata "identifier"]
    fitsheader::writekeyandvalue $channel "BINNING"  string [server::getdata "detectorbinning"]
    fitsheader::writekeyandvalue $channel "READMODE" string [server::getdata "detectorreadmode"]
    fitsheader::writekeyandvalue $channel "SOFTGAIN" double [server::getdata "detectorsoftwaregain"]
    fitsheader::writekeyandvalue $channel "DATASAT"  double [server::getdata "detectorsaturationlevel"]
    fitsheader::writekeyandvalue $channel "CCDSEC"   string [formatirafsection [server::getdata "detectordatawindow"]]
    fitsheader::writekeyandvalue $channel "DATASEC"  string [formatirafsection [server::getdata "detectordatawindow"]]
    if {![string equal "" [server::getdata "detectorbiaswindow"]]} {
      fitsheader::writekeyandvalue $channel "BIASSEC"  string [formatirafsection [server::getdata "detectorbiaswindow"]]
    }
    fitsheader::writekeyandvalue $channel "FILTER"   string [server::getdata "filter"]
    fitsheader::writekeyandvalue $channel "FWPS"     string [server::getdata "filterwheelposition"]
    fitsheader::writekeyandvalue $channel "DTDS"     string  [server::getdata "detectordescription"]
    fitsheader::writekeyandvalue $channel "FCDS"     string  [server::getdata "focuserdescription"]
    fitsheader::writekeyandvalue $channel "NFW "     integer  [server::getdata "filterwheels"]
    set i 0
    while {$i < [server::getdata "filterwheels"]} {
      set iplus1 [expr {$i + 1}]
      fitsheader::writekeyandvalue $channel "FWDS$iplus1" string [server::getdata "filterwheeldescription$i"]
      incr i
    }    
    fitsheader::writekeysandvaluesforproject $channel
    fitsheader::writeccdfitsheader $channel [server::getdata "identifier"] "S"
    fitsheader::writetcsfitsheader $channel "S"
  }
  
  proc writefitsheaderepilog {channel} {
    fitsheader::writeccdfitsheader $channel [server::getdata "identifier"] "E"
    fitsheader::writetcsfitsheader $channel "E"  
  }
  
  proc withcube {} {
    set amplifier [detector::getamplifier]
    if {[string equal $amplifier "conventional"]} {
      return false
    } else {
      return true
    }
  }
  
  proc exposeactivitycommand {exposuretime exposuretype fitsfileprefix starttime} {

    set start [utcclock::seconds]
    coroutine::after 1

    variable identifier
    
    if {![string equal $starttime "now"]} {
      set start [utcclock::seconds]
      log::info "waiting until [utcclock::format $starttime]."
      set startseconds [utcclock::scan $starttime]
      while {[utcclock::seconds] <= $startseconds} {
        coroutine::after 100
      }
      log::info [format "continuing %.1f seconds after requested start time." [utcclock::diff now $startseconds]]
    }

    log::info "exposing $exposuretype image for $exposuretime seconds."

    stopexposing
    stopsolving

    set finalfitsfilename [getfitsfilename $exposuretype $fitsfileprefix]
    log::info [format "FITS file is %s." $finalfitsfilename]
    set tmpfitsfilename "$finalfitsfilename.tmp"
    if {[withcube]} {
      set finalfitscubefilename    [getfitscubefilename $exposuretype $fitsfileprefix]
      log::info [format "FITS cube file is %s." $finalfitscubefilename]
      set finalfitscubehdrfilename "$finalfitscubefilename.hdr"
      set finalfitscubepixfilename "$finalfitscubefilename.pix"
      set tmpfitscubehdrfilename   "$finalfitscubehdrfilename.tmp"
      set tmpfitscubepixfilename   "$finalfitscubepixfilename.tmp"
    } else {
      set finalfitscubefilename    ""
      set finalfitscubehdrfilename ""
      set finalfitscubepixfilename ""
      set tmpfitscubehdrfilename   ""
      set tmpfitscubepixfilename   ""
    }
    if {[catch {file mkdir [file dirname $finalfitsfilename]}]} {
      error "unable to create the directory \"[file dirname $finalfitsfilename]\"."
    }

    # The difference between the latest file and the current file is
    # that, once created, the latest file always exists and is replaced
    # atomically at the end of an exposure. The current file, on the
    # other hand, is removed at the start of an exposure and replaced at
    # the end of an exposure.
    set latestfilename [file join [directories::var] $identifier "latest.fits"]
    set currentfilename [file join [directories::var] $identifier "current.fits"]
    file delete -force -- $currentfilename

    server::setdata "exposuretime"        $exposuretime
    server::setdata "fitsfilename"        $finalfitsfilename
    server::setdata "solvedalpha"         ""
    server::setdata "solveddelta"         ""
    server::setdata "solvedequinox"       ""
    server::setdata "solvedobservedalpha" ""
    server::setdata "solvedobserveddelta" ""
    server::setdata "mountobservedalpha"  ""
    server::setdata "mountobserveddelta"  ""
    server::setdata "fwhm"                ""
    server::setdata "fwhmpixels"          ""
    server::setdata "average"             ""
    server::setdata "standarddeviation"   ""

    if {[string equal $exposuretype "object"          ] || 
        [string equal $exposuretype "flat"            ] || 
        [string equal $exposuretype "astrometry"      ] ||
        [string equal $exposuretype "focus"           ]
    } {
      set shutter open
    } elseif {[string equal $exposuretype "bias"] ||
              [string equal $exposuretype "dark"]} {
      set shutter closed
    }
    log::info [format "starting exposing after %.1f seconds." [utcclock::diff now $start]]
    detector::startexposure $exposuretime $shutter $tmpfitscubepixfilename
    set seconds [utcclock::seconds]
    log::info [format "started exposing after %.1f seconds." [utcclock::diff now $start]]
    log::info [format "started writing FITS header (start) after %.1f seconds." [utcclock::diff now $start]]

    updatedata
    if {[catch {
      set channel [detector::openfitsheader $tmpfitsfilename]
      writefitsheaderprolog $channel $seconds $finalfitsfilename $exposuretime $exposuretype
    } message]} {
      error "while writing FITS header: $message"
      catch {close $channel}
    }

    if {[withcube]} {
      if {[catch {
        set cubehdrchannel [detector::openfitscubeheader $tmpfitscubehdrfilename]
        writefitsheaderprolog $cubehdrchannel $seconds $finalfitscubefilename $exposuretime $exposuretype
      } message]} {
        error "while writing FITS header: $message"
        catch {close $channel}
        catch {close $cubehdrchannel}
      }
    }

    while {[detector::continueexposure]} {
      variable pollmilliseconds
      if {[utcclock::diff now [server::getdata "timestamp"]] * 1000 > $pollmilliseconds} {
        updatedata
      }
      coroutine::after 100
    }

    log::info [format "started writing FITS header (end) after %.1f seconds." [utcclock::diff now $start]]
    updatedata
    if {[catch {
      fitsheader::writeccdfitsheader $channel [server::getdata "identifier"] "E"
      fitsheader::writetcsfitsheader $channel "E"
      detector::closefitsheader $channel
    } message]} {
      error "while writing FITS header: $message"
      catch {close $channel}
      catch {close $cubehdrchannel}
    }
    if {[withcube]} {
      if {[catch {
        fitsheader::writeccdfitsheader $cubehdrchannel [server::getdata "identifier"] "E"
        fitsheader::writetcsfitsheader $cubehdrchannel "E"
        detector::closefitsheader $cubehdrchannel
      } message]} {
        error "while writing FITS header: $message"
        catch {close $cubehdrchannel}
      }
    }

    log::info [format "started reading after %.1f seconds." [utcclock::diff now $start]]
    server::setactivity "reading"
    if {[catch {detector::readexposure} message]} {
      error "while reading exposure: $message"
    }    

    log::info [format "started writing after %.1f seconds." [utcclock::diff now $start]]
    server::setactivity "writing"
    if {[catch {detector::writeexposure $tmpfitsfilename $finalfitsfilename $latestfilename $currentfilename $tmpfitscubehdrfilename $finalfitscubehdrfilename $tmpfitscubepixfilename $finalfitscubepixfilename false} message]} {
      error "while writing FITS data: $message"
    }
    
    if {[withcube]} {
      if {[catch {updatedata} message]} {
        error "unable to update date: $message"
      }
      set saasigmax [server::getdata "detectorsaasigmax"]
      set saasigmay [server::getdata "detectorsaasigmay"]
      log::info [format "SAA sigma are %.2fas in x and %.2fas in y." [astrometry::radtoarcsec $saasigmax] [astrometry::radtoarcsec $saasigmay]]
    }
    log::info [format "finished exposing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc getfitsfwhmargs {} {
    variable fitsfwhmargs
    set binning [server::getdata "detectorbinning"]
    if {[dict exists $fitsfwhmargs $binning]} {
      return [dict get $fitsfwhmargs $binning]
    } else {
      return ""
    }
  }

  proc analyzeactivitycommand {type} {
    variable identifier
    set start [utcclock::seconds]
    log::info "analyzing current exposure."
    coroutine::yield
    set fitsfilename [server::getdata "fitsfilename"]
    set currentfilename [file join [directories::var] $identifier "current.fits"]
    if {![file exists $currentfilename]} {
      log::info "waiting for FITS file."
      variable pollmilliseconds
      while {![file exists $currentfilename]} {
        coroutine::after $pollmilliseconds
      }
      log::info [format "finished waiting for FITS file after %.1f seconds." [utcclock::diff now $start]]
    }
    if {[string equal $type "levels"]} {
      server::setdata "average"           [detector::getaverage]
      server::setdata "standarddeviation" [detector::getstandarddeviation]
      log::info [format "level is %.1f ± %.1f DN." [detector::getaverage] [detector::getstandarddeviation]]
    } elseif {[string equal $type "fwhm"]} {
      variable fitsfwhmchannel
      variable fitsfwhmargs
      set binning [server::getdata "detectorbinning"]
      if {[dict exists $fitsfwhmargs $binning]} {
        set fitsfwhmarg [dict get $fitsfwhmargs $binning]
      } else {
        set fitsfwhmarg ""
      }
      log::debug "command is [directories::bin]/tcs newpgrp [directories::bin]/tcs fitsfwhm $fitsfwhmarg -- \"$currentfilename\""
      set fitsfwhmchannel [open "|[directories::bin]/tcs newpgrp [directories::bin]/tcs fitsfwhm $fitsfwhmarg -- \"$currentfilename\"" "r"]
      chan configure $fitsfwhmchannel -buffering "line"
      chan configure $fitsfwhmchannel -encoding "ascii"
      set line [coroutine::gets $fitsfwhmchannel 0 100]
      catch {close $fitsfwhmchannel}
      set fitsfwhmchannel {}
      if {
        [string equal $line ""] ||
        [scan $line "%f %f %f" fwhmpixels x y] != 3
      } {
        log::debug "fitsfwhm failed: \"$line\"."
        log::info "unable to determine FWHM."
      } else {
        set binning      [server::getdata "detectorbinning"]
        set filter       [server::getdata "filter"]
        set exposuretime [server::getdata "exposuretime"]
        variable detectorunbinnedpixelscale
        set fwhm [expr {$fwhmpixels * $binning * $detectorunbinnedpixelscale}]
        set fwhmpixels [format "%.2f" $fwhmpixels]
        set x [format "%.2f" $x]
        set y [format "%.2f" $y]
        server::setdata "fwhm" $fwhm
        server::setdata "fwhmpixels" $fwhmpixels
        log::info [format \
          "FWHM is %.2fas (%.2f pixels with binning $binning) in filter %s in %s seconds." \
          [astrometry::radtoarcsec $fwhm] $fwhmpixels $filter $exposuretime \
        ]
      }
    } elseif {[string equal $type "astrometry"]} {
      variable solvingchannel
      set solvingchannel [open "|[directories::bin]/tcs newpgrp [directories::bin]/tcs fitssolvewcs -c -f -- \"$currentfilename\"" "r"]
      chan configure $solvingchannel -buffering "line"
      chan configure $solvingchannel -encoding "ascii"
      set line [coroutine::gets $solvingchannel 0 100]
      catch {close $solvingchannel}
      set solvingchannel {}
      if {
        [string equal $line ""] ||
        [scan $line "%f %f %f" solvedalpha solveddelta solvedequinox] != 3 ||
        $solvedequinox != 2000.0
      } {
        log::debug "astrometry solving failed: \"$line\"."
        log::info "unable to determine astrometry."
      } else {
        log::debug "astrometry solving succeeded: \"$line\"."
        set solvedalpha [astrometry::degtorad $solvedalpha]
        set solveddelta [astrometry::degtorad $solveddelta]
        log::info "solved $identifier position is [astrometry::formatalpha $solvedalpha] [astrometry::formatdelta $solveddelta] $solvedequinox."
        set solvedobservedalpha [astrometry::observedalpha $solvedalpha $solveddelta $solvedequinox]
        set solvedobserveddelta [astrometry::observeddelta $solvedalpha $solveddelta $solvedequinox]
        log::info "solved $identifier observed position is [astrometry::formatalpha $solvedobservedalpha] [astrometry::formatdelta $solvedobserveddelta]."
        set mountdalpha [mountdalpha $solvedobservedalpha $solvedobserveddelta]
        set mountddelta [mountddelta $solvedobservedalpha $solvedobserveddelta]
        set solvedmountobservedalpha [astrometry::foldradpositive [expr {$solvedobservedalpha + $mountdalpha}]]
        set solvedmountobserveddelta [expr {$solvedobserveddelta + $mountddelta}]
        log::info "solved $identifier mount observed position is [astrometry::formatalpha $solvedmountobservedalpha] [astrometry::formatdelta $solvedmountobserveddelta]."
        server::setdata "solvedalpha"         $solvedalpha
        server::setdata "solveddelta"         $solveddelta
        server::setdata "solvedequinox"       $solvedequinox
        server::setdata "solvedobservedalpha" $solvedobservedalpha
        server::setdata "solvedobserveddelta" $solvedobserveddelta
        server::setdata "mountobservedalpha"  $solvedmountobservedalpha
        server::setdata "mountobserveddelta"  $solvedmountobserveddelta
      }
    }
  }
  
  proc movefilterwheelactivitycommand {newfilter forcemove} {
    set start [utcclock::seconds]
    variable filters
    set newposition $newfilter
    while {[dict exists $filters $newposition]} {
      set newposition [dict get $filters $newposition]
    }
    log::info "moving filter wheel to filter [getfilter $newposition] (position $newposition)."
    if {$forcemove || ![string equal [server::getdata "filterwheelposition"] $newposition]} {
      server::setdata "requestedfilterwheelposition" $newposition
      filterwheel::move $newposition
      filterwheel::waitwhilemoving
    }
    log::info [format "finished moving filter wheel after %.1f seconds." [utcclock::diff now $start]]
    movefocuseractivitycommand [server::getdata "requestedfocuserposition"]
  }
  
  proc setfocuserdz {} {

    if {[catch {client::update "target"}]} {

      log::warning "unable to determine focuser correction."
      set dzfilter 0

    } else {

      variable focuserdzmodel
      log::debug "focuser correction model is $focuserdzmodel."

      set filter [server::getdata "filter"]
      if {[dict exists $focuserdzmodel "filter" $filter]} {
        set dzfilter [dict get $focuserdzmodel "filter" $filter]
      } else {
        set dzfilter 0
      }
      
      set X [client::getdata "target" "observedairmass"]
      log::debug [format "determining focuser correction for X = %.2f." $X]
      set dzposition 0
      if {[dict exists $focuserdzmodel "position" "C"]} {
        set dzposition [expr {$dzposition + [dict get $focuserdzmodel "position" "C"]}]
      }
      if {[dict exists $focuserdzmodel "position" "XM"]} {
        set dzposition [expr {$dzposition + [dict get $focuserdzmodel "position" "XM"] * ($X - 1)}]
      }
      if {[dict exists $focuserdzmodel "position" "XM2"]} {
        set dzposition [expr {$dzposition + [dict get $focuserdzmodel "position" "XM2"] * ($X - 1) * ($X - 1)}]
      }            
      set dzposition [expr {int($dzposition)}]

    }
    
    set dz [expr {$dzfilter + $dzposition}]
    log::debug "focuser correction is $dz."
    server::setdata "focuserdzfilter"   $dzfilter
    server::setdata "focuserdzposition" $dzposition
    server::setdata "focuserdz"         $dz

    set requestedposition [server::getdata "requestedfocuserposition"]
    set requestedrawposition [expr {$requestedposition + $dz}]
    server::setdata "requestedfocuserrawposition" $requestedrawposition
    log::debug "focuser raw position is $requestedrawposition."
  }
  
  proc movefocuseractivitycommand {newposition} {
    set start [utcclock::seconds]
    log::info "moving focuser to position $newposition."
    coroutine::yield
    server::setdata "requestedfocuserposition" $newposition
    setfocuserdz
    set newrawposition [server::getdata "requestedfocuserrawposition"]
    set rawposition [focuser::getposition]
    if {[server::getdata "focusermaxposition"] != 0 && $rawposition != $newrawposition} {
      variable focuserbacklashoffset
      if {
        ($newrawposition > $rawposition && $focuserbacklashoffset > 0) ||
        ($newrawposition < $rawposition && $focuserbacklashoffset < 0)
      } {
        set minposition [focuser::getminposition]
        set maxposition [focuser::getmaxposition]
        set firstrawposition [expr {min($maxposition,max($minposition,$newrawposition + $focuserbacklashoffset))}]
        log::info "moving focuser to raw position $firstrawposition to mitigate backlash."
        focuser::move $firstrawposition
        focuser::waitwhilemoving
      }
      log::info "moving focuser to raw position $newrawposition."
      focuser::move $newrawposition
      focuser::waitwhilemoving
      checkfocuserpositionerror "after moving focuser"
    }
    log::info [format "finished moving focuser after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc setfocuseractivitycommand {newposition} {
    set start [utcclock::seconds]
    log::info "setting focuser to position $newposition."
    coroutine::yield
    server::setdata "requestedfocuserposition" $newposition
    setfocuserdz
    set newrawposition [server::getdata "requestedfocuserrawposition"]
    set rawposition [server::getdata "focuserrawposition"]
    focuser::setposition $newrawposition
    focuser::waitwhilemoving
    log::info [format "focuser position shift is %+d." [expr {$newrawposition - $rawposition}]]
    checkfocuserpositionerror "after setting focuser"
    log::info [format "finished setting focuser after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc exposeforfocus {exposuretime fitsfileprefix} {
    exposeactivitycommand $exposuretime "focus" $fitsfileprefix/[utcclock::combinedformat now 0 false] "now"
  }
  
  proc mapfocusactivitycommand {exposuretime fitsfileprefix range step} {
    set start [utcclock::seconds]
    log::info "mapping focus."
    coroutine::yield
    set originalposition [server::getdata "focuserposition"]
    set midposition $originalposition
    set minposition [expr {max($midposition - int($range / 2), [server::getdata "focuserminposition"])}]
    set maxposition [expr {min($midposition + int($range / 2), [server::getdata "focusermaxposition"])}]
    for {set position $minposition} {$position <= $maxposition} {incr position $step} {
      movefocuseractivitycommand $position
      exposeforfocus $exposuretime $fitsfileprefix
    }
    movefocuseractivitycommand $originalposition
    log::info [format "finished focus map after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" ccd::initializeactivitycommand 600000
    return
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] ccd::stopactivitycommand
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] ccd::resetactivitycommand 600000
  }

  proc expose {exposuretime {exposuretype "object"} {fitsfileprefix ""} {starttime "now"}} {
    log::info "received request to expose."
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is double -strict $exposuretime] ||
      $exposuretime < 0
    } {
      error "invalid exposure time \"$exposuretime\"."
    }
    if {
      ![string equal $exposuretype "object"          ] &&
      ![string equal $exposuretype "bias"            ] &&
      ![string equal $exposuretype "dark"            ] &&
      ![string equal $exposuretype "flat"            ] &&
      ![string equal $exposuretype "astrometry"      ] &&
      ![string equal $exposuretype "focus"           ]
    } {
      error "invalid exposure type \"$exposuretype\"."
    }
    if {[string equal $fitsfileprefix ""]} {
      variable identifier
      set seconds [utcclock::seconds]
      set fitsfileprefix [file join \
        [directories::vartoday $seconds] \
        $identifier \
        "[utcclock::combinedformat $seconds 0 false]" \
      ]
    }
    set timeoutmilliseconds [expr {1000 * ($exposuretime + 120)}]
    server::newactivitycommand "exposing" "idle" \
      "ccd::exposeactivitycommand $exposuretime $exposuretype $fitsfileprefix $starttime" \
      $timeoutmilliseconds
    return
  }

  proc analyze {type} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string equal $type "levels"         ] &&
      ![string equal $type "fwhm"           ] &&
      ![string equal $type "astrometry"     ]
    } {
      error "invalid analysis type \"$type\"."
    }
#    if {[string equal [server::getdata "fitsfilename"] ""]} {
#      error "no previous exposure to analyze."
#    }
    server::newactivitycommand "analyzing" "idle" \
      "ccd::analyzeactivitycommand $type"
    return
  }
  
  proc movefilterwheel {filter} {
    server::checkstatus
    server::checkactivity "idle"
    variable filters
    if {![dict exists $filters $filter] && ![regexp -- {^[0-9]+(:[0-9]+)*$} $filter]} {
      error "invalid filter \"$filter\"."
    }
    server::newactivitycommand "moving" "idle" "ccd::movefilterwheelactivitycommand $filter false"
    return
  }
  
  proc movefocuser {position setasinitial} {
    variable focuserinitialposition
    server::checkstatus
    server::checkactivity "idle"
    set minposition [server::getdata "focuserminposition"]
    set maxposition [server::getdata "focusermaxposition"]
    if {[string equal $position "current"]} {
      log::info "moving focuser to the current position."
      set position [server::getdata "requestedfocuserposition"]
    } elseif {[string equal $position "initial"]} {
      log::info "moving focuser to the initial position."
      set position $focuserinitialposition
    } elseif {[string equal $position "center"]} {
      log::info "moving focuser to the center position."
      set position [expr {int(($minposition + $maxposition) / 2)}]
    } elseif {[string equal $position "minimum"]} {
      log::info "moving focuser to the minimum position."
      set position $minposition
    } elseif {[string equal $position "maximum"]} {
      log::info "moving focuser to the maximum position."
      set position $maxposition
    } elseif {
      ![string is integer -strict $position] ||
      $position < $minposition ||
      $position > $maxposition
    } {
      error "invalid focuser position \"$position\"."
    }
    variable identifier
    if {$setasinitial} {
      set focuserinitialposition $position
      config::setvarvalue $identifier "focuserinitialposition" $position
    }
    server::newactivitycommand "moving" "idle" "ccd::movefocuseractivitycommand $position"
    return
  }

  proc setfocuser {position setasinitial} {
    variable focuserinitialposition
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is integer -strict $position] ||
      $position < 0 ||
      $position > [server::getdata "focusermaxposition"]
    } {
      error "invalid focuser position \"$position\"."
    }
    variable identifier
    if {$setasinitial} {
      set focuserinitialposition $position
      config::setvarvalue $identifier "focuserinitialposition" $position
    }
    server::newactivitycommand "setting" "idle" "ccd::setfocuseractivitycommand $position"
    return
  }

  proc setcoolerhelper {setting} {
    log::info "setting cooler to $setting."
    if {
      ![string equal $setting "last"] && 
      ![string equal $setting "on"] && 
      ![string equal $setting "off"] &&
      ![string equal $setting "following"] &&
      ![string equal $setting "start"] &&
      ![string equal $setting "open"] &&
      ![string equal $setting "closed"] &&
      ![string is double -strict $setting]} {
      error "invalid cooler setting \"$setting\"."
    }
    if {[string equal $setting "start"]} {
      variable coolerstartsetting
      set setting $coolerstartsetting
      log::info "requested to set cooler to start setting which is \"$setting\"."
    }
    if {[string equal $setting "open"]} {
      variable cooleropensetting
      set setting $cooleropensetting
      log::info "requested to set cooler to open setting which is \"$setting\"."
    }    
    if {[string equal $setting "closed"]} {
      variable coolerclosedsetting
      set setting $coolerclosedsetting
      log::info "requested to set cooler to closed setting which is \"$setting\"."
    }
    variable identifier
    if {[string equal $setting "last"]} {
      set setting [config::getvalue $identifier "lastcoolersetting"]
      log::info "requested to set cooler to last setting which is \"$setting\"."
    }
    detector::setcooler $setting
    config::setvarvalue $identifier "lastcoolersetting" $setting
    updatedata
  }

  proc setcooler {setting} {
    set start [utcclock::seconds]
    server::checkstatus
    server::checkactivity "idle"
    setcoolerhelper $setting
    log::info [format "finished setting cooler after %.1f seconds." [utcclock::diff now $start]]
    return
  }

  proc setsoftwaregain {softwaregain} {
    set start [utcclock::seconds]
    log::info "setting software gain to $softwaregain."
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is integer -strict $softwaregain] ||
      $softwaregain < 1
    } {
      error "invalid detector software gain \"$softwaregain\"."
    }
    detector::setsoftwaregain $softwaregain
    updatedata
    log::info [format "finished setting software gain after %.1f seconds." [utcclock::diff now $start]]
    return
  }

  proc setwindow {window} {
    set start [utcclock::seconds]
    log::info "setting window to $window."
    server::checkstatus
    server::checkactivity "idle"
    variable detectorwindows
    while {[dict exists $detectorwindows $window]} {
      set window [dict get $detectorwindows $window]
    }
    if {![string equal $window "full"]} {
      if {
        ![dict exists $window sx] ||
        ![dict exists $window sy] ||
        ![dict exists $window nx] ||
        ![dict exists $window ny]
      } {
        error "invalid detector window \"$window\"."
      }
      set sx [dict get $window sx]
      set sy [dict get $window sy]
      set nx [dict get $window nx]
      set ny [dict get $window ny]
      if {
        ![string is integer -strict $sx] ||
        $sx < 0
      } {
        error "invalid detector sx \"$sx\"."
      }
      if {
        ![string is integer -strict $sy] ||
        $sy < 0
      } {
        error "invalid detector sy \"$sy\"."
      }
      if {
        ![string is integer -strict $nx] ||
        $nx < 1
      } {
        error "invalid detector nx \"$nx\"."
      }
      if {
        ![string is integer -strict $ny] ||
        $ny < 1
      } {
        error "invalid detector ny \"$ny\"."
      }
    }
    detector::setunbinnedwindow $window
    variable detectorinitialbinning
    detector::setbinning $detectorinitialbinning
    updatedata
    log::info [format "finished setting window after %.1f seconds." [utcclock::diff now $start]]
    return
  }
  
  proc getwidth {} {
    variable detectorunbinnedpixelscale
    set window [detector::getunbinnedwindow]
    return [expr {$detectorunbinnedpixelscale * [dict get $window nx]}]
  }
  
  proc setbinning {binning} {
    set start [utcclock::seconds]
    log::info "setting binning to $binning."
    server::checkstatus
    server::checkactivity "idle"
    if {[string equal $binning "initial"]} {
      variable detectorinitialbinning
      set binning $detectorinitialbinning
    }
    if {
      ![string is integer -strict $binning] ||
      $binning < 1
    } {
      error "invalid detector binning \"$binning\"."
    }
    detector::setbinning $binning
    updatedata
    log::info [format "finished setting binning after %.1f seconds." [utcclock::diff now $start]]
    return
  }
  
  proc setreadmode {readmode} {
    set start [utcclock::seconds]
    log::info "setting read mode to $readmode."
    server::checkstatus
    server::checkactivity "idle"
    variable detectorreadmodes
    while {[dict exists $detectorreadmodes $readmode]} {
      set readmode [dict get $detectorreadmodes $readmode]
    }
    detector::setreadmode $readmode
    variable detectorwindows
    set window "initial"
    while {[dict exists $detectorwindows $window]} {
      set window [dict get $detectorwindows $window]
    }
    detector::setunbinnedwindow $window
    variable detectorinitialbinning
    detector::setbinning $detectorinitialbinning
    updatedata
    log::info [format "finished setting read mode after %.1f seconds." [utcclock::diff now $start]]
    return
  }
  
  proc mapfocus {exposuretime fitsfileprefix range step} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is double -strict $exposuretime] ||
      $exposuretime < 0
    } {
      error "invalid exposure time."
    }
    if {![string is integer -strict $range]} {
      error "invalid range."
    }
    if {![string is integer -strict $step]} {
      error "invalid step."
    }
    server::newactivitycommand "mappingfocus" "idle" \
      "ccd::mapfocusactivitycommand $exposuretime $fitsfileprefix $range $step" false
  }
  
  proc correct {truemountalpha truemountdelta equinox} {
    set start [utcclock::seconds]
    server::checkstatus
    server::checkactivity "idle"
    set truemountalpha [astrometry::parseangle $truemountalpha "hms"]
    set truemountdelta [astrometry::parseangle $truemountdelta "dms"]
    log::info "correcting at [astrometry::radtohms $truemountalpha 2 false] [astrometry::radtodms $truemountdelta 1 true] $equinox"
    if {[string equal $equinox "observed"]} {
      set truemountobservedalpha $truemountalpha
      set truemountobserveddelta $truemountdelta
    } else {
      set truemountobservedalpha [astrometry::observedalpha $truemountalpha $truemountdelta $equinox]
      set truemountobserveddelta [astrometry::observeddelta $truemountalpha $truemountdelta $equinox]    
    }
    set observedmountalpha [server::getdata "mountobservedalpha"]
    set observedmountdelta [server::getdata "mountobserveddelta"]
    if {[string equal $observedmountalpha ""] || [string equal $observedmountdelta ""]} {
      error "the latest image has not been solved."
    }
    set dalpha [astrometry::foldradsymmetric [expr {$truemountobservedalpha - $observedmountalpha}]]
    set ddelta [astrometry::foldradsymmetric [expr {$truemountobserveddelta - $observedmountdelta}]]
    set eastoffset [expr {$dalpha * cos($truemountobserveddelta)}]
    set northoffset $ddelta
    log::info [format "correction is %s E and %s N." [astrometry::formatoffset $eastoffset] [astrometry::formatoffset $northoffset]]
    server::setdata "lastcorrectiontimestamp" [utcclock::format]
    server::setdata "lastcorrectioneastoffset"  $eastoffset
    server::setdata "lastcorrectionnorthoffset" $northoffset
    set dCH [expr {-($eastoffset)}]
    set dID $northoffset
    updatepointingmodel $dCH $dID
    log::info [format "finished correcting after %.1f seconds." [utcclock::diff now $start]]
    return
  }

  ######################################################################
  
  proc start {} {
    server::newactivitycommand "starting" "started" ccd::startactivitycommand
    after idle {
      coroutine ::ccd::updatedataloopcoroutine ccd::updatedataloop      
    }
  }

}
