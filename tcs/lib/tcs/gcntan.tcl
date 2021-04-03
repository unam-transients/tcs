########################################################################

# This file is part of the RATTEL telescope control system.

# $Id: gcntan.tcl 3601 2020-06-11 03:20:53Z Alan $

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

package require "astrometry"
package require "project"
package require "server"

package provide "gcntan" 0.0

namespace eval "gcntan" {

  variable svnid {$Id}

  ######################################################################  

  variable packetport [config::getvalue "gcntan" "serverpacketport"]
  
  # We should get an imalive packet every 60 seconds.
  variable packettimeout 300000
  
  variable swiftalertprojectidentifier [config::getvalue "gcntan" "swiftalertprojectidentifier"]
  variable fermialertprojectidentifier [config::getvalue "gcntan" "fermialertprojectidentifier"]
  variable lvcalertprojectidentifier   [config::getvalue "gcntan" "lvcalertprojectidentifier"  ]

  ######################################################################

  server::setdata "swiftalpha"   ""
  server::setdata "swiftdelta"   ""
  server::setdata "swiftequinox" ""
  
  ######################################################################
  
  # GCN/TAN packets are defined in: http://gcn.gsfc.nasa.gov/sock_pkt_def_doc.html

  # Symbolic names used here are the names in the GCN/TAN document
  # converted to lower case and with underbars elided.
  
  # Packets are 40 packed 32-bit two's complement integers.
  variable packetlength 160
  variable packetformat I40

  proc readloop {channel} {

    variable packetlength
    variable packetformat
    variable packettimeout
  
    chan configure $channel -translation "binary"
    chan configure $channel -blocking false

    while {true} {
        
      set rawpacket [coroutine::read $channel $packetlength $packettimeout]
        
      set timestamp [utcclock::combinedformat]

      if {[string length $rawpacket] != $packetlength} {
        log::error "packet length is [string length $rawpacket]."
        break
      }
    
      server::setdata "timestamp" $timestamp
      server::setactivity [server::getrequestedactivity]
      server::setstatus "ok"
        
      binary scan $rawpacket $packetformat packet
      
      switch [processpacket $timestamp $packet] {
        "echo" {
          echorawpacket $channel $rawpacket
        }
        "close" {
          break
        }
      }

    }
    
    catch {close $channel}

  } 

  proc processpacket {timestamp packet} {

    log::debug [format "packet is %s." $packet]
    set type [type $packet]
    log::debug [format "packet type is \"%s\"." $type]

    switch $type {

      "unknown" {
        # Do not echo back a bad packet.
        log::warning [format "unknown packet type: \"%s\"." [field0 $packet 0]]
        return "bad"
      }

      "imalive" {
        log::info [format "received %s packet." $type]
        return "echo"
      }

      "kill" {
        log::info [format "received %s packet." $type]
        # Close connection without echoing the packet.
        return "close"
      }

      "swiftactualpointdir" {
        log::info [format "received %s packet." $type]
        set alpha       [swiftalpha   $packet]
        set delta       [swiftdelta   $packet]
        set equinox     [swiftequinox $packet]
        server::setdata "swiftalpha"   $alpha
        server::setdata "swiftdelta"   $delta
        server::setdata "swiftequinox" $equinox
        log::info [format "%s: position is %s %s %s." $type [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox]            
        return "echo"
      }
       
      "swiftbatgrbpostest" -
      "swiftbatquicklookposition" - 
      "swiftbatgrbposition" -
      "swiftxrtposition" - 
      "swiftuvotposition" {
        log::info [format "received %s packet." $type]
        variable swiftalertprojectidentifier
        set projectidentifier  $swiftalertprojectidentifier
        set blockidentifier    [swifttrigger         $packet]
        set name               [swiftgrbname         $packet]
        set origin             "swift"
        set identifier         [swifttrigger         $packet]
        set test               [swifttest            $packet]
        set eventtimestamp     [swifteventtimestamp  $packet]
        set alpha              [swiftalpha           $packet]
        set delta              [swiftdelta           $packet]
        set equinox            [swiftequinox         $packet]
        set uncertainty        [swiftuncertainty     $packet]
        set grb                [swiftgrb             $packet]
        set retraction         [swiftretraction      $packet]
        respondtogrbalert $test $projectidentifier $blockidentifier $name $origin $identifier $type $timestamp $eventtimestamp $retraction $grb $alpha $delta $equinox $uncertainty
        return "echo"
      }

      "fermigbmfltpos" -
      "fermigbmgndpos" -
      "fermigbmfinpos" -
      "fermigbmpostest" {
        log::info [format "received %s packet." $type]
        variable fermialertprojectidentifier
        set projectidentifier  $fermialertprojectidentifier
        set blockidentifier    [fermitrigger         $packet]
        set name               [fermigrbname         $packet]
        set origin             "fermi"
        set identifier         [fermitrigger         $packet]
        set test               [fermitest            $packet]
        set eventtimestamp     [fermieventtimestamp  $packet]
        set alpha              [fermialpha           $packet]
        set delta              [fermidelta           $packet]
        set equinox            [fermiequinox         $packet]
        set uncertainty        [fermigbmuncertainty  $packet]
        set grb                [fermigrb             $packet]
        set retraction         [fermiretraction      $packet]
        respondtogrbalert $test $projectidentifier $blockidentifier $name $origin $identifier $type $timestamp $eventtimestamp $retraction $grb $alpha $delta $equinox $uncertainty
        return "echo"
      }
       
      "fermilatgrbpostest" -
      "fermilatgrbposupd" -
      "fermilatgnd" -
      "fermilatoffline" {
        log::info [format "received %s packet." $type]
        variable fermialertprojectidentifier
        set projectidentifier  $fermialertprojectidentifier
        set blockidentifier    [fermitrigger         $packet]
        set name               [fermigrbname         $packet]
        set origin             "fermi"
        set eventidentifier    [fermitrigger         $packet]
        set test               [fermitest            $packet]
        set eventtimestamp     [fermieventtimestamp  $packet]
        set alpha              [fermialpha           $packet]
        set delta              [fermidelta           $packet]
        set equinox            [fermiequinox         $packet]
        set uncertainty        [fermilatuncertainty  $packet]
        set grb                [fermigrb             $packet]
        set retraction         [fermiretraction      $packet]
        respondtogrbalert $test $projectidentifier $blockidentifier $name $origin $identifier $type $timestamp $eventtimestamp $retraction $grb $alpha $delta $equinox $uncertainty
        return "echo"
      }

      "lvcpreliminary" -
      "lvcinitial" -
      "lvcupdate" {
        log::info [format "received %s packet." $type]
        return "echo"
        variable lvcalertprojectidentifier
        set projectidentifier  $lvcalertprojectidentifier
        set blockidentifier    [lvctrigger         $packet]
        set name               [lvcname            $packet]
        set origin             "lvc"
        set identifier         [lvcidentifier      $packet]
        set eventtimestamp     [lvceventtimestamp  $packet]
        set test               [lvctest            $packet]
        set skymapurl          [lvcurl             $packet]
        respondtolvcalert $test $projectidentifier $blockidentifier $name $origin $identifier $type $timestamp $eventtimestamp false $skymapurl
        return "echo"
      }

      "lvcretraction" {
        log::info [format "received %s packet." $type]
        return "echo"
        variable lvcalertprojectidentifier
        set projectidentifier  $lvcalertprojectidentifier
        set blockidentifier    [lvctrigger          $packet]
        set name               [lvcname             $packet]
        set origin             "lvc"
        set identifier         [lvcidentifier       $packet]
        set eventtimestamp     [lvceventtimestamp   $packet]
        set test               [lvctest             $packet]
        respondtolvcalert $test $projectidentifier $blockidentifier $name $origin $identifier $type $timestamp $eventtimestamp true ""
        return "echo"
      }
       
      "lvccounterpart" {
        log::info [format "received %s packet." $type]
        return "echo"
        variable lvcalertprojectidentifier
        set projectidentifier  $lvcalertprojectidentifier
        set blockidentifier    [lvctrigger          $packet]
        set name               [lvcname             $packet]
        set origin             "lvc"
        set identifier         [lvcidentifier       $packet]
        set eventtimestamp     [lvceventtimestamp   $packet]
        set test               [lvctest             $packet]
        log::info [format "%s: test is %s." $type $test]
        log::info [format "%s: project identifier is \"%s\"." $type $projectidentifier]
        log::info [format "%s: block identifier is %s." $type $blockidentifier ]
        log::info [format "%s: name is %s." $type $name]
        log::info [format "%s: origin/identifier/type are %s." $type $origin $identifier $type]
        log::info [format "%s: event timestamp is %s." $type $eventtimestamp]
        return "echo"
      }
       
      default {
        log::info [format "received %s packet." $type]
        return "echo"
      }

    }

  }
  
  proc echorawpacket {channel rawpacket} {
    log::debug "echoing packet."
    puts -nonewline $channel $rawpacket
    flush $channel
  }
  
  ######################################################################
  
  proc logresponse {test message} {
    if {$test} {
      log::debug "test: $message"
    } else {
      log::summary $message
    }
  }
  
  proc respondtogrbalert {test projectidentifier blockidentifier name origin identifier type alerttimestamp eventtimestamp retraction grb alpha delta equinox uncertainty} {
    logresponse $test [format "%s: test is %s." $type $test]
    logresponse $test [format "%s: project identifier is %d." $type $projectidentifier]
    logresponse $test [format "%s: block identifier is %d." $type $blockidentifier]
    logresponse $test [format "%s: name is %s." $type $name]
    logresponse $test [format "%s: origin/identifier/type are %s." $type $origin $identifier $type]
    logresponse $test [format "%s: alert timestamp is %s." $type [utcclock::format $alerttimestamp]] 
    if {![string equal $eventtimestamp ""]} {
      logresponse $test [format "%s: event timestamp is %s." $type [utcclock::format $eventtimestamp]]
      logresponse $test [format "%s: event delay is %s." $type [utcclock::formatinterval [utcclock::diff $alerttimestamp $eventtimestamp]]]
    } else {
      logresponse $test [format "%s: no event timestamp." $type]
    }
    logresponse $test [format "%s: position is %s %s %s." $type [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox]
    logresponse $test [format "%s: uncertainty is %s." $type [astrometry::formatdistance $uncertainty]]
    set enabled ""
    if {![string equal $grb ""]} {
      if {$grb} {
        logresponse $test [format "%s: this is a GRB." $type]
        set enabled true
      } else {
        logresponse $test [format "%s: this is not a GRB." $type]
        set enabled false
      }
    }
    if {![string equal $retraction ""] && $retraction} {
      logresponse $test [format "%s: this is a retraction." $type]
      set enabled false
    }
    if {$test} {
      logresponse $test [format "%s: not requesting scheduler to respond: this is a test packet." $type]
    } elseif {[string equal $projectidentifier ""]} {
      logresponse $test [format "%s: not requesting scheduler to respond: no project identifier." $type]
    } else {
      logresponse $test [format "%s: requesting scheduler to respond." $type]
      if {[catch {
        client::request "scheduler" [list respondtoalert $projectidentifier $blockidentifier $name $origin $identifier $type $alerttimestamp $eventtimestamp $enabled $alpha $delta $equinox $uncertainty]
      } result]} {
        log::warning [format "%s: unable to request scheduler: %s" $type $result]
      }
    }
  }
  
  proc respondtolvcalert {test projectidentifier blockidentifier name origin identifier type alerttimestamp eventtimestamp retraction skymapurl} {
    logresponse $test [format "%s: test is %s." $type $test]
    logresponse $test [format "%s: project identifier is \"%s\"." $type $projectidentifier]
    logresponse $test [format "%s: block identifier is %d." $type $blockidentifier]
    logresponse $test [format "%s: name is %s." $type $name]
    logresponse $test [format "%s: origin/identifier/type are %s." $type $origin $identifier $type]
    logresponse $test [format "%s: alert timestamp is %s." $type [utcclock::format $alerttimestamp]] 
    logresponse $test [format "%s: event timestamp is %s." $type [utcclock::format $eventtimestamp]]
    logresponse $test [format "%s: event delay is %s." $type [utcclock::formatinterval [utcclock::diff $alerttimestamp $eventtimestamp]]]
    if {![string equal $skymapurl ""]} {
      logresponse $test [format "%s: skymap url is %s." $type $skymapurl]
    }
    if {![string equal $retraction ""] && $retraction} {
      logresponse $test [format "%s: this is a retraction." $type]
      set enabled false
    } else {
      set enabled true
    }
    if {$test} {
      logresponse $test [format "%s: not requesting scheduler to respond: this is a test packet." $type]
    } elseif {[string equal $projectidentifier ""]} {
      logresponse $test [format "%s: not requesting scheduler to respond: no project identifier." $type]
    } else {
      logresponse $test [format "%s: requesting scheduler to respond." $type]
      if {[catch {
        client::request "scheduler" [list respondtolvcalert $projectidentifier $blockidentifier $name $origin $identifier $type $alerttimestamp $eventtimestamp $enabled $skymapurl]
      } result]} {
        log::warning [format "%s: unable to request scheduler: %s" $type $result]
      }
    }
  }
  
  ######################################################################

  # These procedures are designed to work with the following packet types:
  #
  #   swiftbatgrbpostest
  #   swiftbatquicklookposition
  #   swiftbatgrbposition
  #   swiftxrtposition
  #   swiftuvotposition
  
  proc swifttest {packet} {
    switch [type $packet] {
      "swiftbatgrbpostest" {
        return true
      }
      "swiftbatquicklookposition" -
      "swiftbatgrbposition" -
      "swiftxrtposition" -
      "swiftuvotposition" {
        return false
      }
      default {
        error "unexpected packet type \"$packet\"."
      }
    }
  }

  proc swifttrigger {packet} {
    return [expr {[field0 $packet 4] & 0xffffff}]
  }
  
  proc swiftgrbname {packet} {
    set timestamp [swifteventtimestamp $packet]
    if {[string equal $timestamp ""]} {
      return ""
    }
    if {[scan $timestamp "%d-%d-%dT%d:%d:%f" year month day hours minutes seconds] != 6} {
      error "unable to scan timestamp \"$timestamp\"."
    }
    set dayfraction [expr {($hours + $minutes / 60.0 + $seconds / 3600.0) / 24.0}]
    set identifier [format "Swift GRB %02d%02d%02d.%03d" [expr {$year % 100}] $month $day [expr {int($dayfraction * 1000)}]]
    return $identifier
  }

  proc swifteventtimestamp {packet} {
    switch [type $packet] {
      "swiftbatquicklookposition" -
      "swiftbatgrbposition" -
      "swiftbatgrbpostest" {
        return [utcclock::combinedformat [seconds $packet 5]]
      }
      "swiftxrtposition" -
      "swiftuvotposition" {
        return ""
      }
      default {
        error "unexpected packet type \"$packet\"."
      }
    }
  }
  
  proc swiftalpha {packet} {
    return [astrometry::foldradpositive [astrometry::degtorad [field4 $packet 7]]]
  }
  
  proc swiftdelta {packet} {
    return [astrometry::degtorad [field4 $packet 8]]
  }
  
  proc swiftequinox {packet} {
    return 2000
  }
  
  proc swiftuncertainty {packet} {
    # BAT, XRT, and UVOT give 90% radius
    set uncertainty [astrometry::degtorad [field4 $packet 11]]
    return [format "%.1fas" [astrometry::radtoarcsec $uncertainty]]
  }

  proc swiftgrb {packet} {
    switch [type $packet] {
      "swiftbatgrbposition" -
      "swiftbatgrbpostest" {
        if {([field0 $packet 18] >> 1) & 1} {
          return true
        } else {
          return false
        }
      }
      "swiftbatquicklookposition" -
      "swiftxrtposition" -
      "swiftuvotposition" {
        return ""
      }
      default {
        error "unexpected packet type \"$packet\"."
      }
    }
  }
  
  proc swiftretraction {packet} {
    switch [type $packet] {
      "swiftbatquicklookposition" {
        return ""
      }
      "swiftbatgrbpostest" -
      "swiftbatgrbposition" -
      "swiftxrtposition" -
      "swiftuvotposition" {
        if {([field0 $packet 18] >> 5) & 1} {
          return true
        } else {
          return false
        }
      }
      default {
        error "unexpected packet type \"$packet\"."
      }
    }
  }

######################################################################

  # These procedures are designed to work with the following packet types:
  #
  #  fermilatgrbpostest
  #  fermilatgrbposupd
  #  fermilatgnd
  #  fermilatoffline

  proc fermitest {packet} {
    switch [type $packet] {
      "fermigbmpostest" -
      "fermilatgrbpostest" {
        return true
      }
      "fermigbmfltpos" -
      "fermigbmgndpos" -
      "fermigbmfinpos" -
      "fermilatgrbposupd" - 
      "fermilatgnd" - 
      "fermilatoffline" {
        return false
      }
      default {
        error "unexpected packet type \"$packet\"."
      }
    }
  }

  proc fermitrigger {packet} {
    return [field0 $packet 4]
  }

  proc fermigrbname {packet} {
    set timestamp [fermieventtimestamp $packet]
    if {[string equal $timestamp ""]} {
      return ""
    }
    if {[scan $timestamp "%d-%d-%dT%d:%d:%f" year month day hours minutes seconds] != 6} {
      error "unable to scan timestamp \"$timestamp\"."
    }
    switch -glob [type $packet] {
      "fermigbm*" {
        set dayfractioninthousandths [field0 $packet 32]
        set identifier [format "Fermi GRB %02d%02d%02d.%03d" [expr {$year % 100}] $month $day $dayfractioninthousandths]
      }
      "fermilat*" {
        set dayfraction [expr {($hours + $minutes / 60.0 + $seconds / 3600.0) / 24.0}]
        set identifier [format "Fermi GRB %02d%02d%02d.%03d" [expr {$year % 100}] $month $day [expr {int($dayfraction * 1000)}]]
      }
    }
    return $identifier
  }

  proc fermieventtimestamp {packet} {
    return [utcclock::combinedformat [seconds $packet 5]]
  }
  
  proc fermialpha {packet} {
    return [astrometry::foldradpositive [astrometry::degtorad [field4 $packet 7]]]
  }
  
  proc fermidelta {packet} {
    return [astrometry::degtorad [field4 $packet 8]]
  }

  proc fermiequinox {packet} {
    return 2000
  }
  
proc r {s P} {

  # LGRBs from Table 5 of the RoboBA paper.
  set F 0.579
  set C 1.86
  set T 4.41
    
  # SGRBs from Table 5 of the RoboBA paper.
  set F 0.39
  set C 2.55
  set T 4.42

  # Convert from "radius containing 68% of the probability", which is the sigma of the GBM team, to an actual sigma for a distribution with p(r) = A exp(-0.5*(r/sigma)^2).
  set s [expr {$s / sqrt(-2 * log(1-0.68))}]
  set C [expr {$C / sqrt(-2 * log(1-0.68))}]
  set T [expr {$T / sqrt(-2 * log(1-0.68))}]

  # Add systematic and statistical uncertainties in quadrature.
  set c [expr {sqrt($s * $s + $C * $C)}]
  set t [expr {sqrt($s * $s + $T * $T)}]

  # Find radius containing P.
  set r 0
  while {true} {
    set p [expr {$F * (1 - exp(-0.5*($r*$r)/($c*$c))) + (1-$F) * (1 - exp(-0.5*($r*$r)/($t*$t)))}]
    if {$p > $P} {
      break
    }
    set r [expr {$r + 0.01}]
  }

  return $r
}
  

  proc fermigbmuncertainty {packet} {

    set type [type $packet]

    # We work in degrees here.

    set rawuncertainty [field4 $packet 11]
    log::info [format "%s: raw uncertainty is %.1fd." $type $rawuncertainty]  
    
    # We want the radius containing 90% of the probability. There are
    # two complications here.
    # 
    # First, the GCN notices distribute a sigma defined to be the
    # "radius containing 68% of the probability" (see the start of
    # section 5 of Connaughton et al. 2015), which is not the standard
    # sigma in a 2-D Gaussian with p(x,y) = A exp(-0.5*(r/sigma)^2).
    # 
    # Second, we need to add the systematic probability. The core and
    # tail are both Gaussians and a certain fraction of the probability
    # is in the core. The parameters are given in Table 3 of Goldstein
    # et al. (submitted). They are different for long and short GRBs,
    # but we use the global values. This could be improved based on the
    # classification in the GCN notice.
    
    set F 0.517
    set C 1.81
    set T 4.07
    
    set s $rawuncertainty
    
    # Convert from "radius containing 68% of the probability" to a true sigma.
    set s [expr {$s / sqrt(-2 * log(1-0.68))}]
    set C [expr {$C / sqrt(-2 * log(1-0.68))}]
    set T [expr {$T / sqrt(-2 * log(1-0.68))}]

    # Add systematic and statistical uncertainties in quadrature.
    set c [expr {sqrt($s * $s + $C * $C)}]
    set t [expr {sqrt($s * $s + $T * $T)}]

    # Find radius containing 90% of the probability.
    set P 0.9
    set r 0
    set dr 0.01
    while {true} {
      set p [expr {$F * (1 - exp(-0.5*($r*$r)/($c*$c))) + (1 - $F) * (1 - exp(-0.5*($r*$r)/($t*$t)))}]
      if {$p > $P} {
        break
      }
      set r [expr {$r + $dr}]
    }

    set uncertainty $r

    log::info [format "%s: uncertainty is %.1fd." $type $uncertainty]  

    return [format "%.1fd" $uncertainty]
  }
  
  proc fermilatuncertainty {packet} {
    # LAT gives 90% radius.
    set uncertainty [astrometry::degtorad [field4 $packet 11]]
    return [format "%.1fam" [astrometry::radtoarcmin $uncertainty]]
  }
  
  proc fermiretraction {packet} {
    if {([field0 $packet 18] >> 5) & 1} {
      return true
    } else {
      return false
    }
  }
  
  proc fermigrb {packet} {
    set type [type $packet]
    switch [type $packet] {
      "fermigbmpostest" -
      "fermigbmfltpos" {
        set sigma [fermigbmtriggersigma $packet]
        log::info [format "%s: %.1f sigma." $type $sigma]
        set class            [fermigbmclass $packet 23]
        set classprobability [fermigbmclassprobability $packet 23]
        log::info [format "%s: class is \"%s\" (%.0f%%)." $type $class [expr {$classprobability * 100}]]
        if {[string equal $class "grb"]} {
          return true
        } else {
          return false
        }
      }
      "fermigbmgndpos" {
        set sigma [fermigbmtriggersigma $packet]
        log::info [format "%s: trigger sigma is %.1f." $type $sigma]
        if {[fermiretraction $packet]} {
          return false
        } else {
          log::info [format "%s: the duration is %s." $type [fermigbmgrbduration $packet]]          
          return true
        }
      }
      "fermigbmfinpos" {
        if {[fermiretraction $packet]} {
          return false
        } else {
          log::info [format "%s: the duration is %s." $type [fermigbmgrbduration $packet]]          
          return true
        }
      }
      "fermilatgrbposupd" -
      "fermilatgrbpostest" {
        set temporalsignificance [field0 $packet 25]
        set imagesignificance    [field0 $packet 26]
        set totalsignificance    [expr {$temporalsignificance + $imagesignificance}]
        log::info [format "%s: temporal significance is %d." $type $temporalsignificance]
        log::info [format "%s: image significance is %d."    $type $imagesignificance]
        log::info [format "%s: total significance is %d."    $type $totalsignificance]
        if {$totalsignificance >= 120} {
          return true
        } else {
          return false
        }
      }
      "fermilatgnd" {
        # fermilatgnd packets a field that gives the sqrt of the trigger
        # significance. I am confused by this. So, for the time being, I
        # am logging it but treating all as GRBs.
        set significance [field2 $packet 26]
        log::info [format "%s: significance is %.2f." $type $significance]
        return true
      }
      "fermilatoffline" {
        return true
      }
      default {
        error "fermigrb: unexpected packet type \"$packet\"."
      }
    }
  }

  variable fermigbmclassdict {
    0 "error"
    1 "unreliablelocation"
    2 "localparticles"
    3 "belowhorizon"
    4 "grb"
    5 "genericsgr"
    6 "generictransient"
    7 "distantparticles"
    8 "solarflare"
    9 "cygx1"
    10 "sgr180620"
    11 "groj042232"
    19 "tgf"
  }
  
  proc fermigbmclass {packet i} {
    set i [expr {[field0 $packet $i] & 0xffff}]
    variable fermigbmclassdict
    if {[dict exists $fermigbmclassdict $i]} {
      return [dict get $fermigbmclassdict $i]
    } else {
      return "unknown"
    } 
  }
  
  proc fermigbmclassprobability {packet i} {
    return [expr {(([field0 $packet $i] >> 16) & 0xffff) / 256.0}]
  }
  
  proc fermigbmtriggersigma {packet} {
    set type [type $packet]
    switch [type $packet] {
      "fermigbmpostest" -
      "fermigbmfltpos" {
        return [field2 $packet 21]
      }
      "fermigbmgndpos" {
        return [field1 $packet 21]
      }
      default {
        error "fermigbmtriggersigma: unexpected packet type \"$packet\"."
      }
    }
  }
  
  proc fermigbmgrbduration {packet} {
    set ls [expr {([field0 $packet 18] >> 26) & 0x3}]
    switch $ls {
    0 {
      return "uncertain" 
    }
    1 { 
      return "short" 
    }
    2 {
      return "long" 
    }
    3 { 
      log::warning "invalid value in l-v-s field."
      return "uncertain"
    }
    }
  }

######################################################################

  proc lvcidentifier {packet} {

    set date [field0 $packet 4]            

    set prefixcode [expr {([field0 $packet 19] >> 20) & 0xf}]
    switch [directories::prefix]code {
      1  { set prefix "G" }
      2  { set prefix "T" }
      3  { set prefix "M" }
      4  { set prefix "Y" }
      5  { set prefix "H" }
      6  { set prefix "E" }
      7  { set prefix "K" }
      8  { set prefix "S" }
      9  { set prefix "GW" }
      10 { set prefix "TS" }
      11 { set prefix "TGW" }
      12 { set prefix "MS"  }
      13 { set prefix "MGW" }
      default {
        log::warning "unknown lvc prefix code [directories::prefix]code."
        set prefix ""
      }
    }

    set suffix0 [format "%c" [expr {([field0 $packet 19] >> 10) & 0xff}]]
    set suffix1 [format "%c" [expr {([field0 $packet 21] >>  0) & 0xff}]]          

    return [string trimright "${prefix}${date}${suffix0}${suffix1}"]
  }

  proc lvctest {packet} {
    set identifier [lvcidentifier $packet]
    switch -glob $identifier {
      "S*" -
      "GW" {
        return false
      }
      "MS*"  -
      "MGW*" -
      "TS*"  -
      "TGW" {
        return true
      } 
      default {
        log::warning "obsolete lvc identifier $identifier."
        return false
      }
    }
  }

  proc lvcname {packet} {
    return "LVC [lvcidentifier $packet]"     
  }

  proc lvceventtimestamp {packet} {
    return [utcclock::combinedformat [seconds $packet 5]]
  }

  proc lvctrigger {packet} {
    # LVC events don't have a formal numerical trigger number, so we use the
    # timestamp to generate one.
    set timestamp [lvceventtimestamp $packet]
    return [string range [string map {"T" ""} [utcclock::combinedformat $timestamp 0 false]] 0 end-2]
  }
  
  proc lvcurl {packet} {
    return [string trimright [format "%s%s%s%s%s%s%s%s%s%s%s" \
      "https://gracedb.ligo.org/api/superevents/" \
      [fields $packet 29] \
      [fields $packet 30] \
      [fields $packet 31] \
      [fields $packet 32] \
      [fields $packet 33] \
      [fields $packet 34] \
      [fields $packet 35] \
      [fields $packet 36] \
      [fields $packet 37] \
      [fields $packet 38] \
   ] "\0"]
  }

######################################################################

  proc seconds {packet i} {
    # Convert the GCN/TAN time into seconds since the epoch. Leap
    # seconds are ignored. TJD 10281 is 1996 July 17 UTC. SOD is the
    # number of seconds since the start of the JD.
    set tjd [field0 $packet $i]
    set sod [field2 $packet [expr {$i + 1}]]
    expr {($tjd - 10281) * 24.0 * 60.0 * 60.0 + [utcclock::scan "19960717T000000"] + $sod}
  }
  
  variable typedict {
     1  "batseoriginal"
     2  "test"
     3  "imalive"
     4  "kill"
    11  "batsemaxbc"
    21  "bradfordtest"
    22  "batsefinal"
    24  "batselocburst"
    25  "alexis"
    26  "rxtepcaalert"
    27  "rxtepca"
    28  "rxteasmalert"
    29  "rxteasm"
    30  "comptel"
    31  "ipnraw"
    32  "ipnsegment"
    33  "saxwfcalert"
    34  "saxwfc"
    35  "saxnfialert"
    36  "saxnfi"
    37  "rxteasmxtrans"
    38  "sparetesting"
    39  "ipnposition"
    40  "hetescalert"
    41  "hetescupdate"
    42  "hetesclast"
    43  "hetegndana"
    44  "hetetest"
    45  "grbcounterpart"
    46  "swifttoofomobserve"
    47  "swifttooscslew"
    48  "dowtodtest"
    51  "integralpointdir"
    52  "integralspiacs"
    53  "integralwakeup"
    54  "integralrefined"
    55  "integraloffline"
    56  "integralweak"
    57  "aavso"
    58  "milagro"
    59  "konuslightcurve"
    60  "swiftbatgrbalert"
    61  "swiftbatgrbposition"
    62  "swiftbatgrbnackposition"
    63  "swiftbatgrblightcurve"
    64  "swiftbatscaledmap"
    65  "swiftfomobserve"
    66  "swiftscslew"
    67  "swiftxrtposition"
    68  "swiftxrtspectrum"
    69  "swiftxrtimage"
    70  "swiftxrtlightcurve"
    71  "swiftxrtnackposition"
    72  "swiftuvotimage"
    73  "swiftuvotsrclist"
    76  "swiftbatgrbproclightcurve"
    77  "swiftxrtprocspectrum"
    78  "swiftxrtprocimage"
    79  "swiftuvotprocimage"
    80  "swiftuvotprocsrclist"
    81  "swiftuvotposition"
    82  "swiftbatgrbpostest"
    83  "swiftpointdir"
    84  "swiftbattrans"
    85  "swiftxrtthreshpix"
    86  "swiftxrtthreshpixproc"
    87  "swiftxrtsper"
    88  "swiftxrtsperproc"
    89  "swiftuvotnackposition"
    97  "swiftbatquicklookposition"
    98  "swiftbatsubthresholdposition"
    99  "swiftbatslewgrbposition"
    100 "superagilegrbposwakeup"
    101 "superagilegrbposground"
    102 "superagilegrbposrefined"
    103 "swiftactualpointdir"
    105 "agilealert"
    107 "agilepointdir"
    109 "superagilegrbpostest"
    110 "fermigbmalert"
    111 "fermigbmfltpos"
    112 "fermigbmgndpos"
    114 "fermigbmgndinternal"
    115 "fermigbmfinpos"
    116 "fermigbmalertinternal"
    117 "fermigbmfltinternal"
    119 "fermigbmpostest"
    120 "fermilatgrbposini"
    121 "fermilatgrbposupd"
    122 "fermilatgrbposdiag"
    123 "fermilattrans"
    124 "fermilatgrbpostest"
    125 "fermilatmonitor"
    126 "fermiscslew"
    127 "fermilatgnd"
    128 "fermilatoffline"
    129 "fermipointdir"
    130 "simbadnedsearchresults"
    131 "fermigbmsubthreshold"
    133 "swiftbatmonitor"
    134 "maxiunknownsource"
    135 "maxiknownsource"
    136 "maxitest"
    137 "ogle"
    139 "moa"
    140 "swiftbatsubsubthreshpos"
    141 "swiftbatknownsrcpos"
    144 "fermiscslewinternal"
    145 "coincidence"
    146 "fermigbmfinposinternal"
    148 "suzakulightcurve"
    149 "snews"
    150 "lvcpreliminary"
    151 "lvcinitial"
    152 "lvcupdate"
    153 "lvctest"
    154 "lvccounterpart"
    157 "amonicecubecoinc"
    158 "amonicecubehese"
    159 "amonicecubetest"
    160 "caletgbmfltlc"
    161 "caletgbmgndlc"
    164 "lvcretraction"
    166 "amonicecubecluster"
    168 "gwhencoinc"
    169 "amonicecubeehe"
    170 "amonantaresfermilatcoinc"
    171 "amonhawcburstmonitor"
    172 "amongammanucoinc"
    173 "amonicecubegold"
    174 "amonicecubebronze"
  }
  
  proc type {packet} {
    set i [field0 $packet 0]
    variable typedict
    if {[dict exists $typedict $i]} {
      return [dict get $typedict $i]
    } else {
      return "unknown"
    }
  }
  
  proc field0 {packet i} {
    return [lindex $packet $i]
  }

  proc field1 {packet i} {
    return [expr {[field0 $packet $i] * 1e-1}]
  }

  proc field2 {packet i} {
    return [expr {[field0 $packet $i] * 1e-2}]
  }

  proc field4 {packet i} {
    return [expr {[field0 $packet $i] * 1e-4}]
  }
  
  proc fields {packet i} {
    return [format "%s%s%s%s" \
      [bytes $packet $i 0] \
      [bytes $packet $i 1] \
      [bytes $packet $i 2] \
      [bytes $packet $i 3] \
    ]
  }
  
  proc byte0 {packet i j} {
    return [expr {([field0 $packet $i] >> (8 * $j)) & 0xff}]
  }
  
  proc bytes {packet i j} {
    return [format "%c" [byte0 $packet $i $j]]
  }

  ######################################################################
  
  variable servercoroutine
  variable serving false
  
  proc servername {address} {
    if {![catch {set output [exec "host" $address]}]} {
      set servername [lindex [split [string trimright $output "."]] end]
    } else {
      set servername "unknown"
    }
    return $servername
  }

  proc server {channel address} {
    variable serving
    set serving true
    if {[catch {readloop $channel} message]} {
      log::error "while serving connection from [servername $address] ($address): $message"
    }
    log::summary "closing connection from [servername $address] ($address)."
    catch {close $channel}
    set serving false
    log::summary "waiting for connection."
  }

  proc accept {channel address port} {
    log::summary "accepting connection from [servername $address] ($address)."
    variable serving
    if {$serving} {
      log::warning "closing connection from [servername $address] ($address): already serving another connection."
      catch {close $channel}
    } else {
      log::summary "serving connection from [servername $address] ($address)."
      after idle coroutine gcntan::servercoroutine "gcntan::server $channel $address"
    }
  }
  
  ######################################################################

  proc stop {} {
    server::checkstatus
    server::checkactivityforstop
    server::setactivity [server::getrequestedactivity]
  }

  proc reset {} {
    server::checkstatus
    server::checkactivityforreset
    server::setactivity [server::getrequestedactivity]
  }
  
  ######################################################################

  set server::datalifeseconds 300

  proc start {} {
    variable packetport
    log::summary "waiting for connection."
    socket -server gcntan::accept $packetport
    server::setrequestedactivity "idle"
    server::setstatus "starting"
  }

  ######################################################################

}
