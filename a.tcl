  proc updaterequestedpositiondata {{updaterequestedrotation false}} {
  
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
      
      if {$updaterequestedrotation} {
        set requestedmountrotation [mountrotation $requestedobservedha $requestedobservedalpha]
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

      if {$updaterequestedrotation} {
        set requestedmountrotation [mountrotation $requestedobservedha $requestedobservedalpha]
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
