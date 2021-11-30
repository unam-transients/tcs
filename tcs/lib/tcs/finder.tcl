########################################################################

# This file is part of the UNAM telescope control system.

# $Id: finder.tcl 3601 2020-06-11 03:20:53Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "directories"

package require "detector[config::getvalue [config::getvalue "finder" "identifier"] "detectortype"]"
package require "focuser[config::getvalue [config::getvalue "finder" "identifier"] "focusertype"]"
package require "filterwheel[config::getvalue [config::getvalue "finder" "identifier"] "filterwheeltype"]"

package provide "finder" 0.0

namespace eval "finder" {

  variable svnid {$Id}

  ######################################################################

  variable identifier                      [config::getvalue "finder" "identifier"                     ]
  variable telescopedescription            [config::getvalue $identifier "telescopedescription"           ]
  variable detectortype                    [config::getvalue $identifier "detectortype"                   ]
  variable detectoridentifier              [config::getvalue $identifier "detectoridentifier"             ]
  variable detectorinitialreadmode         [config::getvalue $identifier "detectorinitialreadmode"        ]
  variable detectorinitialsoftwaregain     [config::getvalue $identifier "detectorinitialsoftwaregain"    ]
  variable detectorinitialbinning          [config::getvalue $identifier "detectorinitialbinning"         ]
  variable detectorfullunbinneddatawindow  [config::getvalue $identifier "detectorfullunbinneddatawindow" ]
  variable detectorfullunbinnedbiaswindow  [config::getvalue $identifier "detectorfullunbinnedbiaswindow" ]
  variable coolersettemperature            [config::getvalue $identifier "coolersettemperature"           ]
  variable filterwheeltype                 [config::getvalue $identifier "filterwheeltype"                ]
  variable filterwheelidentifier           [config::getvalue $identifier "filterwheelidentifier"          ]
  variable filterwheelinitialposition      [config::getvalue $identifier "filterwheelinitialposition"     ]
  variable allowedfilterwheelpositionerror [config::getvalue $identifier "allowedfilterwheelpositionerror"]
  variable focusertype                     [config::getvalue $identifier "focusertype"                    ]
  variable focuseridentifier               [config::getvalue $identifier "focuseridentifier"              ]
  variable focuserinitialposition          [config::getvalue $identifier "focuserinitialposition"         ]
  variable allowedfocuserpositionerror     [config::getvalue $identifier "allowedfocuserpositionerror"    ]
  variable defaultfocusexposuretime        [config::getvalue $identifier "defaultfocusexposuretime"       ]
  variable defaultfocusrange               [config::getvalue $identifier "defaultfocusrange"              ]
  variable defaultfocusstep                [config::getvalue $identifier "defaultfocusstep"               ]
  variable isstandalone                    [config::getvalue $identifier "isstandalone"                   ]
  variable detectorwidth                   [astrometry::parseangle [config::getvalue $identifier "detectorwidth"]]
  variable pointingmodelparameters         [config::getvalue $identifier "pointingmodelparameters"        ]
  variable temperaturelimit                [config::getvalue $identifier "temperaturelimit"               ]
  variable temperaturelimitoutletgroup     [config::getvalue $identifier "temperaturelimitoutletgroup" ]

  ######################################################################
  
  set server::datalifeseconds 5

  server::setdata "identifier"                   $identifier
  server::setdata "telescopedescription"         $telescopedescription
  server::setdata "detectortype"                 $detectortype
  server::setdata "detectoridentifier"           $detectoridentifier
  server::setdata "detectorwidth"                $detectorwidth
  server::setdata "filterwheeltype"              $filterwheeltype
  server::setdata "filterwheelidentifier"        $filterwheelidentifier
  server::setdata "focusertype"                  $focusertype
  server::setdata "focuseridentifier"            $focuseridentifier
  server::setdata "timestamp"                    ""
  server::setdata "stoppedtimestamp"             ""
  server::setdata "filterwheelposition"          ""
  server::setdata "lastfilterwheelposition"      ""
  server::setdata "requestedfilterwheelposition" ""
  server::setdata "focuserposition"              ""
  server::setdata "lastfocuserposition"          ""
  server::setdata "requestedfocuserposition"     ""
  server::setdata "exposuretime"                 ""
  server::setdata "fitsfilename"                 ""
  server::setdata "lastcorrectiontimestamp"      ""
  server::setdata "lastcorrectioneastoffset"     ""
  server::setdata "lastcorrectionnorthoffset"    ""
  server::setdata "solvedalpha"                  "unknown"
  server::setdata "solveddelta"                  "unknown"
  server::setdata "solvedequinox"                "unknown"
  server::setdata "solvedobservedalpha"          "unknown"
  server::setdata "solvedobserveddelta"          "unknown"
  server::setdata "mountobservedalpha"           "unknown"
  server::setdata "mountobserveddelta"           "unknown"
  server::setdata "fwhm"                         "unknown"
  
  variable settledelayseconds 3

  proc updatedata {} {
    
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
    set lastfocuserposition          [server::getdata "focuserposition"]
    set lastfilterwheelposition      [server::getdata "filterwheelposition"]

    set timestamp                    [utcclock::combinedformat now]
    set stoppedtimestamp             [server::getdata "stoppedtimestamp"]

    set filterwheelposition          [filterwheel::getposition]
    set focuserposition              [focuser::getposition]
    set requestedfilterwheelposition [server::getdata "requestedfilterwheelposition"]
    set requestedfocuserposition     [server::getdata "requestedfocuserposition"]
    
    if {[catch {
      expr {$filterwheelposition - $requestedfilterwheelposition}
    } filterwheelpositionerror]} {
      set filterwheelpositionerror ""
    }
    
    if {[catch {
      expr {$focuserposition - $requestedfocuserposition}
    } focuserpositionerror]} {
      set focuserpositionerror ""
    }

    variable settledelayseconds

    if {
      [string equal $filterwheelposition ""] || 
      [string equal $focuserposition ""] ||
      [string equal $lastfilterwheelposition ""] || 
      [string equal $lastfocuserposition ""] ||
      $filterwheelposition != $lastfilterwheelposition || 
      $focuserposition != $lastfocuserposition
    } {
      set stoppedtimestamp ""
    } elseif {[string equal $stoppedtimestamp ""]} {
      set stoppedtimestamp $lasttimestamp
    }

    if {![string equal $stoppedtimestamp ""] &&
        [utcclock::diff $timestamp $stoppedtimestamp] >= $settledelayseconds} {
      set settled true
    } else {
      set settled false
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

    server::setdata "timestamp"                    [utcclock::combinedformat now]
    server::setdata "lasttimestamp"                $lasttimestamp
    server::setdata "detectordescription"          [detector::getdescription]
    server::setdata "detectorsoftwaregain"         [detector::getsoftwaregain]
    server::setdata "detectorbinning"              [detector::getbinning]
    server::setdata "detectorreadmode"             [detector::getreadmode]
    server::setdata "detectordetectortemperature"  $detectortemperature
    server::setdata "detectorhousingtemperature"   $housingtemperature
    server::setdata "detectorcoolerstate"          [detector::getcoolerstate]
    server::setdata "detectorcoolersettemperature" [detector::getcoolersettemperature]
    server::setdata "detectorcoolerpower"          [detector::getcoolerpower]
    server::setdata "filterwheeldescription"       [filterwheel::getdescription]
    server::setdata "filterwheelposition"          $filterwheelposition
    server::setdata "filterwheelpositionerror"     $filterwheelpositionerror
    server::setdata "lastfilterwheelposition"      $lastfilterwheelposition
    server::setdata "filterwheelmaxposition"       [filterwheel::getmaxposition]
    server::setdata "focuserdescription"           [focuser::getdescription]
    server::setdata "focuserposition"              $focuserposition
    server::setdata "lastfocuserposition"          $lastfocuserposition
    server::setdata "focuserminposition"           [focuser::getminposition]
    server::setdata "focusermaxposition"           [focuser::getmaxposition]
    server::setdata "focuserpositionerror"         $focuserpositionerror
    server::setdata "stoppedtimestamp"             $stoppedtimestamp
    server::setdata "settled"                      $settled
    
    log::writedatalog [server::getdata "identifier"] {
      timestamp
      detectordetectortemperature detectorhousingtemperature
      detectorcoolerstate detectorcoolersettemperature detectorcoolerpower
    }

  }
  
  ######################################################################

  variable updatedatapollmilliseconds 200

  proc updatedataloop {} {
    while {true} {
      if {[catch {updatedata} message]} {
        log::error "error while updating data: $message"
      }
      server::resumeactivitycommand
      variable updatedatapollmilliseconds
      coroutine::after $updatedatapollmilliseconds
    }
  }

  ######################################################################

  proc checkfilterwheelpositionerror {when} {
    set filterwheelpositionerror [server::getdata "filterwheelpositionerror"]
    variable allowedfilterwheelpositionerror
    if {abs($filterwheelpositionerror) > $allowedfilterwheelpositionerror} {
      log::warning [format "filter wheel position error is %+d $when." $filterwheelpositionerror]
    }
  }

  ######################################################################

  proc checkfocuserpositionerror {when} {
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

  proc getfitsfilename {} {
    variable identifier
    set seconds [utcclock::seconds]
    return [file join \
      [directories::vartoday $seconds] \
      $identifier \
      "[utcclock::combinedformat $seconds 3 false].fits" \
    ]
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
        log::warning "killing the solving process group failed: $message"
      }
    }
    catch {close $solvingchannel}
    set solvingchannel {}
  }

  proc settle {} {
    log::debug "settling."
    server::setdata "stoppedtimestamp"        ""
    server::setdata "lastfocuserposition"     ""
    server::setdata "lastfilterwheelposition" ""
    server::setdata "settled"                 false
    while {![server::getdata "settled"]} {
      coroutine::yield
    }
    log::debug "settled."
  }

  proc startactivitycommand {} {
    variable detectoridentifier
    if {[catch {detector::detectorrawstart} message]} {
      error "unable to start detector: $message"
    }
    while {[catch {detector::open $detectoridentifier} message]} {
      log::debug "unable to open detector: $message"
      coroutine::after 5000
    }
    detector::setcooler "following"
    variable filterwheelidentifier
    while {[catch {filterwheel::open $filterwheelidentifier} message]} {
      log::debug "unable to open filter wheel: $message"
      coroutine::after 5000
    }
    variable focuseridentifier
    while {[catch {focuser::open $focuseridentifier} message]} {
      log::debug "unable to open focuser: $message"
      coroutine::after 5000
    }
    settle
  }
  
  proc initializeactivitycommand {} {
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
    detector::setwindow $detectorfullunbinneddatawindow
    variable detectorinitialbinning
    detector::setbinning $detectorinitialbinning
    detector::setcooler following
    variable filterwheelinitialposition
    movefilterwheelactivitycommand $filterwheelinitialposition
    variable focuserinitialposition
    movefocuseractivitycommand $focuserinitialposition
    checkfilterwheelpositionerror "after initializing"
    checkfocuserpositionerror "after initializing"
  }
  
  proc stopactivitycommand {} {
    stopexposing
    stopsolving
  }
  
  proc exposeactivitycommand {exposuretime exposuretype} {
    variable identifier
    stopexposing
    stopsolving
    set finalfilename [getfitsfilename]
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
    server::setdata "exposuretime"        $exposuretime
    server::setdata "fitsfilename"        $finalfilename
    server::setdata "solvedalpha"         "unknown"
    server::setdata "solveddelta"         "unknown"
    server::setdata "solvedequinox"       "unknown"
    server::setdata "solvedobservedalpha" "unknown"
    server::setdata "solvedobserveddelta" "unknown"
    server::setdata "mountobservedalpha"  "unknown"
    server::setdata "mountobserveddelta"  "unknown"
    server::setdata "fwhm"                "unknown"
    if {[string equal $exposuretype "object"] || 
        [string equal $exposuretype "astrometry"] ||
        [string equal $exposuretype "focus"]
    } {
      set shutter open
    } elseif {[string equal $exposuretype "dark"]} {
      set shutter closed
    }
    set fitsdirectory [file dirname $finalfilename]
    if {[catch {file mkdir $fitsdirectory} message]} {
      error "unable to create FITS file directory \"$fitsdirectory\": $message"
    }
    if {[catch {
      set channel [detector::openfitsheader $tmpfilename]
      fitsheader::writekeyandvalue $channel "ORIGIN"  string "OAN/SPM"
      fitsheader::writekeyandvalue $channel "EXPTIME" double [expr {double($exposuretime)}]
      fitsheader::writekeyandvalue $channel "EXPTYPE" string $exposuretype
      fitsheader::writetcsfitsheader $channel "S"
      fitsheader::writefinderfitsheader $channel [server::getdata "identifier"] "S"
    } message]} {
      error "while writing FITS header: $message"
    }
    set seconds [utcclock::seconds]
    detector::startexposure $exposuretime $shutter
    while {[detector::continueexposure]} {
      coroutine::yield
    }
    if {[catch {
      fitsheader::writekeyandvalue $channel "DATE-OBS" date $seconds
      fitsheader::writekeyandvalue $channel "MJD-OBS"  double [format "%.8f" [utcclock::mjd $seconds]]
      fitsheader::writetcsfitsheader $channel "E"
      fitsheader::writefinderfitsheader $channel [server::getdata "identifier"] "E"
      detector::closefitsheader $channel
    } message]} {
      error "while writing FITS header: $message"
    }
    if {[catch {detector::readexposure} message]} {
      error "while reading exposure: $message"
    }    
    if {[catch {detector::writeexposure $tmpfilename $finalfilename $latestfilename $currentfilename false} message]} {
      error "while writing FITS data: $message"
    }
    if {[string equal $exposuretype "focus"]} {
      set datawindow [detector::getdatawindow]
      set sx [dict get $datawindow sx]
      set sy [dict get $datawindow sy]
      set nx [dict get $datawindow nx]
      set ny [dict get $datawindow ny]
      log::debug "ACF fitting region is $sx $nx $sy $ny."
      set fitsfwhmchannel [open \
        "|[directories::bin]/tcs fitpsf $finalfilename $sx $nx $sy $ny 16 3 \"[file join [directories::etc] wisdom]\"" \
      ]
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
        server::setdata "fwhm" $fwhm
        set x [format "%.2f" $x]
        set y [format "%.2f" $y]
        set binning [server::getdata "detectorbinning"]        
        log::info "FWHM is $fwhm pixels with binning $binning in ${exposuretime} seconds."
      }
    }
    if {[string equal $exposuretype "astrometry"]} {
      variable solvingchannel
      set solvingchannel [open "|[directories::bin]/tcs newpgrp fitssolvewcs -c -f -e \"[directories::etc]\" -- \"$finalfilename\"" "r"]
      chan configure $solvingchannel -buffering "line"
      chan configure $solvingchannel -encoding "ascii"
      set line [coroutine::gets $solvingchannel]
      catch {close $solvingchannel}
      set solvingchannel {}
      if {
        [string equal $line ""] ||
        [scan $line "%f %f %f" solvedalpha solveddelta solvedequinox] != 3 ||
        $solvedequinox != 2000.0
      } {
        log::debug "astrometry solving failed: \"$line\"."
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
  
  proc movefilterwheelactivitycommand {position} {
    server::setdata "requestedfilterwheelposition" $position
    filterwheel::move $position
    settle
    checkfilterwheelpositionerror "after moving filter wheel"
  }
  
  proc movefocuseractivitycommand {position} {
    server::setdata "requestedfocuserposition" $position
    focuser::move $position
    settle
    checkfocuserpositionerror "after moving focuser"
  }
  
  proc focusactivitycommand {exposuretime range step} {

    log::info "focusing."
    
    set originalposition [server::getdata "focuserposition"]

    set midposition [server::getdata "focuserposition"]
    while {true} {
      set minposition [expr {max($midposition - int($range / 2), [server::getdata "focuserminposition"])}]
      set maxposition [expr {min($midposition + int($range / 2), [server::getdata "focusermaxposition"])}]
      log::info "focusing from $minposition to $maxposition in steps of $step."
      set positionlist {}
      set fwhmlist {}
      for {set position $minposition} {$position <= $maxposition} {incr position $step} {
        movefocuseractivitycommand $position
        exposeactivitycommand $exposuretime "focus"
        set fwhm [server::getdata "fwhm"]
        if {[string equal $fwhm "unknown"]} {
          log::info "[file tail [server::getdata "fitsfilename"]]: FWHM is unknown at $position."
        } else {
          log::info "[file tail [server::getdata "fitsfilename"]]: FWHM is $fwhm pixels at $position."
          lappend positionlist $position
          lappend fwhmlist $fwhm
        }
      }
      if {[catch {
        set bestposition [fitfocus::findmin $positionlist $fwhmlist]
      } message]} {
        log::warning "focusing failed: $message"
        set bestposition $originalposition
        break
      } elseif {$minposition < $bestposition && $bestposition < $maxposition} {
        log::info "focusing succeeded."
        break
      } elseif {$bestposition <= $minposition && $minposition == [server::getdata "focuserminposition"]} {
        log::warning "focusing failed: the best focuser position is below the minimum focuser position."
        set bestposition [server::getdata "focuserminposition"]
        break
      } elseif {$bestposition >= $maxposition && $maxposition == [server::getdata "focusermaxposition"]} {
        log::warning "focusing failed: the best focuser position is above the maximum focuser position."
        set bestposition [server::getdata "focusermaxposition"]
        break
      } elseif {$bestposition <= $minposition} {
        log::info "continuing to focus."
        set midposition $minposition
      } elseif {$bestposition >= $maxposition} {
        log::info "continuing to focus."
        set midposition $maxposition
      }
    }

    movefocuseractivitycommand $bestposition
    exposeactivitycommand $exposuretime "focus"
    set fwhm [server::getdata "fwhm"]
    if {[string equal $fwhm "unknown"]} {
      log::summary "[file tail [server::getdata "fitsfilename"]]: witness FWHM is unknown at $bestposition."
    } else {
      log::summary "[file tail [server::getdata "fitsfilename"]]: witness FWHM is $fwhm pixels at $bestposition."
    }
    set fitsdirectory [file join [directories::var] [server::getdata "identifier"]]
    if {[catch {file mkdir $fitsdirectory} message]} {
      error "unable to create FITS file directory \"$fitsdirectory\": $message"
    }
    if {[catch {file copy -force -- [server::getdata "fitsfilename"] $fitsdirectory} message]} {
      error "unable to copy FITS file: $message"
    }
    variable identifier
    config::setvarvalue $identifier "lastfocustimestamp" [utcclock::format now]

    log::info "finished focusing."
    
  }

  ######################################################################
  
  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    server::newactivitycommand "initializing" "idle" finder::initializeactivitycommand
    return
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::newactivitycommand "stopping" [server::getstoppedactivity] finder::stopactivitycommand
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::newactivitycommand "resetting" [server::getstoppedactivity] finder::stopactivitycommand
  }

  proc expose {exposuretime {exposuretype "object"}} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is double -strict $exposuretime] ||
      $exposuretime < 0
    } {
      error "invalid exposure time."
    }
    if {
      ![string equal $exposuretype "object"] &&
      ![string equal $exposuretype "astrometry"] &&
      ![string equal $exposuretype "focus"] &&
      ![string equal $exposuretype "dark"]
    } {
      error "invalid exposure type \"$exposuretype\"."
    }
    server::newactivitycommand "exposing" "idle" \
      "finder::exposeactivitycommand $exposuretime $exposuretype"
    return
  }
  
  proc movefilterwheel {position} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is integer -strict $position] ||
      $position < 0 ||
      $position > [server::getdata "filterwheelmaxposition"]
    } {
      error "invalid filter wheel position."
    }
    server::newactivitycommand "moving" "idle" "finder::movefilterwheelactivitycommand $position"
    return
  }
  
  proc movefocuser {position setasinitial} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is integer -strict $position] ||
      $position < 0 ||
      $position > [server::getdata "focusermaxposition"]
    } {
      error "invalid focuser position."
    }
    if {$setasinitial} {
      variable focuserinitialposition
      set focuserinitialposition $position
      variable identifier
      config::setvarvalue $identifier "focuserinitialposition" $position
    }
    server::newactivitycommand "moving" "idle" "finder::movefocuseractivitycommand $position"
    return
  }

  proc setcooler {setting} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string equal $setting "on"] && 
      ![string equal $setting "off"] &&
      ![string equal $setting "following"] &&
      ![string equal $setting "open"] &&
      ![string equal $setting "closed"] &&
      ![string is double -strict $setting]} {
      error "invalid cooler setting: \"$setting\"."
    }
    if {[string equal $setting "open"]} {
      set setting "on"
    }
    if {[string equal $setting "closed"]} {
      set setting "following"
    }    
    if {[string equal $setting "on"]} {
      variable coolersettemperature
      set setting $coolersettemperature
    }
    detector::setcooler $setting
    updatedata
    return
  }

  proc setsoftwaregain {detectorsoftwaregain} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is integer -strict $detectorsoftwaregain] ||
      $detectorsoftwaregain < 1
    } {
      error "invalid detector software gain."
    }
    detector::setsoftwaregain $detectorsoftwaregain
    updatedata
    return
  }

  proc setbinning {detectorbinning} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is integer -strict $detectorbinning] ||
      $detectorbinning < 1
    } {
      error "invalid detector binning."
    }
    detector::setbinning $detectorbinning
    updatedata
    return
  }
  
  proc focus {exposuretime range step} {
    server::checkstatus
    server::checkactivity "idle"
    if {
      ![string is double -strict $exposuretime] ||
      $exposuretime < 0
    } {
      error "invalid exposure time."
    }
    if {$exposuretime == 0.0} {
      variable defaultfocusexposuretime
      set exposuretime $defaultfocusexposuretime
    }
    if {![string is integer -strict $range]} {
      error "invalid range."
    }
    if {$range == 0} {
      variable defaultfocusrange
      set range $defaultfocusrange
    }
    if {![string is integer -strict $step]} {
      error "invalid step."
    }
    if {$step == 0} {
      variable defaultfocusstep
      set step $defaultfocusstep
    }
    server::newactivitycommand "focusing" "idle" \
      "finder::focusactivitycommand $exposuretime $range $step" false
  }
  
  proc correct {truemountalpha truemountdelta equinox} {
    server::checkstatus
    server::checkactivity "idle"
    set truemountalpha [astrometry::parseangle $truemountalpha "hms"]
    set truemountdelta [astrometry::parseangle $truemountdelta "dms"]
    log::debug "correcting at [astrometry::radtohms $truemountalpha 2 false] [astrometry::radtodms $truemountdelta 1 true] $equinox"
    if {[string equal $equinox "observed"]} {
      set truemountobservedalpha $truemountalpha
      set truemountobserveddelta $truemountdelta
    } else {
      set truemountobservedalpha [astrometry::observedalpha $truemountalpha $truemountdelta $equinox]
      set truemountobserveddelta [astrometry::observeddelta $truemountalpha $truemountdelta $equinox]    
    }
    set observedmountalpha [server::getdata "mountobservedalpha"]
    set observedmountdelta [server::getdata "mountobserveddelta"]
    if {[string equal $observedmountalpha "unknown"] || [string equal $observedmountdelta "unknown"]} {
      error "the latest finder image has not been solved."
    }
    set dalpha [astrometry::foldradsymmetric [expr {$truemountobservedalpha - $observedmountalpha}]]
    set ddelta [astrometry::foldradsymmetric [expr {$truemountobserveddelta - $observedmountdelta}]]
    set eastoffset [expr {$dalpha * cos($truemountobserveddelta)}]
    set northoffset $ddelta
    log::debug [format "correction is %s E and %s N." [astrometry::formatoffset $eastoffset] [astrometry::formatoffset $northoffset]]
    server::setdata "lastcorrectiontimestamp" [utcclock::format]
    server::setdata "lastcorrectioneastoffset"  $eastoffset
    server::setdata "lastcorrectionnorthoffset" $northoffset
    set dCH [expr {-($eastoffset)}]
    set dID $northoffset
    updatepointingmodel $dCH $dID
  }

  ######################################################################
  
  proc start {} {
    server::newactivitycommand "starting" "started" finder::startactivitycommand
    after idle {
      coroutine ::finder::updatedataloopcoroutine finder::updatedataloop      
    }
  }

}
