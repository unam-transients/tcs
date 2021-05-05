########################################################################

# This file is part of the UNAM telescope control system.

# $Id: ccd.tcl 3611 2020-06-11 21:19:38Z Alan $

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

  variable svnid {$Id}

  ######################################################################

  variable identifier [config::getvalue "ccd" "identifier"]

  variable telescopedescription            [config::getvalue $identifier "telescopedescription"           ]
  variable detectortype                    [config::getvalue $identifier "detectortype"                   ]
  variable detectoridentifier              [config::getvalue $identifier "detectoridentifier"             ]
  variable detectorinitialreadmode         [config::getvalue $identifier "detectorinitialreadmode"        ]
  variable detectorinitialsoftwaregain     [config::getvalue $identifier "detectorinitialsoftwaregain"    ]
  variable detectorinitialbinning          [config::getvalue $identifier "detectorinitialbinning"         ]
  variable detectorfullunbinneddatawindow  [config::getvalue $identifier "detectorfullunbinneddatawindow" ]
  variable detectorfullunbinnedbiaswindow  [config::getvalue $identifier "detectorfullunbinnedbiaswindow" ]
  variable detectorwindows                 [config::getvalue $identifier "detectorwindows"                ]
  variable cooleropensetting               [config::getvalue $identifier "cooleropensetting"              ]
  variable coolerclosedsetting             [config::getvalue $identifier "coolerclosedsetting"            ]
  variable filterwheeltype                 [config::getvalue $identifier "filterwheeltype"                ]
  variable filterwheelidentifier           [config::getvalue $identifier "filterwheelidentifier"          ]
  variable filterwheelinitialposition      [config::getvalue $identifier "filterwheelinitialposition"     ]
  variable filterwheelidleposition         [config::getvalue $identifier "filterwheelidleposition"        ]
  variable allowedfilterwheelpositionerror [config::getvalue $identifier "allowedfilterwheelpositionerror"]
  variable filterlist                      [config::getvalue $identifier "filterlist"                     ]
  variable focusertype                     [config::getvalue $identifier "focusertype"                    ]
  variable focuseridentifier               [config::getvalue $identifier "focuseridentifier"              ]
  variable focuserinitialposition          [config::getvalue $identifier "focuserinitialposition"         ]
  variable focuserbacklashoffset           [config::getvalue $identifier "focuserbacklashoffset"          ]
  variable focusercorrectionmodel          [config::getvalue $identifier "focusercorrectionmodel" ]
  variable allowedfocuserpositionerror     [config::getvalue $identifier "allowedfocuserpositionerror"    ]
  variable isstandalone                    [config::getvalue $identifier "isstandalone"                   ]
  variable detectorpixelscale              [astrometry::parseangle [config::getvalue $identifier "detectorpixelscale"]]
  variable pointingmodelparameters         [config::getvalue $identifier "pointingmodelparameters"        ]
  variable temperaturelimit                [config::getvalue $identifier "temperaturelimit"               ]
  variable temperaturelimitoutletgroup     [config::getvalue $identifier "temperaturelimitoutletgroup"    ]
  variable fitsfwhmargs                    [config::getvalue $identifier "fitsfwhmargs"                   ]

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
  server::setdata "focusercorrection"                 0
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
  server::setdata "average"                           ""
  server::setdata "standarddeviation"                 ""
  
  proc updatedata {} {
  
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
    if {[catch {
      expr {$filterwheelposition - $requestedfilterwheelposition}
    } filterwheelpositionerror]} {
      set filterwheelpositionerror ""
    }
    
    set lastfocuserrawposition [server::getdata "focuserrawposition"]
    set focuserrawposition     [focuser::getposition]
    set lastfocuserposition    [server::getdata "focuserposition"]
    set focusercorrection      [server::getdata "focusercorrection"]
    set focuserposition        [expr {$focuserrawposition - $focusercorrection}]

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
        detector::setcooler "off"
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
    server::setdata "detectorwindow"                   [detector::getwindow]
    server::setdata "detectorwidth"                    [getwidth]
    server::setdata "detectorbinning"                  [detector::getbinning]
    server::setdata "detectorfullunbinneddatawindow"   [detector::getfullunbinneddatawindow]
    server::setdata "detectorfullunbinnedbiaswindow"   [detector::getfullunbinnedbiaswindow]
    server::setdata "detectordatawindow"               [detector::getdatawindow]
    server::setdata "detectorbiaswindow"               [detector::getbiaswindow]
    server::setdata "detectorreadmode"                 [detector::getreadmode]
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
    server::setdata "filterwheeldescription"           [filterwheel::getdescription]
    server::setdata "filterwheelposition"              $filterwheelposition
    server::setdata "filterwheelpositionerror"         $filterwheelpositionerror
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
    variable filterlist
    if {[string is integer -strict $filterwheelposition] &&
        0 <= $filterwheelposition && 
        $filterwheelposition < [llength $filterlist]} {
      set filter [lindex $filterlist $filterwheelposition]
    } else {
      set filter ""
    }
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

  proc checkfilterwheelpositionerror {when} {
    updatedata
    set filterwheelpositionerror [server::getdata "filterwheelpositionerror"]
    variable allowedfilterwheelpositionerror
    if {abs($filterwheelpositionerror) > $allowedfilterwheelpositionerror} {
      log::warning [format "filter wheel position error is %+d $when." $filterwheelpositionerror]
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
      "firstalertobject" -
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
      "guidestart" -
      "guidenext" -
      "guidestartdonuts" -
      "guidenextdonuts" {
        set suffix "g"
      }
      default {
        set suffix "x"
      }
    }
    return "$fitsfileprefix$identifier$suffix.fits"
  }

  ######################################################################

  proc stopexposing {} {
    if {[catch {detector::cancelexposure} message]} {
      log::warning $message
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
    if {[catch {detector::detectorrawstart} message]} {
      error "unable to start detector: $message"
    }
    variable detectoridentifier
    while {[catch {detector::open $detectoridentifier} message]} {
      log::warning "unable to open detector: $message"
      coroutine::after 5000
    }
    variable coolerclosedsetting
    detector::setcooler $coolerclosedsetting
    variable filterwheelidentifier
    if {[catch {filterwheel::filterwheelrawstart} message]} {
      error "unable to start filter wheel: $message"
    }
    while {[catch {filterwheel::open $filterwheelidentifier} message]} {
      log::warning "unable to open filter wheel: $message"
      coroutine::after 5000
    }
    filterwheel::waitwhilemoving
    variable filterlist
    if {[llength $filterlist] == 0} {
      log::info "no filters installed."
    } else {
      set position 0
      foreach filter $filterlist {
        log::info "filter $filter is in position $position."
        incr position
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
    stopexposing
    stopsolving
    variable detectorfullunbinneddatawindow
    detector::setfullunbinneddatawindow $detectorfullunbinneddatawindow
    variable detectorfullunbinnedbiaswindow
    detector::setfullunbinnedbiaswindow $detectorfullunbinnedbiaswindow
    variable detectorinitialreadmode
    detector::setreadmode $detectorinitialreadmode
    variable detectorinitialsoftwaregain
    detector::setsoftwaregain $detectorinitialsoftwaregain
    variable detectorwindows
    set window "initial"
    while {[dict exists $detectorwindows $window]} {
      set window [dict get $detectorwindows $window]
    }
    detector::setwindow $window
    variable detectorinitialbinning
    detector::setbinning $detectorinitialbinning
    variable coolerclosedsetting
    detector::setcooler $coolerclosedsetting
    variable filterwheelinitialposition
    movefilterwheelactivitycommand $filterwheelinitialposition true
    variable focuserinitialposition
    movefocuseractivitycommand $focuserinitialposition
    checkfilterwheelpositionerror "after initializing"
    checkfocuserpositionerror "after initializing"
    log::info [format "finished initializing after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc stopactivitycommand {} {
    set start [utcclock::seconds]
    log::info "stopping."
    stopexposing
    stopsolving
    log::info [format "finished stopping after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc resetactivitycommand {} {
    set start [utcclock::seconds]
    log::info "resetting."
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
  
  proc exposeactivitycommand {exposuretime exposuretype fitsfileprefix} {
    variable identifier
    set start [utcclock::seconds]
    log::info "exposing $exposuretype image for $exposuretime seconds."
    stopexposing
    stopsolving
    set finalfilename [getfitsfilename $exposuretype $fitsfileprefix]
    if {[catch {file mkdir [file dirname $finalfilename]}]} {
      error "unable to create the directory \"[file dirname $finalfilename]\"."
    }
    log::info [format "FITS file is %s." $finalfilename]
    set tmpfilename "$finalfilename.tmp"
    # The difference between the latest file and the current file is
    # that, once created, the latest file always exists and is replaced
    # atomically at the end of an exposure. The current file, on the
    # other hand, is removed at the start of an exposure and replaced at
    # the end of an exposure.
    set latestfilename [file join [directories::var] $identifier "latest.fits"]
    set currentfilename [file join [directories::var] $identifier "current.fits"]
    file delete -force -- $currentfilename
    server::setdata "exposuretime"        $exposuretime
    server::setdata "fitsfilename"        $finalfilename
    server::setdata "solvedalpha"         ""
    server::setdata "solveddelta"         ""
    server::setdata "solvedequinox"       ""
    server::setdata "solvedobservedalpha" ""
    server::setdata "solvedobserveddelta" ""
    server::setdata "mountobservedalpha"  ""
    server::setdata "mountobserveddelta"  ""
    server::setdata "fwhm"                ""
    server::setdata "average"             ""
    server::setdata "standarddeviation"   ""
    if {[string equal $exposuretype "object"          ] || 
        [string equal $exposuretype "firstalertobject"] || 
        [string equal $exposuretype "flat"            ] || 
        [string equal $exposuretype "astrometry"      ] ||
        [string equal $exposuretype "focus"           ] ||
        [string equal $exposuretype "guidestart"      ] ||
        [string equal $exposuretype "guidenext"       ] ||
        [string equal $exposuretype "guidestartdonuts"] ||
        [string equal $exposuretype "guidenextdonuts" ]
    } {
      set shutter open
    } elseif {[string equal $exposuretype "bias"] ||
              [string equal $exposuretype "dark"]} {
      set shutter closed
    }
    set seconds [utcclock::seconds]
    log::info [format "started exposure after %.1f seconds." [utcclock::diff $seconds $start]]
    detector::startexposure $exposuretime $shutter
    log::info [format "started writing FITS header (start) after %.1f seconds." [utcclock::diff now $start]]
    if {[catch {
      set channel [detector::openfitsheader $tmpfilename]
      fitsheader::writekeyandvalue $channel "DATE-OBS" date $seconds
      fitsheader::writekeyandvalue $channel "MJD-OBS"  double [format "%.8f" [utcclock::mjd $seconds]]
      fitsheader::writekeyandvalue $channel "ORIGIN"   string "OAN/SPM"
      fitsheader::writekeyandvalue $channel "TELESCOP" string [server::getdata "telescopedescription"]
      fitsheader::writekeyandvalue $channel "INSTRUME" string [server::getdata "identifier"]
      fitsheader::writekeyandvalue $channel "ORIGNAME" string [file tail $finalfilename]
      fitsheader::writekeysandvaluesforproject $channel
      fitsheader::writekeyandvalue $channel "EXPTIME"  double [expr {double($exposuretime)}]
      fitsheader::writekeyandvalue $channel "EXPTYPE"  string $exposuretype
      fitsheader::writekeyandvalue $channel "FILTER"   string [server::getdata "filter"]
      fitsheader::writekeyandvalue $channel "CCD_NAME" string [server::getdata "identifier"]
      fitsheader::writekeyandvalue $channel "BINNING" string [server::getdata "detectorbinning"]
      fitsheader::writekeyandvalue $channel "READMODE" string [server::getdata "detectorreadmode"]
      fitsheader::writekeyandvalue $channel "SOFTGAIN" double [server::getdata "detectorsoftwaregain"]
      fitsheader::writekeyandvalue $channel "DATASAT"  double [server::getdata "detectorsaturationlevel"]
      fitsheader::writekeyandvalue $channel "CCDSEC"   string [formatirafsection [server::getdata "detectordatawindow"]]
      fitsheader::writekeyandvalue $channel "DATASEC"  string [formatirafsection [server::getdata "detectordatawindow"]]
      if {![string equal "" [server::getdata "detectorbiaswindow"]]} {
        fitsheader::writekeyandvalue $channel "BIASSEC"  string [formatirafsection [server::getdata "detectorbiaswindow"]]
      }
      fitsheader::writeccdfitsheader $channel [server::getdata "identifier"] "S"
      fitsheader::writetcsfitsheader $channel "S"
    } message]} {
      error "while writing FITS header: $message"
    }
    if {[string equal $exposuretype "firstalertobject"]} {
      if {[catch {
        client::update "executor"
        set alerteventtimestamp [client::getdata "executor" "alerteventtimestamp"]
        if {![string equal $alerteventtimestamp ""]} {
          log::info [format "trigger timestamp is %s." [utcclock::format $alerteventtimestamp]]
          set delay [utcclock::diff $seconds $alerteventtimestamp]
          log::summary [format "exposure started %.1f seconds after trigger." $delay]
        } else {
          log::summary [format "no trigger timestamp."]
        }
        set alertearliesttimestamp [client::getdata "executor" "alertearliesttimestamp"]
        if {![string equal $alertearliesttimestamp ""]} {
          log::info [format "earliest alert timestamp is %s." [utcclock::format $alertearliesttimestamp]]
          set delay [utcclock::diff $seconds $alertearliesttimestamp]
          log::summary [format "exposure started %.1f seconds after alert." $delay]
        } else {
          log::summary [format "no alert timestamp."]
        }
      } message]} {
        log::debug "unable to calculate delays: $message"
      }
    }
    while {[detector::continueexposure]} {
      coroutine::after 100
    }
    log::info [format "started writing FITS header (end) after %.1f seconds." [utcclock::diff now $start]]
    if {[catch {
      fitsheader::writeccdfitsheader $channel [server::getdata "identifier"] "E"
      fitsheader::writetcsfitsheader $channel "E"
      detector::closefitsheader $channel
    } message]} {
      error "while writing FITS header: $message"
    }
    log::info [format "started reading after %.1f seconds." [utcclock::diff now $start]]
    server::setactivity "reading"
    if {[catch {detector::readexposure} message]} {
      error "while reading exposure: $message"
    }    
    server::setactivity "writing"
    log::info [format "started writing after %.1f seconds." [utcclock::diff now $start]]
    if {[catch {detector::writeexposure $tmpfilename $finalfilename $latestfilename $currentfilename true} message]} {
      error "while writing FITS data: $message"
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
    log::info "analyzing last exposure."
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
      log::info "command is [directories::bin]/tcs newpgrp [directories::bin]/tcs fitsfwhm $fitsfwhmarg -- \"$currentfilename\""
      set fitsfwhmchannel [open "|[directories::bin]/tcs newpgrp [directories::bin]/tcs fitsfwhm $fitsfwhmarg -- \"$currentfilename\"" "r"]
      chan configure $fitsfwhmchannel -buffering "line"
      chan configure $fitsfwhmchannel -encoding "ascii"
      set line [coroutine::gets $fitsfwhmchannel 0 100]
      catch {close $fitsfwhmchannel}
      set fitsfwhmchannel {}
      if {
        [string equal $line ""] ||
        [scan $line "%f %f %f" fwhm x y] != 3
      } {
        log::debug "fitsfwhm failed: \"$line\"."
        log::info "unable to determine FWHM."
      } else {
        set fwhm [format "%.2f" $fwhm]
        set x [format "%.2f" $x]
        set y [format "%.2f" $y]
        server::setdata "fwhm" $fwhm
        set binning      [server::getdata "detectorbinning"]
        set filter       [server::getdata "filter"]
        set exposuretime [server::getdata "exposuretime"]
        log::info "FWHM is $fwhm pixels with binning $binning in filter $filter in ${exposuretime}s."
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
    } elseif {
      [string equal $type "guidestart"] ||
      [string equal $type "guidenext" ]
    } {
      variable fitsfwhmchannel
      set fitsfwhmchannel [open "|[directories::bin]/tcs newpgrp [directories::bin]/tcs fitsfwhm -- \"$currentfilename\"" "r"]
      chan configure $fitsfwhmchannel -buffering "line"
      chan configure $fitsfwhmchannel -encoding "ascii"
      set line [coroutine::gets $fitsfwhmchannel 0 100]
      catch {close $fitsfwhmchannel}
      set fitsfwhmchannel {}
      if {
        [string equal $line ""] ||
        [scan $line "%f %f %f" fwhm x y] != 3
      } {
        log::debug "fitsfwhm failed: \"$line\"."
      } elseif {[string equal $type "guidestart"]} {
        log::debug [format "guide star initial position is (%.1f,%.1f) pixels." $x $y]
        server::setdata "guidereferenceimage" $fitsfilename
        server::setdata "guidestarinitialx" $x
        server::setdata "guidestarinitialy" $y
      } elseif {[string equal $type "guidenext"]} {
        set dx [expr {$x - [server::getdata "guidestarinitialx"]}]
        set dy [expr {$y - [server::getdata "guidestarinitialy"]}]
        set easterror  [expr {$dx * [astrometry::arcsectorad +0.3]}]
        set northerror [expr {$dy * [astrometry::arcsectorad -0.3]}]
        server::setdata "guidestareasterror"  $easterror
        server::setdata "guidestarnortherror" $northerror
        log::debug [format "guide error is %+.2f E and %+.2f N arcsec." [astrometry::radtoarcsec $easterror]  [astrometry::radtoarcsec $northerror]]
      }
    } elseif {[string equal $type "guidestartdonuts"]} {
      log::debug [format "guide reference image is \"%s\"." $fitsfilename]
      server::setdata "guidereferencefitsfilename" $fitsfilename
      server::setdata "guidestarinitialx" ""
      server::setdata "guidestarinitialy" ""
    } elseif {[string equal $type "guidenextdonuts"]} {
      variable fitsdonutschannel
      set guidereferencefitsfilename [server::getdata "guidereferencefitsfilename"]
      error "donut guiding needs fixing to work with disappearing FITS files!"
      set fitsdonutschannel [open "|[directories::bin]/tcs newpgrp fitsdonuts -- \"$guidereferencefitsfilename\" \"$currentfilename\"" "r"]
      chan configure $fitsdonutschannel -buffering "line"
      chan configure $fitsdonutschannel -encoding "ascii"
      set line [coroutine::gets $fitsdonutschannel 0 100]
      catch {close $fitsdonutschannel}
      set fitsdonutschannel {}
      if {
        [string equal $line ""] ||
        [scan $line "%f %f" dx dy] != 2
      } {
        log::debug "fitsdonuts failed: \"$line\"."
      } else {
        set easterror  [expr {$dx * [astrometry::arcsectorad -0.3]}]
        set northerror [expr {$dy * [astrometry::arcsectorad +0.3]}]
        server::setdata "guidestareasterror"  $easterror
        server::setdata "guidestarnortherror" $northerror
        log::debug [format "guide error is %+.2f E and %+.2f N arcsec." [astrometry::radtoarcsec $easterror]  [astrometry::radtoarcsec $northerror]]
      }
    }
    log::info [format "finished analyzing last exposure after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc movefilterwheelactivitycommand {newposition forcemove} {
    set start [utcclock::seconds]
    variable filterlist
    set newfilter [lindex $filterlist $newposition]
    log::info "moving filter wheel to filter $newfilter (position $newposition)."
    server::setdata "requestedfilterwheelposition" $newposition
    if {[server::getdata "filterwheelmaxposition"] != 0} {
      set start [utcclock::seconds]
      log::debug "filterwheel: ccd: moving filter wheel to $newposition."
      if {$forcemove || [server::getdata "filterwheelposition"] != $newposition} {
        filterwheel::move $newposition
        filterwheel::waitwhilemoving
        checkfilterwheelpositionerror "after moving filter wheel"
      }
      set end [utcclock::seconds]
      log::debug [format "filterwheel: ccd: moving the filter wheel took %.1f seconds." [expr {$end - $start}]]
      log::debug "filterwheel: ccd: done."
    }
    log::info [format "finished moving filter wheel after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc setfocusercorrection {} {
    variable focusercorrectionmodel
    if {[catch {client::update "target"}]} {
      log::warning "unable to determine focuser correction."
      set correction 0
    } else {
      set X [client::getdata "target" "observedairmass"]
      log::debug [format "determining focuser correction for X = %.2f." $X]
      log::debug "focuser correction model is $focusercorrectionmodel."
      set correction 0
      if {[dict exists $focusercorrectionmodel "C"]} {
        set correction [expr {$correction + [dict get $focusercorrectionmodel "C"]}]
      }
      if {[dict exists $focusercorrectionmodel "XM"]} {
        set correction [expr {$correction + [dict get $focusercorrectionmodel "XM"] * ($X - 1)}]
      }
      if {[dict exists $focusercorrectionmodel "XM2"]} {
        set correction [expr {$correction + [dict get $focusercorrectionmodel "XM2"] * ($X - 1) * ($X - 1)}]
      }
      set correction [expr {int($correction)}]
    }
    server::setdata "focusercorrection" $correction
    log::debug "focuser correction is $correction."
    set requestedposition [server::getdata "requestedfocuserposition"]
    set requestedrawposition [expr {$requestedposition + $correction}]
    server::setdata "requestedfocuserrawposition" $requestedrawposition
    log::debug "focuser raw position is $requestedrawposition."
  }
  
  proc movefocuseractivitycommand {newposition} {
    set start [utcclock::seconds]
    log::info "moving focuser to position $newposition."
    server::setdata "requestedfocuserposition" $newposition
    setfocusercorrection
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
    server::setdata "requestedfocuserposition" $newposition
    setfocusercorrection
    set newrawposition [server::getdata "requestedfocuserrawposition"]
    set rawposition [server::getdata "focuserrawposition"]
    focuser::setposition $newrawposition
    focuser::waitwhilemoving
    log::info [format "focuser position shift is %+d." [expr {$newrawposition - $rawposition}]]
    checkfocuserpositionerror "after setting focuser"
    log::info [format "finished setting focuser after %.1f seconds." [utcclock::diff now $start]]
  }
  
  proc exposeforfocus {exposuretime fitsfileprefix} {
    exposeactivitycommand $exposuretime "focus" $fitsfileprefix/[utcclock::combinedformat now 0 false]
  }
  
  proc focusactivitycommand {exposuretime fitsfileprefix range step witness} {

    set start [utcclock::seconds]
    log::info "focusing."

    set originalposition [server::getdata "focuserposition"]
    set midposition $originalposition
    set focuserminposition [server::getdata "focuserminposition"]
    set focusermaxposition [server::getdata "focusermaxposition"]
    while {true} {
      set minposition [expr {max($midposition - int($range / 2), $focuserminposition)}]
      set maxposition [expr {min($midposition + int($range / 2), $focusermaxposition)}]
      set positionlist {}
      set fwhmlist     {}
      variable focuserbacklashoffset
      if {$focuserbacklashoffset <= 0} {
        for {set position $minposition} {$position <= $maxposition} {incr position $step} {
          movefocuseractivitycommand $position
          exposeforfocus $exposuretime $fitsfileprefix
          analyzeactivitycommand "fwhm"
          set fwhm [server::getdata "fwhm"]
          if {![string equal $fwhm ""]} {
            lappend positionlist $position
            lappend fwhmlist     $fwhm
          }
        }
      } else {
        for {set position $maxposition} {$position >= $minposition} {incr position [expr {-($step)}]} {
          movefocuseractivitycommand $position
          exposeforfocus $exposuretime $fitsfileprefix
          analyzeactivitycommand "fwhm"
          set fwhm [server::getdata "fwhm"]
          if {![string equal $fwhm ""]} {
            lappend positionlist $position
            lappend fwhmlist     $fwhm
          }
        }
      }
      if {[catch {
        set position [fitfocus::findmin $positionlist $fwhmlist]
      } message]} {
        log::warning "fitting failed: $message"
        set position $originalposition
        break
      } elseif {$minposition == $focuserminposition && $position <= $focuserminposition} {
        log::warning "the best focuser position is at or below minimum focuser position."
        set position $focuserminposition
        break
      } elseif {$maxposition == $focuserminposition && $position >= [server::getdata "focusermaxposition"]} {
        log::warning "the best focuser position is at or above the maximum focuser position."
        set position $focusermaxposition
        break
      } elseif {$position < $minposition} {
        set midposition $minposition
      } elseif {$position > $maxposition} {
        set midposition $maxposition
      } else {
        break
      }
      log::info "continuing focusing around $midposition."
    }

    movefocuseractivitycommand $position

    if {$witness} {
      exposeforfocus $exposuretime $fitsfileprefix
      analyzeactivitycommand "fwhm"
      set fwhm         [server::getdata "fwhm"]
      set fitsfilename [file tail [server::getdata "fitsfilename"]]
      set filter       [server::getdata "filter"]
      set binning      [server::getdata "detectorbinning"]
      set rawposition  [server::getdata "focuserrawposition"]
      if {![string equal $fwhm ""]} {
        log::summary "$fitsfilename: witness FWHM is $fwhm pixels with binning $binning in filter $filter at position $position (raw position $rawposition) in ${exposuretime}s."
        variable identifier
        config::setvarvalue $identifier "focuserinitialposition" $position
        config::setvarvalue $identifier "lastfocustimestamp"     [utcclock::format now]
      } else {
        log::summary "$fitsfilename: witness FWHM is unknown with binning $binning in filter $filter at position $position (raw position $rawposition) in ${exposuretime}s."
      }
    }
    
    log::info [format "finished focusing after %.1f seconds." [utcclock::diff now $start]]
    
  }

  proc mapfocusactivitycommand {exposuretime fitsfileprefix range step} {
    set start [utcclock::seconds]
    log::info "mapping focus."
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

  proc expose {exposuretime {exposuretype "object"} {fitsfileprefix ""}} {
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
      ![string equal $exposuretype "firstalertobject"] &&
      ![string equal $exposuretype "bias"            ] &&
      ![string equal $exposuretype "dark"            ] &&
      ![string equal $exposuretype "flat"            ] &&
      ![string equal $exposuretype "astrometry"      ] &&
      ![string equal $exposuretype "focus"           ] &&
      ![string equal $exposuretype "guidestart"      ] &&
      ![string equal $exposuretype "guidenext"       ] &&
      ![string equal $exposuretype "guidestartdonuts"] &&
      ![string equal $exposuretype "guidenextdonuts" ]
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
      "ccd::exposeactivitycommand $exposuretime $exposuretype $fitsfileprefix" \
      $timeoutmilliseconds
    return
  }
  
  proc analyze {type} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string equal $type "levels"         ] &&
      ![string equal $type "fwhm"           ] &&
      ![string equal $type "astrometry"     ] &&
      ![string equal $type "guidestart"     ] &&
      ![string equal $type "guidenext"      ] &&
      ![string equal $type "guidestartdonuts"] &&
      ![string equal $type "guidenextdonuts" ]
    } {
      error "invalid analysis type \"$type\"."
    }
    if {[string equal [server::getdata "fitsfilename"] ""]} {
      error "no previous exposure to analyze."
    }
    server::newactivitycommand "analyzing" "idle" \
      "ccd::analyzeactivitycommand $type"
    return
  }
  
  proc movefilterwheel {position} {
    server::checkstatus
    server::checkactivity "idle"
    variable filterlist
    if {[string equal $position "idle"]} {
      variable filterwheelidleposition
      set position $filterwheelidleposition
    }
    if {[lsearch -exact $filterlist $position] != -1} {
      set position [lsearch -exact $filterlist $position]
    }
    if {
      ![string is integer -strict $position] ||
      $position < 0 ||
      $position > [server::getdata "filterwheelmaxposition"]
    } {
      error "invalid filter wheel position \"$position\"."
    }
    server::newactivitycommand "moving" "idle" "ccd::movefilterwheelactivitycommand $position false"
    return
  }
  
  proc movefocuser {position setasinitial} {
    server::checkstatus
    server::checkactivity "idle"
    if {[string equal $position "current"]} {
      set position [server::getdata "requestedfocuserposition"]
    } elseif {
      ![string is integer -strict $position] ||
      $position < 0 ||
      $position > [server::getdata "focusermaxposition"]
    } {
      error "invalid focuser position \"$position\"."
    }
    variable identifier
    if {$setasinitial} {
      config::setvarvalue $identifier "focuserinitialposition" $position
    }
    server::newactivitycommand "moving" "idle" "ccd::movefocuseractivitycommand $position"
    return
  }

  proc setfocuser {position setasinitial} {
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
      config::setvarvalue $identifier "focuserinitialposition" $position
    }
    server::newactivitycommand "setting" "idle" "ccd::setfocuseractivitycommand $position"
    return
  }

  proc setcooler {setting} {
    set start [utcclock::seconds]
    log::info "setting cooler to $setting."
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string equal $setting "current"] && 
      ![string equal $setting "on"] && 
      ![string equal $setting "off"] &&
      ![string equal $setting "following"] &&
      ![string equal $setting "open"] &&
      ![string equal $setting "closed"] &&
      ![string is double -strict $setting]} {
      error "invalid cooler setting \"$setting\"."
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
    if {[string equal $setting "current"]} {
      set setting [server::getdata "detectorcoolersetting"]
      log::info "requested to set cooler to current setting which is \"$setting\"."
    }
    detector::setcooler $setting
    updatedata
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
    detector::setwindow $window
    variable detectorinitialbinning
    detector::setbinning $detectorinitialbinning
    updatedata
    log::info [format "finished setting window after %.1f seconds." [utcclock::diff now $start]]
    return
  }
  
  proc getwidth {} {
    variable detectorpixelscale
    set window [detector::getwindow]
    return [expr {$detectorpixelscale * [dict get $window nx]}]
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
    detector::setreadmode $readmode
    variable detectorwindows
    set window "initial"
    while {[dict exists $detectorwindows $window]} {
      set window [dict get $detectorwindows $window]
    }
    detector::setwindow $window
    variable detectorinitialbinning
    detector::setbinning $detectorinitialbinning
    updatedata
    log::info [format "finished setting read mode after %.1f seconds." [utcclock::diff now $start]]
    return
  }
  
  proc focus {exposuretime fitsfileprefix range step witness} {
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
    server::newactivitycommand "focusing" "idle" \
      "ccd::focusactivitycommand $exposuretime $fitsfileprefix $range $step $witness" false
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
