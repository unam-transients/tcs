########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

config::setdefaultvalue "mount" "configuration" "equatorial"

config::setdefaultvalue "mount" "trackingpositionerrorlimit"   "1as"
config::setdefaultvalue "mount" "fixedpositionerrorlimit"      "1as"
config::setdefaultvalue "mount" "trackingsettlingdelayseconds" "0"
config::setdefaultvalue "mount" "movingsettlingdelayseconds"   "0"

config::setdefaultvalue "mount" "easthalimit"                ""
config::setdefaultvalue "mount" "westhalimit"                ""
config::setdefaultvalue "mount" "westhalimit"                ""
config::setdefaultvalue "mount" "meridianhalimit"            ""
config::setdefaultvalue "mount" "northdeltalimit"            ""
config::setdefaultvalue "mount" "southdeltalimit"            ""
config::setdefaultvalue "mount" "polardeltalimit"            ""
config::setdefaultvalue "mount" "minzenithdistancelimit"     ""
config::setdefaultvalue "mount" "maxzenithdistancelimit"     ""

namespace eval "mount" {

  ######################################################################

  variable configuration [config::getvalue "mount" "configuration"]
  
  variable trackingpositionerrorlimit   [astrometry::parseoffset [config::getvalue "mount" "trackingpositionerrorlimit"]]
  variable fixedpositionerrorlimit      [astrometry::parseoffset [config::getvalue "mount" "fixedpositionerrorlimit"]]
  variable trackingsettlingdelayseconds [config::getvalue "mount" "trackingsettlingdelayseconds"]
  variable movingsettlingdelayseconds   [config::getvalue "mount" "movingsettlingdelayseconds"]
  
  ######################################################################

  variable easthalimit
  variable westhalimit
  variable meridianhalimit
  variable northdeltalimit
  variable southdeltalimit
  variable polardeltalimit
  variable minzenithdistancelimit
  variable maxzenithdistancelimit
  
  if {[string equal "" [config::getvalue "mount" "easthalimit"]]} {
    set easthalimit ""
  } else {
    set easthalimit [astrometry::parseha [config::getvalue "mount" "easthalimit"]]
  }

  if {[string equal "" [config::getvalue "mount" "westhalimit"]]} {
    set westhalimit ""
  } else {
    set westhalimit [astrometry::parseha [config::getvalue "mount" "westhalimit"]]
  }

  if {[string equal "" [config::getvalue "mount" "meridianhalimit"]]} {
    set meridianhalimit ""
  } else {
    set meridianhalimit [astrometry::parseha [config::getvalue "mount" "meridianhalimit"]]
  }

  if {[string equal "" [config::getvalue "mount" "northdeltalimit"]]} {
    set northdeltalimit ""
  } else {
    set northdeltalimit [astrometry::parsedelta [config::getvalue "mount" "northdeltalimit"]]
  }

  if {[string equal "" [config::getvalue "mount" "southdeltalimit"]]} {
    set southdeltalimit ""
  } else {
    set southdeltalimit [astrometry::parsedelta [config::getvalue "mount" "southdeltalimit"]]
  }

  if {[string equal "" [config::getvalue "mount" "polardeltalimit"]]} {
    set polardeltalimit ""
  } else {
    set polardeltalimit [astrometry::parsedelta [config::getvalue "mount" "polardeltalimit"]]
  }

  if {[string equal "" [config::getvalue "mount" "minzenithdistancelimit"]]} {
    set minzenithdistancelimit ""
  } else {
    set minzenithdistancelimit [astrometry::parseangle [config::getvalue "mount" "minzenithdistancelimit"]]
  }

  if {[string equal "" [config::getvalue "mount" "maxzenithdistancelimit"]]} {
    set maxzenithdistancelimit ""
  } else {
    set maxzenithdistancelimit [astrometry::parseangle [config::getvalue "mount" "maxzenithdistancelimit"]]
  }

  ######################################################################

  server::setdata "configuration" $configuration

  ######################################################################

  proc updaterequestedpositiondata {{defaultmountrotation false}} {
  
    variable configuration
    variable usemountcoordinates

    log::debug "updating requested position."

    set seconds [utcclock::seconds]

    if {[catch {client::update "target"} message]} {
      error "unable to update target data: $message"
    }
    set targetstatus   [client::getstatus "target"]
    set targetactivity [client::getdata "target" "activity"]
    log::debug "target status is \"$targetstatus\"."
    log::debug "target activity is \"$targetactivity\"."

    set activity [server::getactivity]
    set requestedactivity [server::getrequestedactivity]
    log::debug "continuing to update requested position for activity \"$activity\" and requested activity \"$requestedactivity\"."

    set requestedmountha                ""
    set requestedmountalpha             ""
    set requestedmountdelta             ""
    set requestedmountharate            ""
    set requestedmountalpharate         ""
    set requestedmountdeltarate         ""

    set mounthaerror                    ""
    set mountalphaerror                 ""
    set mountdeltaerror                 ""

    if {
      [string equal $requestedactivity "tracking"] &&
      [string equal $targetstatus "ok"] &&
      [string equal $targetactivity "tracking"]
    } {

      log::debug "updating requested position in the tracking/ok/tracking branch."

      set requestedtimestamp              [client::getdata "target" "timestamp"]

      set requestedstandardalpha          [client::getdata "target" "standardalpha"]
      set requestedstandarddelta          [client::getdata "target" "standarddelta"]
      set requestedstandardalpharate      [client::getdata "target" "standardalpharate"]
      set requestedstandarddeltarate      [client::getdata "target" "standarddeltarate"]
      set requestedstandardequinox        [client::getdata "target" "standardequinox"]

      set requestedobservedha             [client::getdata "target" "observedha"]
      set requestedobservedalpha          [client::getdata "target" "observedalpha"]
      set requestedobserveddelta          [client::getdata "target" "observeddelta"]
      set requestedobservedharate         [client::getdata "target" "observedharate"]
      set requestedobservedalpharate      [client::getdata "target" "observedalpharate"]
      set requestedobserveddeltarate      [client::getdata "target" "observeddeltarate"]
      set requestedobservedazimuth        [client::getdata "target" "observedazimuth"]
      set requestedobservedzenithdistance [client::getdata "target" "observedzenithdistance"]
      
      if {$defaultmountrotation} {
        set requestedmountrotation [defaultmountrotation $requestedobservedha $requestedobservedalpha]
      } else {
        set requestedmountrotation [server::getdata "mountrotation"]
      }

      if {$usemountcoordinates} {
      
        set seconds [utcclock::scan $requestedtimestamp]
        set dseconds 60
        set futureseconds [expr {$seconds + $dseconds}]

        set mountha       [server::getdata "mountha"      ]
        set mountalpha    [server::getdata "mountalpha"   ]
        set mountdelta    [server::getdata "mountdelta"   ]

        set mountdha    [mountdha    $requestedobservedha    $requestedobserveddelta $requestedmountrotation]
        set mountdalpha [mountdalpha $requestedobservedalpha $requestedobserveddelta $requestedmountrotation $seconds]
        set mountddelta [mountddelta $requestedobservedalpha $requestedobserveddelta $requestedmountrotation $seconds]

        set requestedmountha    [astrometry::foldradsymmetric [expr {$requestedobservedha + $mountdha}]]
        set requestedmountalpha [astrometry::foldradpositive [expr {$requestedobservedalpha + $mountdalpha}]]
        set requestedmountdelta [expr {$requestedobserveddelta + $mountddelta}]

        set futurerequestedmountrotation $requestedmountrotation
        set futurerequestedobservedha    [astrometry::foldradsymmetric [expr {
          $requestedobservedha + $dseconds * $requestedobservedharate
        }]]
        set futurerequestedobservedalpha [astrometry::foldradpositive [expr {
          $requestedobservedalpha + $dseconds * $requestedobservedalpharate / cos($requestedobserveddelta)
        }]]
        set futurerequestedobserveddelta [expr {
          $requestedobserveddelta + $dseconds * $requestedobserveddeltarate
        }]

        set futuremountdha    [mountdha    $futurerequestedobservedha    $futurerequestedobserveddelta $futurerequestedmountrotation]
        set futuremountdalpha [mountdalpha $futurerequestedobservedalpha $futurerequestedobserveddelta $futurerequestedmountrotation $futureseconds]
        set futuremountddelta [mountddelta $futurerequestedobservedalpha $futurerequestedobserveddelta $futurerequestedmountrotation $futureseconds]

        set futurerequestedmountha    [astrometry::foldradsymmetric [expr {$futurerequestedobservedha + $futuremountdha}]]
        set futurerequestedmountalpha [astrometry::foldradpositive [expr {$futurerequestedobservedalpha + $futuremountdalpha}]]
        set futurerequestedmountdelta [expr {$futurerequestedobserveddelta + $futuremountddelta}]

        set requestedmountharate      [astrometry::foldradsymmetric [expr {
          ($futurerequestedmountha - $requestedmountha) / $dseconds
        }]]
        set requestedmountalpharate   [astrometry::foldradsymmetric [expr {
          ($futurerequestedmountalpha - $requestedmountalpha) / $dseconds * cos($requestedobserveddelta)
        }]]
        set requestedmountdeltarate   [expr {
          ($futurerequestedmountdelta - $requestedmountdelta) / $dseconds
        }]

        set mounthaerror    ""
        set mountalphaerror [astrometry::foldradsymmetric [expr {$mountalpha - $requestedmountalpha}]]
        set mountdeltaerror [expr {$mountdelta - $requestedmountdelta}]
        
      }

    } elseif {
      [string equal $requestedactivity "idle"] &&
      [string equal $targetstatus "ok"] &&
      [string equal $targetactivity "idle"]
    } {

      log::debug "updating requested position in the idle/ok/idle equatorial branch."

      set requestedtimestamp              [client::getdata "target" "timestamp"]

      set requestedstandardalpha          ""
      set requestedstandarddelta          ""
      set requestedstandardalpharate      ""
      set requestedstandarddeltarate      ""
      set requestedstandardequinox        ""

      set requestedobservedha             [client::getdata "target" "observedha"]
      set requestedobservedalpha          [client::getdata "target" "observedalpha"]
      set requestedobserveddelta          [client::getdata "target" "observeddelta"]
      set requestedobservedharate         ""
      set requestedobservedalpharate      ""
      set requestedobserveddeltarate      ""
      set requestedobservedazimuth        [client::getdata "target" "observedazimuth"]
      set requestedobservedzenithdistance [client::getdata "target" "observedzenithdistance"]

      if {$defaultmountrotation} {
        set requestedmountrotation [defaultmountrotation $requestedobservedha $requestedobservedalpha]
      } else {
        set requestedmountrotation [server::getdata "mountrotation"]
      }
            
      if {$usemountcoordinates} {

        set mountha       [server::getdata "mountha"      ]
        set mountalpha    [server::getdata "mountalpha"   ]
        set mountdelta    [server::getdata "mountdelta"   ]

        set mountdha    [mountdha    $requestedobservedha    $requestedobserveddelta $requestedmountrotation]
        set mountddelta [mountddelta $requestedobservedalpha $requestedobserveddelta $requestedmountrotation]

        set requestedmountha         [astrometry::foldradsymmetric [expr {$requestedobservedha + $mountdha}]]
        set requestedmountalpha      ""
        set requestedmountdelta      [expr {$requestedobserveddelta + $mountddelta}]

        set requestedmountharate     ""
        set requestedmountalpharate  ""
        set requestedmountdeltarate  ""

        set mounthaerror    [astrometry::foldradsymmetric [expr {$mountha    - $requestedmountha   }]]
        set mountalphaerror ""
        set mountdeltaerror [expr {$mountdelta - $requestedmountdelta}]
    
      }

    } else {

      log::debug "updating requested position in the last branch."

      set requestedtimestamp              ""

      set requestedstandardalpha          ""
      set requestedstandarddelta          ""
      set requestedstandardalpharate      ""
      set requestedstandarddeltarate      ""
      set requestedstandardequinox        ""

      set requestedmountrotation          ""
      set requestedobservedha             ""
      set requestedobservedalpha          ""
      set requestedobserveddelta          ""
      set requestedobservedharate         ""
      set requestedobservedalpharate      ""
      set requestedobserveddeltarate      ""
      set requestedobservedazimuth        ""
      set requestedobservedzenithdistance ""

      set requestedmountha                ""
      set requestedmountalpha             ""
      set requestedmountdelta             ""
      set requestedmountharate            ""
      set requestedmountalpharate         ""
      set requestedmountdeltarate         ""

      set mounthaerror                    ""
      set mountalphaerror                 ""
      set mountdeltaerror                 ""

    }

    server::setdata "requestedtimestamp"              $requestedtimestamp
    server::setdata "requestedmountrotation"          $requestedmountrotation
    server::setdata "requestedstandardalpha"          $requestedstandardalpha
    server::setdata "requestedstandarddelta"          $requestedstandarddelta
    server::setdata "requestedstandardalpharate"      $requestedstandardalpharate
    server::setdata "requestedstandarddeltarate"      $requestedstandarddeltarate
    server::setdata "requestedstandardequinox"        $requestedstandardequinox
    server::setdata "requestedobservedha"             $requestedobservedha
    server::setdata "requestedobservedalpha"          $requestedobservedalpha
    server::setdata "requestedobserveddelta"          $requestedobserveddelta
    server::setdata "requestedobservedharate"         $requestedobservedharate
    server::setdata "requestedobservedalpharate"      $requestedobservedalpharate
    server::setdata "requestedobserveddeltarate"      $requestedobserveddeltarate
    server::setdata "requestedobservedazimuth"        $requestedobservedazimuth
    server::setdata "requestedobservedzenithdistance" $requestedobservedzenithdistance
    server::setdata "requestedmountha"                $requestedmountha
    server::setdata "requestedmountalpha"             $requestedmountalpha
    server::setdata "requestedmountdelta"             $requestedmountdelta
    server::setdata "requestedmountharate"            $requestedmountharate
    server::setdata "requestedmountalpharate"         $requestedmountalpharate
    server::setdata "requestedmountdeltarate"         $requestedmountdeltarate
    server::setdata "mounthaerror"                    $mounthaerror
    server::setdata "mountalphaerror"                 $mountalphaerror
    server::setdata "mountdeltaerror"                 $mountdeltaerror

    log::debug "finished updating requested position."
  }
  
  ######################################################################
  
  variable tracking                  false
  variable trackingtimestamp         ""
  variable trackingsettlingtimestamp ""
  variable moving                    false
  variable movingsettlingtimestamp   ""

  variable waittracking

  proc updatetracking {mounttracking axishatrackingerror axisdeltatrackingerror mounteasttrackingerror mountnorthtrackingerror} {

    variable tracking
    variable trackingsettlingtimestamp
    variable trackingtimestamp
    variable trackingpositionerrorlimit
    variable trackingsettlingdelayseconds
    
    set lasttracking $tracking
    set mounttrackingerror [expr {sqrt(pow($mounteasttrackingerror, 2) + pow($mountnorthtrackingerror, 2))}]

    if {![string equal [server::getrequestedactivity] "tracking"]} {

      set tracking false
      set trackingsettlingtimestamp ""

    } elseif {!$mounttracking} {

      set tracking false
      set trackingsettlingtimestamp ""
      
    } elseif {$lasttracking} {

      set tracking true

    } elseif {$trackingpositionerrorlimit != 0 && $mounttrackingerror > $trackingpositionerrorlimit} {

      set tracking false
      set trackingsettlingtimestamp ""
      
    } elseif {$trackingsettlingdelayseconds == 0} {
    
      set tracking true

    } elseif {[string equal $trackingsettlingtimestamp ""]} {

      log::info "settling."
      set trackingsettlingtimestamp [utcclock::combinedformat "now"]
      set tracking false

    } elseif {[utcclock::diff "now" $trackingsettlingtimestamp] < $trackingsettlingdelayseconds} {

      set tracking false

    } else {

      set tracking true

    }
    
    if {!$lasttracking && $tracking} {
      log::info "started tracking."
      starttrackingstatistics      
    } elseif {$lasttracking && !$tracking} {
      log::info "stopped tracking."
      set trackingtimestamp ""
    }
    
    if {$tracking} {
      updatetrackingstatistics $axishatrackingerror $axisdeltatrackingerror $mounteasttrackingerror $mountnorthtrackingerror
    }

  }

  proc waituntiltracking {} {
    log::debug "waituntiltracking: starting."
    variable tracking
    set tracking false
    while {!$tracking} {
      log::debug "waituntiltracking: yielding."
      coroutine::yield
    }
    log::debug "waituntiltracking: finished."
  }

  proc waituntilnottracking {} {
    log::debug "waituntilnottracking: starting."
    variable tracking
    while {$tracking} {
      log::debug "waituntilnottracking: yielding."
      coroutine::yield
    }
    log::debug "waituntilnottracking: finished."
  }
  
  proc updatemoving {mountmoving} {
    
    variable moving
    variable movingsettlingtimestamp
    variable movingsettlingdelayseconds
    
    set lastmoving $moving
    
    if {$mountmoving} {

      set moving true
      set movingsettlingtimestamp ""
      
    } elseif {!$lastmoving} {

      set moving false

    } elseif {$movingsettlingdelayseconds == 0} {
    
      set moving false

    } elseif {[string equal $movingsettlingtimestamp ""]} {

      log::info "settling."
      set movingsettlingtimestamp [utcclock::combinedformat "now"]
      set moving true

    } elseif {[utcclock::diff "now" $movingsettlingtimestamp] < $movingsettlingdelayseconds} {

      set moving true

    } else {

      set moving false

    }
    
    if {!$lastmoving && $moving} {
      log::info "started moving."
    } elseif {$lastmoving && !$moving} {
      log::info "stopped moving."
    }

  }

  proc waitwhilemoving {} {
    log::debug "waitwhilemoving: starting."
    variable moving
    set moving true
    while {$moving} {
      log::debug "waitwhilemoving: yielding."
      coroutine::yield
    }
    log::debug "waitwhilemoving: finished."
  }

  ######################################################################
  
  variable sumaxishatrackingerror       0
  variable sumaxisdeltatrackingerror    0
  variable summounteasttrackingerror    0
  variable summountnorthtrackingerror   0
  variable sumsqmounteasttrackingerror  0
  variable sumsqmountnorthtrackingerror 0
  variable nmounttrackingerror          0

  variable maxmounteasttrackingerror    ""
  variable minmounteasttrackingerror    ""
  variable maxmountnorthtrackingerror   ""
  variable minmountnorthtrackingerror   ""

  variable axismeanhatrackingerror      ""
  variable axismeandeltatrackingerror   ""
  variable mountmeaneasttrackingerror   ""
  variable mountmeannorthtrackingerror  ""
  variable mountrmseasttrackingerror    ""
  variable mountrmsnorthtrackingerror   ""
  variable maxmounteasttrackingerror    ""
  variable minmounteasttrackingerror    ""
  variable maxmountnorthtrackingerror   ""
  variable minmountnorthtrackingerror   ""
  variable mountpveasttrackingerror     ""
  variable mountpvnorthtrackingerror    ""
  
  proc starttrackingstatistics {} {
  
    variable trackingtimestamp

    variable sumaxishatrackingerror
    variable sumaxisdeltatrackingerror
    variable summounteasttrackingerror
    variable summountnorthtrackingerror
    variable sumsqmounteasttrackingerror
    variable sumsqmountnorthtrackingerror
    variable nmounttrackingerror

    set trackingtimestamp [utcclock::combinedformat "now"]

    set sumaxishatrackingerror       0
    set sumaxisdeltatrackingerror    0
    set summounteasttrackingerror    0
    set summountnorthtrackingerror   0
    set sumsqmounteasttrackingerror  0
    set sumsqmountnorthtrackingerror 0
    set nmounttrackingerror          0

  }

  proc updatetrackingstatistics {axishatrackingerror axisdeltatrackingerror mounteasttrackingerror mountnorthtrackingerror} {

    variable sumaxishatrackingerror
    variable sumaxisdeltatrackingerror
    variable summounteasttrackingerror
    variable summountnorthtrackingerror
    variable sumsqmounteasttrackingerror
    variable sumsqmountnorthtrackingerror
    variable nmounttrackingerror

    variable axismeanhatrackingerror
    variable axismeandeltatrackingerror
    variable mountmeaneasttrackingerror
    variable mountmeannorthtrackingerror
    variable mountrmseasttrackingerror
    variable mountrmsnorthtrackingerror
    variable maxmounteasttrackingerror
    variable minmounteasttrackingerror
    variable maxmountnorthtrackingerror
    variable minmountnorthtrackingerror
    variable mountpveasttrackingerror
    variable mountpvnorthtrackingerror

    variable trackingpositionerrorlimit      
    set mounttrackingerror [expr {sqrt(pow($mounteasttrackingerror, 2) + pow($mountnorthtrackingerror, 2))}]
    if {$mounttrackingerror > $trackingpositionerrorlimit} {
      log::info [format \
        "while tracking: mount tracking error is %+.1fas (%+.1fas east and %+.1fas north)." \
        [astrometry::radtoarcsec $mounttrackingerror] \
        [astrometry::radtoarcsec $mounteasttrackingerror] \
        [astrometry::radtoarcsec $mountnorthtrackingerror] \
      ]
    }

    set sumaxishatrackingerror       [expr {$sumaxishatrackingerror       + $axishatrackingerror}]
    set sumaxisdeltatrackingerror    [expr {$sumaxisdeltatrackingerror    + $axisdeltatrackingerror}]
    set summounteasttrackingerror    [expr {$summounteasttrackingerror    + $mounteasttrackingerror}]
    set summountnorthtrackingerror   [expr {$summountnorthtrackingerror   + $mountnorthtrackingerror}]
    set sumsqmounteasttrackingerror  [expr {$sumsqmounteasttrackingerror  + pow($mounteasttrackingerror , 2)}]
    set sumsqmountnorthtrackingerror [expr {$sumsqmountnorthtrackingerror + pow($mountnorthtrackingerror, 2)}]
    set nmounttrackingerror          [expr {$nmounttrackingerror + 1}]

    set axismeanhatrackingerror      [expr {$sumaxishatrackingerror     / $nmounttrackingerror}]
    set axismeandeltatrackingerror   [expr {$sumaxisdeltatrackingerror  / $nmounttrackingerror}]
    set mountmeaneasttrackingerror   [expr {$summounteasttrackingerror  / $nmounttrackingerror}]
    set mountmeannorthtrackingerror  [expr {$summountnorthtrackingerror / $nmounttrackingerror}]
    set mountrmseasttrackingerror    [expr {sqrt(($sumsqmounteasttrackingerror  - $nmounttrackingerror * pow($mountmeaneasttrackingerror , 2)) / $nmounttrackingerror)}]
    set mountrmsnorthtrackingerror   [expr {sqrt(($sumsqmountnorthtrackingerror - $nmounttrackingerror * pow($mountmeannorthtrackingerror, 2)) / $nmounttrackingerror)}]
    if {[string equal $maxmounteasttrackingerror ""]} {
      set maxmounteasttrackingerror  $mounteasttrackingerror
    } else {
      set maxmounteasttrackingerror  [expr {max($maxmounteasttrackingerror,$mounteasttrackingerror)}]
    }
    if {[string equal $minmounteasttrackingerror ""]} {
      set minmounteasttrackingerror  $mounteasttrackingerror
    } else {
      set minmounteasttrackingerror  [expr {min($minmounteasttrackingerror,$mounteasttrackingerror)}]
    }
    if {[string equal $maxmountnorthtrackingerror ""]} {
      set maxmountnorthtrackingerror $mountnorthtrackingerror
    } else {
      set maxmountnorthtrackingerror [expr {max($maxmountnorthtrackingerror,$mountnorthtrackingerror)}]
    }
    if {[string equal $minmountnorthtrackingerror ""]} {
      set minmountnorthtrackingerror $mountnorthtrackingerror
    } else {
      set minmountnorthtrackingerror [expr {min($minmountnorthtrackingerror,$mountnorthtrackingerror)}]
    }
    set mountpveasttrackingerror     [expr {$maxmounteasttrackingerror-$minmounteasttrackingerror}]
    set mountpvnorthtrackingerror    [expr {$maxmountnorthtrackingerror-$minmountnorthtrackingerror}]

    server::setdata "axismeanhatrackingerror"     $axismeanhatrackingerror
    server::setdata "axismeandeltatrackingerror"  $axismeandeltatrackingerror
    server::setdata "mountmeaneasttrackingerror"  $mountmeaneasttrackingerror
    server::setdata "mountmeannorthtrackingerror" $mountmeannorthtrackingerror
    server::setdata "mountrmseasttrackingerror"   $mountrmseasttrackingerror
    server::setdata "mountrmsnorthtrackingerror"  $mountrmsnorthtrackingerror
    server::setdata "mountpveasttrackingerror"    $mountpveasttrackingerror
    server::setdata "mountpvnorthtrackingerror"   $mountpvnorthtrackingerror

  }
  
  proc maybeendtracking {} {

    variable tracking
    variable trackingtimestamp

    variable sumaxishatrackingerror
    variable sumaxisdeltatrackingerror
    variable summounteasttrackingerror
    variable summountnorthtrackingerror
    variable sumsqmounteasttrackingerror
    variable sumsqmountnorthtrackingerror
    variable nmounttrackingerror

    variable axismeanhatrackingerror
    variable axismeandeltatrackingerror
    variable mountmeaneasttrackingerror
    variable mountmeannorthtrackingerror
    variable mountrmseasttrackingerror
    variable mountrmsnorthtrackingerror
    variable maxmounteasttrackingerror
    variable minmounteasttrackingerror
    variable maxmountnorthtrackingerror
    variable minmountnorthtrackingerror
    variable mountpveasttrackingerror
    variable mountpvnorthtrackingerror

    if {$tracking} {
      log::info [format "stopped tracking after %.1f seconds." [utcclock::diff now $trackingtimestamp]]
      if {
        ![string equal $axismeanhatrackingerror ""] &&
        ![string equal $axismeandeltatrackingerror ""]
      } {
        log::info [format \
          "mean axis tracking errors were %+.2fas in HA and %+.2fas in δ." \
          [astrometry::radtoarcsec $axismeanhatrackingerror] \
          [astrometry::radtoarcsec $axismeandeltatrackingerror] \
        ]
      }
      if {
        ![string equal $mountmeaneasttrackingerror ""] &&
        ![string equal $mountmeannorthtrackingerror ""]
      } {
        log::info [format \
          "mean tracking errors were %+.2fas east and %+.2fas north." \
          [astrometry::radtoarcsec $mountmeaneasttrackingerror] \
          [astrometry::radtoarcsec $mountmeannorthtrackingerror] \
        ]
      }
      if {
        ![string equal $mountrmseasttrackingerror ""] &&
        ![string equal $mountrmsnorthtrackingerror ""]
      } {
        log::info [format \
          "RMS tracking errors were %.2fas east and %.2fas north." \
          [astrometry::radtoarcsec $mountrmseasttrackingerror] \
          [astrometry::radtoarcsec $mountrmsnorthtrackingerror] \
        ]
      }
      if {
        ![string equal $mountpveasttrackingerror ""] &&
        ![string equal $mountpvnorthtrackingerror ""]
      } {
        log::info [format \
          "P-V tracking errors were %.2fas east and %.2fas north." \
          [astrometry::radtoarcsec $mountpveasttrackingerror] \
          [astrometry::radtoarcsec $mountpvnorthtrackingerror] \
        ]
      }
    }

    set tracking                     false
    set trackingtimestamp            ""

    set sumaxishatrackingerror       0
    set sumaxisdeltatrackingerror    0
    set summounteasttrackingerror    0
    set summountnorthtrackingerror   0
    set sumsqmounteasttrackingerror  0
    set sumsqmountnorthtrackingerror 0
    set nmounttrackingerror          0

    set axismeanhatrackingerror      ""
    set axismeandeltatrackingerror   ""
    set mountmeaneasttrackingerror   ""
    set mountmeannorthtrackingerror  ""
    set mountrmseasttrackingerror    ""
    set mountrmsnorthtrackingerror   ""
    set maxmounteasttrackingerror    ""
    set minmounteasttrackingerror    ""
    set maxmountnorthtrackingerror   ""
    set minmountnorthtrackingerror   ""
    set mountpveasttrackingerror     ""
    set mountpvnorthtrackingerror    ""

    server::setdata "axismeanhatrackingerror"     $axismeanhatrackingerror
    server::setdata "axismeandeltatrackingerror"  $axismeandeltatrackingerror
    server::setdata "mountmeaneasttrackingerror"  $mountmeaneasttrackingerror
    server::setdata "mountmeannorthtrackingerror" $mountmeannorthtrackingerror
    server::setdata "mountrmseasttrackingerror"   $mountrmseasttrackingerror
    server::setdata "mountrmsnorthtrackingerror"  $mountrmsnorthtrackingerror
    server::setdata "mountpveasttrackingerror"    $mountpveasttrackingerror
    server::setdata "mountpvnorthtrackingerror"   $mountpvnorthtrackingerror

  }
  

  ######################################################################
  
  proc checkaftermoving {{report true}} {
    variable fixedpositionerrorlimit
    set haerror [server::getdata "mounthaerror"]
    set deltaerror [server::getdata "mountdeltaerror"]
    if {$report && abs($haerror) > $fixedpositionerrorlimit} {
      log::warning "mount HA error is [astrometry::radtohms $haerror 2 true] after moving."
    }
    if {$report && abs($deltaerror) > $fixedpositionerrorlimit} {
      log::warning "mount delta error is [astrometry::radtodms $deltaerror 1 true] after moving."
    }
    if {
      (abs($haerror) > $fixedpositionerrorlimit) ||
      (abs($deltaerror) > $fixedpositionerrorlimit)
    } {
      return true
    } else {
      return false
    }
  }

  ######################################################################
  
  proc checkunparked {} {
    if {![server::getdata "unparked"]} {
      error "mount is parked."
    }
  }

  ######################################################################

  proc mountdha {ha delta rotation} {
    variable pointingmodelpolarhole 
    if {0.5 * [astrometry::pi] - abs($delta) <= $pointingmodelpolarhole} {
      set dha 0
    } else {
      set dha [pointing::modeldha [pointingmodelparameters $rotation] $ha $delta]
    }
    return $dha
  }

  proc mountdalpha {alpha delta rotation {seconds "now"}} {
    variable pointingmodelpolarhole 
    if {0.5 * [astrometry::pi] - abs($delta) <= $pointingmodelpolarhole} {
      set dalpha 0
    } else {
      set ha [astrometry::ha $alpha $seconds]
      set dalpha [pointing::modeldalpha  [pointingmodelparameters $rotation] $ha $delta]
    }
    return $dalpha
  }

  proc mountdha {ha delta rotation} {
    variable pointingmodelpolarhole 
    if {0.5 * [astrometry::pi] - abs($delta) <= $pointingmodelpolarhole} {
      set dha 0
    } else {
      set dha [pointing::modeldha [pointingmodelparameters $rotation] $ha $delta]
    }
    return $dha
  }

  proc mountdalpha {alpha delta rotation {seconds "now"}} {
    variable pointingmodelpolarhole 
    if {0.5 * [astrometry::pi] - abs($delta) <= $pointingmodelpolarhole} {
      set dalpha 0
    } else {
      set ha [astrometry::ha $alpha $seconds]
      set dalpha [pointing::modeldalpha  [pointingmodelparameters $rotation] $ha $delta]
    }
    return $dalpha
  }

  proc mountddelta {alpha delta rotation {seconds "now"}} {
    variable pointingmodelpolarhole 
    if {0.5 * [astrometry::pi] - abs($delta) <= $pointingmodelpolarhole} {
      set ddelta 0
    } else {
      set ha [astrometry::ha $alpha $seconds]
      set ddelta [pointing::modelddelta [pointingmodelparameters $rotation] $ha $delta]
    }
    return $ddelta
  }

  proc pointingmodelparameters {rotation} {
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    if {$rotation == 0} {
      return $pointingmodelparameters0
    } else {
      return $pointingmodelparameters180
    }
  }

  proc setpointingmodelparameters {rotation newpointingmodelparameters} {
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    if {$rotation == 0} {
      set pointingmodelparameters0 $newpointingmodelparameters
      config::setvarvalue "mount" "pointingmodelID0" [pointing::getparameter $pointingmodelparameters0 "ID"]
      config::setvarvalue "mount" "pointingmodelIH0" [pointing::getparameter $pointingmodelparameters0 "IH"]
    } else {
      set pointingmodelparameters180 $newpointingmodelparameters
      config::setvarvalue "mount" "pointingmodelID180" [pointing::getparameter $pointingmodelparameters180 "ID"]
      config::setvarvalue "mount" "pointingmodelIH180" [pointing::getparameter $pointingmodelparameters180 "IH"]
    }
  }

  proc updatepointingmodel {dIH dID rotation} {
    setpointingmodelparameters $rotation [pointing::updateabsolutemodel [pointingmodelparameters $rotation] $dIH $dID]
  }
  
  proc setMAtozero {} {
    log::info "setting MA to zero in the pointing model parameters."
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    set pointingmodelparameters0   [pointing::setparameter $pointingmodelparameters0   MA 0]
    set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 MA 0]
    log::info "the pointing model parameters for mount rotation 0 are: $pointingmodelparameters0:"
    log::info "the pointing model parameters for mount rotation 180 are: $pointingmodelparameters180:"
  }

  proc setMEtozero {} {
    log::info "setting ME to zero in the pointing model parameters."
    variable pointingmodelparameters0
    variable pointingmodelparameters180
    set pointingmodelparameters0   [pointing::setparameter $pointingmodelparameters0   ME 0]
    set pointingmodelparameters180 [pointing::setparameter $pointingmodelparameters180 ME 0]
    log::info "the pointing model parameters for mount rotation 0 are: $pointingmodelparameters0:"
    log::info "the pointing model parameters for mount rotation 180 are: $pointingmodelparameters180:"
  }

  ######################################################################

  proc checklimits {} {

    set activity [server::getactivity]
    if {
      ![string equal $activity "moving"  ] &&
      ![string equal $activity "tracking"]
    } {
      return
    }

    variable easthalimit
    variable westhalimit
    variable meridianhalimit
    variable polardeltalimit
    variable southdeltalimit
    variable northdeltalimit
    variable minzenithdistancelimit
    variable maxzenithdistancelimit
    
    set mountha       [server::getdata "mountha"]
    set mountdelta    [server::getdata "mountdelta"]
    set mountrotation [server::getdata "mountrotation"]

    set mountzenithdistance [astrometry::equatorialtozenithdistance $mountha $mountdelta]
    
    set withintargetlimits [client::getdata "target" "withinlimits"]
    
    if {![string equal $easthalimit ""] && $mountha < $easthalimit && $mountdelta < $polardeltalimit} {
      log::warning "HA exceeds eastern limit."
      set withinmountlimits false
    } elseif {![string equal $westhalimit ""] && $mountha > $westhalimit && $mountdelta < $polardeltalimit} {
      log::warning "HA exceeds western limit."
      set withinmountlimits false
    } elseif {![string equal $southdeltalimit ""] && $mountdelta < $southdeltalimit} {
      log::warning "δ exceeds southern limit."
      set withinmountlimits false
    } elseif {![string equal $northdeltalimit ""] && $mountdelta > $northdeltalimit} {
      log::warning "δ exceeds northern limit."
      set withinmountlimits false
    } elseif {![string equal $minzenithdistancelimit ""] && $mountzenithdistance < $minzenithdistancelimit} {
      log::warning "zenith distance exceeds minimum limit."
      set withinmountlimits false
    } elseif {![string equal $maxzenithdistancelimit ""] && $mountzenithdistance > $maxzenithdistancelimit} {
      log::warning "zenith distance exceeds maximum limit."
      set withinmountlimits false
    } elseif {![string equal $meridianhalimit ""] && $mountrotation == 0 && $mountha <= -$meridianhalimit && $mountdelta < $polardeltalimit} {
      log::warning "HA exceeds eastern meridian limit."
      set withinmountlimits false
    } elseif {![string equal $meridianhalimit ""] && $mountrotation != 0 && $mountha >= +$meridianhalimit && $mountdelta < $polardeltalimit} {
      log::warning "HA exceeds western meridian limit."
      set withinmountlimits false
    } else {
      set withinmountlimits true
    }
    
    if {!$withinmountlimits} {
      log::warning "mount is moving and not within the limits."
    } elseif {[string equal $activity "tracking"] && !$withintargetlimits} {
      log::warning "tracking and target is not within the limits."
    } else {
      return
    }    

    log::warning "mount position is [astrometry::formatha $mountha] [astrometry::formatdelta $mountdelta]."
    log::warning "mount zenith distance is [astrometry::formatzenithdistance $mountzenithdistance]."
    log::warning [format "mount rotation is %.0f°." [astrometry::radtodeg $mountrotation]]

    log::warning "starting emergency stop."
    emergencystophardware

    server::setdata "mounttracking" false

    server::erroractivity

  }

  ######################################################################


  proc initialize {} {
    server::checkstatus
    server::checkactivityforinitialize
    checkhardware "initialize"
    server::newactivitycommand "initializing" "idle" mount::initializeactivitycommand 1200000
  }

  proc open {} {
    server::checkstatus
    server::checkactivityformove
    checkhardware "open"
    server::newactivitycommand "opening" "idle" mount::openactivitycommand 1200000
  }

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    checkhardware "stop"
    server::newactivitycommand "stopping" [server::getstoppedactivity] mount::stopactivitycommand
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    checkhardware "reset"
    server::newactivitycommand "resetting" [server::getstoppedactivity] mount::resetactivitycommand
  }

  proc preparetomove {} {
    server::checkstatus
    server::checkactivityformove
    checkhardware "preparetomove"
    server::newactivitycommand "preparingtomove" "preparedtomove" mount::preparetomoveactivitycommand
  }

  proc move {} {
    server::checkstatus
    server::checkactivity "preparedtomove"
    checkunparked
    checkhardware "move"
    if {[catch {client::checkactivity "target" "idle"} message]} {
      stop
      error "move cancelled because $message"
    }
    server::newactivitycommand "moving" "idle" mount::moveactivitycommand
  }

  proc park {} {
    server::checkstatus
    server::checkactivity "preparedtomove"
    checkhardware "park"
    if {[catch {client::checkactivity "target" "idle"} message]} {
      stop
      error "parking cancelled because $message"
    }
    server::newactivitycommand "parking" "idle" mount::parkactivitycommand
  }

  proc unpark {} {
    server::checkstatus
    server::checkactivity "preparedtomove"
    checkhardware "unpark"
    if {[catch {client::checkactivity "target" "idle"} message]} {
      stop
      error "unparking cancelled because $message"
    }
    server::newactivitycommand "unparking" "idle" mount::unparkactivitycommand
  }

  proc preparetotrack {} {
    server::checkstatus
    server::checkactivityformove
    checkunparked
    checkhardware "preparetotrack"
    server::newactivitycommand "preparingtotrack" "preparedtotrack" mount::preparetotrackactivitycommand
  }

  proc track {} {
    server::checkstatus
    server::checkactivity "preparedtotrack"
    checkunparked
    checkhardware "track"
    if {[catch {client::checkactivity "target" "tracking"} message]} {
      stop
      error "move cancelled because $message"
    }
    server::newactivitycommand "moving" "tracking" mount::trackactivitycommand
  }

  proc offset {} {
    server::checkstatus
    server::checkactivity "preparedtotrack"
    checkunparked
    checkhardware "offset"
    if {[catch {client::checkactivity "target" "tracking"} message]} {
      stop
      error "move cancelled because $message"
    }
    server::newactivitycommand "offsetting" "tracking" mount::offsetactivitycommand
  }

  proc correct {truemountalpha truemountdelta equinox} {

    set start [utcclock::seconds]

    server::checkstatus
    server::checkactivity "tracking"
    checkunparked
    checkhardware "correct"

    set truemountalpha [astrometry::parsealpha $truemountalpha]
    set truemountdelta [astrometry::parsealpha $truemountdelta]
    set equinox [astrometry::parseequinox $equinox]
    log::info "true position is [astrometry::formatalpha $truemountalpha] [astrometry::formatdelta $truemountdelta] $equinox"

    set truemountobservedalpha [astrometry::observedalpha $truemountalpha $truemountdelta $equinox]
    set truemountobserveddelta [astrometry::observeddelta $truemountalpha $truemountdelta $equinox]    
    log::info "true mount observed position is [astrometry::formatalpha $truemountobservedalpha] [astrometry::formatdelta $truemountobserveddelta]."

    set requestedobservedalpha [server::getdata "requestedobservedalpha"]
    set requestedobserveddelta [server::getdata "requestedobserveddelta"]
    log::info "requested mount observed position is [astrometry::formatalpha $requestedobservedalpha] [astrometry::formatdelta $requestedobserveddelta]."

    set mountalphaerror [server::getdata "mountalphaerror"]
    set mountdeltaerror [server::getdata "mountdeltaerror"]
    set mountobservedalpha [astrometry::foldradpositive  [expr {$requestedobservedalpha + $mountalphaerror}]]
    set mountobserveddelta [astrometry::foldradsymmetric [expr {$requestedobserveddelta + $mountdeltaerror}]]
    log::info "mount observed position is [astrometry::formatalpha $mountobservedalpha] [astrometry::formatdelta $mountobserveddelta]."

    set d [astrometry::distance $mountobservedalpha $mountobserveddelta $truemountobservedalpha $truemountobserveddelta]
    log::info [format "correction is %s." [astrometry::formatdistance $d]]

    set dalpha [astrometry::foldradsymmetric [expr {$mountobservedalpha - $truemountobservedalpha}]]
    set ddelta [astrometry::foldradsymmetric [expr {$mountobserveddelta - $truemountobserveddelta}]]
    set alphaoffset [expr {$dalpha * cos($truemountobserveddelta)}]
    set deltaoffset $ddelta
    log::info [format "correction is %s E and %s N." [astrometry::formatoffset $alphaoffset] [astrometry::formatoffset $deltaoffset]]

    variable maxcorrection
    if {$d >= $maxcorrection} {
      log::warning [format "ignoring correction: the correction distance of %s is larger than the maximum allowed of %s." [astrometry::formatdistance $d] [astrometry::formatdistance $maxcorrection]]
    } else {
      server::setdata "lastcorrectiontimestamp" [utcclock::format]
      server::setdata "lastcorrectiondalpha"    $dalpha
      server::setdata "lastcorrectionddelta"    $ddelta
      set dha [expr {-($dalpha)}]
      updatepointingmodel $dha $ddelta [server::getdata "mountrotation"]
      updaterequestedpositiondata
      set requestedobservedalpha [server::getdata "requestedobservedalpha"]
      set requestedobserveddelta [server::getdata "requestedobserveddelta"]
      log::info "requested mount observed position is [astrometry::formatalpha $requestedobservedalpha] [astrometry::formatdelta $requestedobserveddelta]."  
    }

    log::info [format "finished correcting after %.1f seconds." [utcclock::diff now $start]]

    return
  }

  ######################################################################

}
