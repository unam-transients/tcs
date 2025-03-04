########################################################################

# This file is part of the RATTEL telescope control system.

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

  ######################################################################  

  variable packetport [config::getvalue "gcntan" "serverpacketport"]
  
  # We should get an imalive packet every 60 seconds.
  variable packettimeout 300000
  
  ######################################################################

  server::setdata "swiftalpha"   ""
  server::setdata "swiftdelta"   ""
  server::setdata "swiftequinox" ""
  
  ######################################################################
  
  proc lognull {message} {
    return
  }
  
  proc logprocedure {packet} {
    switch -glob [type $packet] {
      "swift*" {
        set test       [swifttest         lognull $packet]
        set retraction [swiftretraction   lognull $packet]
        set worthy     [swiftworthy       lognull $packet]
      }
      "fermi*" {
        set test       [fermitest         lognull $packet]
        set retraction [fermiretraction   lognull $packet]
        set worthy     [fermiworthy       lognull $packet]
      }
      "hawc*" {
        set test       [hawctest          lognull $packet]
        set retraction [hawcretraction    lognull $packet]
        set worthy     [hawcworthy        lognull $packet]
      }
      "icecube*" {
        set test       [icecubetest       lognull $packet]
        set retraction [icecuberetraction lognull $packet]
        set worthy     [icecubeworthy     lognull $packet]
      }
      "lvc*" {
        set test       [lvctest           lognull $packet]
        set retraction [lvcretraction     lognull $packet]
        set worthy     [lvcworthy         lognull $packet]
      }
      default {
        return log::info
      }
    }
    if {$test} {
      return log::info
    } elseif {![string equal $retraction ""] && $retraction} {
      return log::summary
    } elseif {![string equal $worthy ""] && !$worthy} {
      return log::info
    } else {
      return log::summary
    }
  }
  
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
        log::warning "packet length is [string length $rawpacket]."
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
        log::warning [format "received %s packet." $type]
        # Close connection without echoing the packet.
        return "close"
      }

      "swiftactualpointdir" {
        log::info [format "received %s packet." $type]
        set alpha       [swiftalpha   lognull $packet]
        set delta       [swiftdelta   lognull $packet]
        set equinox     [swiftequinox lognull $packet]
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
        set log [logprocedure $packet]
        $log [format "received %s packet." $type]
        set blockidentifier    [swifttrigger         $log $packet]
        set eventname          [swifteventname       $log $packet]
        set origin             "swift"
        set identifier         [swifttrigger         $log $packet]
        set test               [swifttest            $log $packet]
        set eventtimestamp     [swifteventtimestamp  $log $packet]
        set alpha              [swiftalpha           $log $packet]
        set delta              [swiftdelta           $log $packet]
        set equinox            [swiftequinox         $log $packet]
        set uncertainty        [swiftuncertainty     $log $packet]
        set worthy             [swiftworthy          $log $packet]
        set retraction         [swiftretraction      $log $packet]
        set class              [swiftclass           $log $packet]
        respondtoalert $log $test $blockidentifier \
          $eventname $origin $identifier $type $timestamp $eventtimestamp \
          $retraction $worthy $alpha $delta $equinox $uncertainty $class \
          "electromagnetic" "" "false"
        return "echo"
      }

      "fermigbmfltpos" -
      "fermigbmgndpos" -
      "fermigbmfinpos" -
      "fermigbmpostest" {
        set log [logprocedure $packet]
        $log [format "received %s packet." $type]
        set blockidentifier    [fermitrigger         $log $packet]
        set eventname          [fermieventname       $log $packet]
        set origin             "fermi"
        set identifier         [fermitrigger         $log $packet]
        set test               [fermitest            $log $packet]
        set eventtimestamp     [fermieventtimestamp  $log $packet]
        set alpha              [fermialpha           $log $packet]
        set delta              [fermidelta           $log $packet]
        set equinox            [fermiequinox         $log $packet]
        set uncertainty        [fermigbmuncertainty  $log $packet]
        set worthy             [fermiworthy          $log $packet]
        set retraction         [fermiretraction      $log $packet]
        set class              [fermiclass           $log $packet]
        respondtoalert $log $test $blockidentifier \
          $eventname $origin $identifier $type $timestamp $eventtimestamp \
          $retraction $worthy $alpha $delta $equinox $uncertainty $class \
          "electromagnetic" "" "false"
        return "echo"
      }
       
      "fermilatgrbpostest" -
      "fermilatgrbposupd" -
      "fermilatgnd" -
      "fermilatoffline" {
        set log [logprocedure $packet]
        $log [format "received %s packet." $type]
        set blockidentifier    [fermitrigger         $log $packet]
        set eventname          [fermieventname       $log $packet]
        set origin             "fermi"
        set identifier         [fermitrigger         $log $packet]
        set test               [fermitest            $log $packet]
        set eventtimestamp     [fermieventtimestamp  $log $packet]
        set alpha              [fermialpha           $log $packet]
        set delta              [fermidelta           $log $packet]
        set equinox            [fermiequinox         $log $packet]
        set uncertainty        [fermilatuncertainty  $log $packet]
        set worthy             [fermiworthy          $log $packet]
        set retraction         [fermiretraction      $log $packet]
        set class              [fermiclass           $log $packet]
        respondtoalert $log $test $blockidentifier \
          $eventname $origin $identifier $type $timestamp $eventtimestamp \
          $retraction $worthy $alpha $delta $equinox $uncertainty $class \
          "electromagnetic" "" "false"
        return "echo"
      }
      
      "hawcburstmonitor" {
        set log [logprocedure $packet]
        $log [format "received %s packet." $type]
        set blockidentifier    [hawctrigger        $log $packet]
        set eventname          [hawceventname      $log $packet]
        set origin             "hawc"
        set identifier         [hawctrigger        $log $packet]
        set test               [hawctest           $log $packet]
        set eventtimestamp     [hawceventtimestamp $log $packet]
        set alpha              [hawcalpha          $log $packet]
        set delta              [hawcdelta          $log $packet]
        set equinox            [hawcequinox        $log $packet]
        set uncertainty        [hawcuncertainty    $log $packet]
        set worthy             [hawcworthy         $log $packet]
        set retraction         [hawcretraction     $log $packet]
        set class              [hawcclass          $log $packet]
        respondtoalert $log $test $blockidentifier \
          $eventname $origin $identifier $type $timestamp $eventtimestamp \
          $retraction $worthy $alpha $delta $equinox $uncertainty $class \
          "electromagnetic" "" "false"
        return "echo"
      }

      "icecubeastrotrackgold" -
      "icecubeastrotrackbronze" -
      "icecubecascade" {
        set log [logprocedure $packet]
        $log [format "received %s packet." $type]
        set blockidentifier    [icecubetrigger        $log $packet]
        set eventname          [icecubeeventname      $log $packet]
        set origin             "icecube"
        set identifier         [icecubetrigger        $log $packet]
        set test               [icecubetest           $log $packet]
        set eventtimestamp     [icecubeeventtimestamp $log $packet]
        set alpha              [icecubealpha          $log $packet]
        set delta              [icecubedelta          $log $packet]
        set equinox            [icecubeequinox        $log $packet]
        set uncertainty        [icecubeuncertainty    $log $packet]
        set worthy             [icecubeworthy         $log $packet]
        set retraction         [icecuberetraction     $log $packet]
        set class              [icecubeclass          $log $packet]
        respondtoalert $log $test $blockidentifier \
          $eventname $origin $identifier $type $timestamp $eventtimestamp \
          $retraction $worthy $alpha $delta $equinox $uncertainty $class \
          "neutrino" "" "false"
        return "echo"      
      }

      "lvcpreliminary" -
      "lvcinitial" -
      "lvcupdate" -
      "lvcretraction" {
        log::info [format "received %s packet." $type]
        set log [logprocedure $packet]
        $log [format "received %s packet." $type]
        set blockidentifier    [lvctrigger         $log $packet]
        set eventname          [lvcname            $log $packet]
        set origin             "lvc"
        set identifier         [lvcidentifier      $log $packet]
        set eventtimestamp     [lvceventtimestamp  $log $packet]
        set test               [lvctest            $log $packet]
        set retraction         [lvcretraction      $log $packet]
        set skymapurl          [lvcurl             $log $packet]
        set class              [lvcclass           $log $packet]
        set preliminary        [lvcpreliminary     $log $packet]
        respondtolvcalert $log $test $blockidentifier \
          $eventname $origin $identifier $type $timestamp $eventtimestamp \
          $retraction $skymapurl $class $preliminary
        return "echo"
      }
       
      "lvccounterpart" {
        log::info [format "received %s packet." $type]
        set log [logprocedure $packet]
        $log [format "received %s packet." $type]
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
  
  proc respondtoalert {log test blockidentifier eventname
    origin identifier type alerttimestamp eventtimestamp retraction worthy
    alpha delta equinox uncertainty class messenger fixedpriority preliminary
  } {
    $log [format "%s: event name is %s." $type $eventname]
    if {$test} {
      $log [format "%s: this is a test." $type]
    } else {
      $log [format "%s: this is not a test." $type]
    }
    set enabled ""
    if {![string equal $worthy ""]} {
      if {$worthy} {
        $log [format "%s: this is a worthy event." $type]
        set enabled true
      } else {
        $log [format "%s: this is not a worthy event." $type]
        set enabled false
      }
    }
    if {![string equal $retraction ""] && $retraction} {
      $log [format "%s: this is a retraction." $type]
      set enabled false
    }
    $log [format "%s: origin/identifier/type are %s/%s/%s." $type $origin $identifier $type]
    $log [format "%s: alert timestamp is %s." $type [utcclock::format $alerttimestamp]] 
    if {![string equal $eventtimestamp ""]} {
      $log [format "%s: event timestamp is %s." $type [utcclock::format $eventtimestamp]]
      $log [format "%s: event delay is %s." $type [utcclock::formatinterval [utcclock::diff $alerttimestamp $eventtimestamp]]]
    } else {
      $log [format "%s: no event timestamp." $type]
    }
    $log [format "%s: position is %s %s %s." $type [astrometry::formatalpha $alpha] [astrometry::formatdelta $delta] $equinox]
    $log [format "%s: 90%% uncertainty is %s in radius." $type [astrometry::formatdistance $uncertainty]]
    $log [format "%s: block identifier is %d." $type $blockidentifier]
    $log [format "%s: class is %s." $type $class] 
    $log [format "%s: preliminary is %s." $type $preliminary] 
    $log [format "%s: messenger is %s." $type $messenger] 
    if {![string equal "" $fixedpriority]} {
    $log [format "%s: fixed priority is %d." $type $fixedpriority] 
    }
    if {$test} {
      $log [format "%s: not requesting selector to respond: this is a test packet." $type]
    } else {
      $log [format "%s: requesting selector to respond." $type]
      if {[catch {
        client::request "selector" [list respondtoalert \
          $blockidentifier $eventname $origin $identifier \
          $type $alerttimestamp $eventtimestamp $enabled $alpha $delta \
          $equinox $uncertainty $class $messenger $fixedpriority $preliminary \
        ]
      } result]} {
        log::warning [format "%s: unable to request selector: %s" $type $result]
      }
    }
  }
  
  proc respondtolvcalert {log test blockidentifier eventname
    origin identifier type alerttimestamp eventtimestamp retraction skymapurl
    class preliminary
  } {
    $log [format "%s: event name is %s." $type $eventname]
    if {$test} {
      $log [format "%s: this is a test." $type]
    } else {
      $log [format "%s: this is not a test." $type]
    }
    if {![string equal $retraction ""] && $retraction} {
      $log [format "%s: this is a retraction." $type]
      set enabled false
    } else {
      set enabled true
    }
    $log [format "%s: origin/identifier/type are %s/%s/%s." $type $origin $identifier $type]
    $log [format "%s: alert timestamp is %s." $type [utcclock::format $alerttimestamp]] 
    $log [format "%s: event timestamp is %s." $type [utcclock::format $eventtimestamp]]
    $log [format "%s: event delay is %s." $type [utcclock::formatinterval [utcclock::diff $alerttimestamp $eventtimestamp]]]
    if {![string equal $skymapurl ""]} {
      $log [format "%s: skymap url is %s." $type $skymapurl]
    }
    $log [format "%s: block identifier is %d." $type $blockidentifier]
    $log [format "%s: class is %s." $type $class] 
    $log [format "%s: preliminary is %s." $type $preliminary] 
    if {$test} {
      $log [format "%s: not requesting selector to respond: this is a test packet." $type]
    } else {
      $log [format "%s: requesting selector to respond." $type]
      if {[catch {
        client::request "selector" [list respondtolvcalert \
          $blockidentifier $eventname $origin $identifier $type \
          $alerttimestamp  $eventtimestamp $enabled $skymapurl $class \
          $preliminary \
        ]
      } result]} {
        log::warning [format "%s: unable to request selector: %s" $type $result]
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
  
  proc swifttest {log packet} {
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

  proc swifttrigger {log packet} {
    return [expr {[field0 $packet 4] & 0xffffff}]
  }
  
  proc swifteventname {log packet} {
    set timestamp [swifteventtimestamp $log $packet]
    if {[string equal $timestamp ""]} {
      return ""
    }
    if {[scan $timestamp "%d-%d-%dT%d:%d:%f" year month day hours minutes seconds] != 6} {
      error "unable to scan timestamp \"$timestamp\"."
    }
    set dayfraction [expr {($hours + $minutes / 60.0 + $seconds / 3600.0) / 24.0}]
    set eventname [format "Swift %02d%02d%02d.%03d (%s)" [expr {$year % 100}] $month $day [expr {int($dayfraction * 1000)}] [swiftclass $log $packet]]
    return $eventname
  }

  proc swifteventtimestamp {log packet} {
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
  
  proc swiftalpha {log packet} {
    return [astrometry::foldradpositive [astrometry::degtorad [field4 $packet 7]]]
  }
  
  proc swiftdelta {log packet} {
    return [astrometry::degtorad [field4 $packet 8]]
  }
  
  proc swiftequinox {log packet} {
    return 2000
  }
  
  proc swiftuncertainty {log packet} {
    # BAT, XRT, and UVOT give 90% radius
    set uncertainty [astrometry::degtorad [field4 $packet 11]]
    return [format "%.1fas" [astrometry::radtoarcsec $uncertainty]]
  }

  proc swiftworthy {log packet} {
    set type [type $packet]
    set class [swiftclass $log $packet]
    $log [format "%s: class is \"%s\"." $type $class]
    if {[swiftretraction lognull $packet]} {
      return false
    } elseif {[swiftcataloged lognull $packet]} {
      return false
    } else {
      return ""
    }
  }
  
  proc swiftretraction {log packet} {
    switch [type $packet] {
      "swiftbatquicklookposition" {
        return false
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
  
  proc swiftcataloged {log packet} {
    switch [type $packet] {
      "swiftbatquicklookposition" {
        return false
      }
      "swiftbatgrbpostest" -
      "swiftbatgrbposition" -
      "swiftxrtposition" -
      "swiftuvotposition" {
        if {([field0 $packet 18] >> 8) & 1} {
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
  
  proc swiftclass {log packet} {
    if {[swiftretraction lognull $packet]} {
      return "retraction"
    } elseif {[swiftcataloged lognull $packet]} {
      return "cataloged"
    } else {
      return "grb"
    }
  }
  
  ######################################################################

  # These procedures are designed to work with the following packet types:
  #
  #  fermigbmpostest
  #  fermigbmfltpos
  #  fermigbmgndpos
  #  fermigbmfinpos
  #  fermilatgrbpostest
  #  fermilatgrbposupd
  #  fermilatgnd
  #  fermilatoffline

  proc fermitest {log packet} {
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

  proc fermitrigger {log packet} {
    return [field0 $packet 4]
  }

  proc fermieventname {log packet} {
    set timestamp [fermieventtimestamp $log $packet]
    if {[string equal $timestamp ""]} {
      return ""
    }
    if {[scan $timestamp "%d-%d-%dT%d:%d:%f" year month day hours minutes seconds] != 6} {
      error "unable to scan timestamp \"$timestamp\"."
    }
    switch -glob [type $packet] {
      "fermigbm*" {
        set dayfractioninthousandths [field0 $packet 32]
        set eventname [format "Fermi GBM %02d%02d%02d.%03d (%s)" [expr {$year % 100}] $month $day $dayfractioninthousandths [fermiclass $log $packet]]
      }
      "fermilat*" {
        set dayfraction [expr {($hours + $minutes / 60.0 + $seconds / 3600.0) / 24.0}]
        set eventname [format "Fermi LAT %02d%02d%02d.%03d (%s)" [expr {$year % 100}] $month $day [expr {int($dayfraction * 1000)}] [fermiclass $log $packet]]
      }
    }
    return $eventname
  }

  proc fermieventtimestamp {log packet} {
    return [utcclock::combinedformat [seconds $packet 5]]
  }
  
  proc fermialpha {log packet} {
    return [astrometry::foldradpositive [astrometry::degtorad [field4 $packet 7]]]
  }
  
  proc fermidelta {log packet} {
    return [astrometry::degtorad [field4 $packet 8]]
  }

  proc fermiequinox {log packet} {
    return 2000
  }

  proc fermigbmuncertainty {log packet} {

    set type [type $packet]

    # We work in degrees here.

    set rawuncertainty [field4 $packet 11]
    $log [format "%s: raw uncertainty is %.1fd in radius." $type $rawuncertainty]  
    
    # We want the radius containing 90% of the probability. There are
    # two complications here.
    # 
    # First, the GCN notices distribute a raw sigma defined to be the "radius
    # containing 68% of the probability" (see the start of section 5 of
    # Connaughton et al. 2015). This is not the standard sigma in a 2-D Gaussian
    # with p(x,y) = A exp(-0.5*(r/sigma)^2).
    # 
    # Second, we need to add the systematic uncertainty. The core and
    # tail are both Gaussians and a certain fraction of the probability
    # is in the core. The parameters are given in Table 3 of Goldstein
    # et al. (2020). They are different for long and short GRBs,
    # but we use the global values. This could be improved based on the
    # classification in the GCN notice.
    #
    # So, we need to convert the raw uncertainty to a true sigma, then account
    # for the systematic uncertainty, and then determine the radius containing
    # 90% of the probability.
    #
    # In this, calculation, we use the result that the probability contained
    # within a radius r of a 2-D Gaussian with p(x,y) = A exp(-0.5*(r/sigma)^2)
    # is (1-exp(-0.5*(r/sigma)^2)).
    #
    # The mapping from raw 68% statistical uncertainty to true 90% uncertainty, including
    # systematics, is then:
    #
    #   raw  true
    #   0.0   4.8
    #   1.0   4.9
    #   2.0   5.4
    #   3.0   6.2
    #   4.0   7.2
    #   5.0   8.4
    #   6.0   9.6
    #   7.0  10.9
    #   8.0  12.2
    #   9.0  13.5
    #  10.0  14.9
    #  15.0  21.8
    #  20.0  28.8
    #  25.0  35.8
    #  30.0  42.9
    #
    # For well-localized bursts (raw uncertainty of 2 degrees or less), the
    # dominant component of the true uncertainty is the systematic uncertainty
    # of about 5 degrees. For poorly-localisted bursts (raw uncertainty of 10
    # degrees or more), the dominant correction is the factor of roughly 1.4
    # between the 68% radius and the 90% radius.
    #
    # References:
    #
    # Connaughton et al. (2015): https://ui.adsabs.harvard.edu/abs/2015ApJS..216...32C/abstract
    # Goldstein et al. (2020): https://ui.adsabs.harvard.edu/abs/2020ApJ...895...40G/abstract

    # These parameters characterize the systematic uncertainty. F is the
    # fraction in the core. C and T are the sigmas of the core and tail. See
    # Goldstein et al. (2020).
        
    set F 0.517
    set C 1.81
    set T 4.07
    
    set R $rawuncertainty
    
    # Convert from "radius containing 68% of the probability" to a true sigma.
    set R [expr {$R / sqrt(-2 * log(1-0.68))}]
    set C [expr {$C / sqrt(-2 * log(1-0.68))}]
    set T [expr {$T / sqrt(-2 * log(1-0.68))}]

    # Add the systematic and statistical uncertainties in quadrature.
    set C [expr {sqrt($R * $R + $C * $C)}]
    set T [expr {sqrt($R * $R + $T * $T)}]

    # Find the radius containing 90% of the probability.
    set P 0.9
    set r 0
    set dr 0.01
    while {true} {
      set p [expr {$F * (1 - exp(-0.5*($r*$r)/($C*$C))) + (1 - $F) * (1 - exp(-0.5*($r*$r)/($T*$T)))}]
      if {$p > $P} {
        set r [expr {$r - $dr}]      
        break
      }
      set r [expr {$r + $dr}]
    }

    set uncertainty $r
    $log [format "%s: 90%% uncertainty is %.1fd in radius." $type $uncertainty]  

    return [format "%.1fd" $uncertainty]
  }
  
  proc fermilatuncertainty {log packet} {
    # LAT gives 90% radius.
    set uncertainty [astrometry::degtorad [field4 $packet 11]]
    return [format "%.1fam" [astrometry::radtoarcmin $uncertainty]]
  }
  
  proc fermiretraction {log packet} {
    if {([field0 $packet 18] >> 5) & 1} {
      return true
    } else {
      return false
    }
  }
  
  proc fermiworthy {log packet} {
    set type [type $packet]
    set class [fermiclass $log $packet]
    $log [format "%s: class is \"%s\"." $type $class]
    switch [type $packet] {
      "fermigbmpostest" -
      "fermigbmfltpos" {
        set sigma [fermigbmtriggersigma $log $packet]
        $log [format "%s: %.1f sigma." $type $sigma]
        if {[string equal $class "grb"]} {
          return true
        } else {
          return false
        }
      }
      "fermigbmgndpos" {
        set sigma [fermigbmtriggersigma $log $packet]
        $log [format "%s: trigger sigma is %.1f." $type $sigma]
        if {[fermiretraction $log $packet]} {
          return false
        } else {
          $log [format "%s: the duration is %s." $type [fermigbmgrbduration $log $packet]]          
          return true
        }
      }
      "fermigbmfinpos" {
        if {[fermiretraction $log $packet]} {
          return false
        } else {
          $log [format "%s: the duration is %s." $type [fermigbmgrbduration $log $packet]]          
          return true
        }
      }
      "fermilatgrbposupd" -
      "fermilatgrbpostest" {
        # There are so few LAT detections that we might as well treat them all as worthy.
        set temporalsignificance [field0 $packet 25]
        set imagesignificance    [field0 $packet 26]
        set totalsignificance    [expr {$temporalsignificance + $imagesignificance}]
        $log [format "%s: temporal significance is %d." $type $temporalsignificance]
        $log [format "%s: image significance is %d."    $type $imagesignificance]
        $log [format "%s: total significance is %d."    $type $totalsignificance]
        return true
      }
      "fermilatgnd" {
        # There are so few LAT detections that we might as well treat them all as worthy.
        set significance [field2 $packet 26]
        $log [format "%s: significance is %.2f." $type $significance]
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

  proc fermigbmtriggersigma {log packet} {
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
  
  proc fermigbmgrbduration {log packet} {
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
  
  proc fermiclass {log packet} {
    if {[fermiretraction lognull $packet]} {
      return "retraction"
    }
    set type [type $packet]
    switch [type $packet] {
      "fermigbmpostest" -
      "fermigbmfltpos" {
        set i [expr {[field0 $packet 23] & 0xffff}]
        variable fermigbmclassdict
        if {[dict exists $fermigbmclassdict $i]} {
          return [dict get $fermigbmclassdict $i]
        } else {
          return "unknown"
        }   
      }
      "fermigbmgndpos" -
      "fermigbmfinpos" {
        switch [fermigbmgrbduration $log $packet] {
          "long" {
            return "lgrb"
          }
          "short" {
            return "sgrb"
          }
          default {
            return "grb"
          }
        }
      }
      default {
        return "grb"
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
    10 "sgr1806-20"
    11 "groj0422+32"
    19 "tgf"
  }
  
  proc fermiclassprobability {packet} {
    set type [type $packet]
    switch [type $packet] {
      "fermigbmpostest" -
      "fermigbmfltpos" {
        return [expr {(([field0 $packet 23] >> 16) & 0xffff) / 256.0}]
      }
      default {
        return 1.0
      }
    }
  }
  
  ######################################################################

  # These procedures are designed to work with the following packet types:
  #
  #  hawcburstmonitor
  
  proc hawctest {log packet} {
    if {([field0 $packet 18] >> 1) & 0x1} {
      return true
    } else {
      return false
    }
  }

  proc hawctrigger {log packet} {
    # HAWC events are uniquely identified by the combination of the run_id and
    # event_id, which isn't very useful for us as we want a single integer.
    # Therefore, we use the timestamp to generate one.
    set timestamp [hawceventtimestamp $log $packet]
    return [string range [string map {"T" ""} [utcclock::combinedformat $timestamp 0 false]] 0 end-2]
  }

  proc hawceventname {log packet} {
    set timestamp [hawceventtimestamp $log $packet]
    if {[string equal $timestamp ""]} {
      return ""
    }
    if {[scan $timestamp "%d-%d-%dT%d:%d:%f" year month day hours minutes seconds] != 6} {
      error "unable to scan timestamp \"$timestamp\"."
    }
    set dayfraction [expr {($hours + $minutes / 60.0 + $seconds / 3600.0) / 24.0}]
    set eventname [format "HAWC %02d%02d%02d.%03d (%s)" [expr {$year % 100}] $month $day [expr {int($dayfraction * 1000)}] [hawcclass $log $packet]]
    return $eventname
  }

  proc hawceventtimestamp {log packet} {
    return [utcclock::combinedformat [seconds $packet 5]]
  }
  
  proc hawcalpha {log packet} {
    return [astrometry::foldradpositive [astrometry::degtorad [field4 $packet 7]]]
  }
  
  proc hawcdelta {log packet} {
    return [astrometry::degtorad [field4 $packet 8]]
  }

  proc hawcequinox {log packet} {
    return 2000
  }

  proc hawcuncertainty {log packet} {

    set type [type $packet]

    # We work in degrees here.

    set rawuncertainty [field4 $packet 11]
    $log [format "%s: raw uncertainty is %.1fam in radius." $type [expr {$rawuncertainty * 60}]]

    # The notice gives the 68% statistical radius. 

    # We assume a Gaussian distribution p(x,y) = A exp(-0.5*(r/sigma)^2), for
    # which P(<r) = 1 - exp(-0.5*(r/sigma)^2). We use this to convert from the
    # 68% radius in the notice to a 90% radius.

    # According to Hugo Ayala (email on 2021-04-27), there is currently no
    # estimate of the systematic error.
    
    set r68 $rawuncertainty
    set sigma [expr {$r68 / sqrt(-2 * log(1-0.68))}]
    set r90 [expr {$sigma * sqrt(-2 * log(1-0.90))}]

    $log [format "%s: 90%% uncertainty is %.1fam in radius." $type [expr {$r90 * 60}]]

    return [format "%.1fam" [expr {$r90 * 60}]]
  }
  
  proc hawcworthy {log packet} {
    set type [type $packet]
    set class [hawcclass $log $packet]
    $log [format "%s: class is \"%s\"." $type $class]
    if {[hawcretraction $log $packet]} {
      return false
    } else {
      return true
    }
  }

  proc hawcretraction {log packet} {
    if {([field0 $packet 18] >> 5) & 0x1} {
      return true
    } else {
      return false
    }
  }
  
  proc hawcclass {log packet} {
    if {[hawcretraction lognull $packet]} {
      return "retraction"
    } else {
      return "grb"
    }
  }
  
  ######################################################################

  # These procedures are designed to work with the following packet types:
  #
  #  icecubeastrotrackgold
  #  icecubeastrotrackbronze
  #  icecubecascade
  
  proc icecubetest {log packet} {
    if {([field0 $packet 18] >> 1) & 0x1} {
      return true
    } else {
      return false
    }
  }

  proc icecubetrigger {log packet} {
    # IceCube events are uniquely identified by the combination of the run_id and
    # event_id, which isn't very useful for us as we want a single integer.
    # Therefore, we use the timestamp to generate one.
    set timestamp [icecubeeventtimestamp $log $packet]
    return [string range [string map {"T" ""} [utcclock::combinedformat $timestamp 0 false]] 0 end-2]
  }

  proc icecubeeventname {log packet} {
    set timestamp [icecubeeventtimestamp $log $packet]
    if {[string equal $timestamp ""]} {
      return ""
    }
    if {[scan $timestamp "%d-%d-%dT%d:%d:%f" year month day hours minutes seconds] != 6} {
      error "unable to scan timestamp \"$timestamp\"."
    }
    set dayfraction [expr {($hours + $minutes / 60.0 + $seconds / 3600.0) / 24.0}]
    set eventname [format "IceCube %02d%02d%02d.%03d (%s)" [expr {$year % 100}] $month $day [expr {int($dayfraction * 1000)}] [icecubeclass $log $packet]]
    return $eventname
  }

  proc icecubeeventtimestamp {log packet} {
    return [utcclock::combinedformat [seconds $packet 5]]
  }
  
  proc icecubealpha {log packet} {
    return [astrometry::foldradpositive [astrometry::degtorad [field4 $packet 7]]]
  }
  
  proc icecubedelta {log packet} {
    return [astrometry::degtorad [field4 $packet 8]]
  }

  proc icecubeequinox {log packet} {
    return 2000
  }

  proc icecubeuncertainty {log packet} {

    set type [type $packet]

    # We work in degrees here.

    set rawuncertainty [field4 $packet 11]
    $log [format "%s: raw uncertainty is %.1fam in radius." $type [expr {$rawuncertainty * 60}]]

    # The notice gives the 90% radius. 
    set r90 $rawuncertainty
    $log [format "%s: 90%% uncertainty is %.1fam in radius." $type [expr {$r90 * 60}]]

    return [format "%.1fam" [expr {$r90 * 60}]]
  }
  
  proc icecubeworthy {log packet} {
    set type [type $packet]
    set class [icecubeclass $log $packet]
    $log [format "%s: class is \"%s\"." $type $class]
    if {[icecuberetraction $log $packet]} {
      return false
    } else {
      return true
    }
  }

  proc icecuberetraction {log packet} {
    if {([field0 $packet 18] >> 5) & 0x1} {
      return true
    } else {
      return false
    }
  }

  proc icecubeclass {log packet} {
    if {[icecuberetraction lognull $packet]} {
      return "retraction"
    }
    set type [type $packet]
    switch $type {
      "icecubeastrotrackgold" {
        return "goldtrack"
      }
      "icecubeastrotrackbronze" {
        return "bronzetrack"
      }
      "icecubecascade" {
        return "cascade"
      }
    }
  }
  
  ######################################################################

  proc lvcidentifier {log packet} {

    set date [field0 $packet 4]            

    set prefixcode [expr {([field0 $packet 19] >> 20) & 0xf}]
    switch $prefixcode {
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
        log::warning "unknown lvc prefix code $prefixcode."
        set prefix ""
      }
    }

    set suffix0 [format "%c" [expr {([field0 $packet 19] >> 10) & 0xff}]]
    set suffix1 [format "%c" [expr {([field0 $packet 21] >>  0) & 0xff}]]          

    return [string trimright "${prefix}${date}${suffix0}${suffix1}"]
  }

  proc lvctest {log packet} {
    set identifier [lvcidentifier $log $packet]
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

  proc lvcname {log packet} {
    return "LVC [lvcidentifier $log $packet] ([lvcclass $log $packet])"     
  }

  proc lvceventtimestamp {log packet} {
    return [utcclock::combinedformat [seconds $packet 5]]
  }

  proc lvctrigger {log packet} {
    # LVC events don't have a formal numerical trigger number, so we use the
    # timestamp to generate one.
    set timestamp [lvceventtimestamp $log $packet]
    return [string range [string map {"T" ""} [utcclock::combinedformat $timestamp 0 false]] 0 end-2]
  }
  
  proc lvcurl {log packet} {
    if {[lvcretraction $log $packet]} {
      return ""
    } else {
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
  }
  
  proc lvcworthy {log packet} {
    set type [type $packet]
    set class [lvcclass $log $packet]
    $log [format "%s: class is \"%s\"." $type $class]
    return true
  }
  
  proc lvcretraction {log packet} {
    switch [type $packet] {
      "lvcretraction" {
        return true
      }
      default {
        return false
      }
    }
  }
  
  proc lvcclass {log packet} {
    if {[lvcretraction lognull $packet]} {
      return "retraction"
    } else {
      return "detection"
    }
  }

  proc lvcpreliminary {log packet} {
    switch [type $packet] {
      "lvcpreliminary" {
        return true
      }
      default {
        return false
      }
    }
  }

  ######################################################################

  proc seconds {packet i} {
    # Convert the GCN/TAN time into seconds since the epoch. Leap
    # seconds are ignored. TJD 10281 is 1996 July 17 UTC. SOD is the
    # number of seconds since the start of the JD.
    set tjd [field0 $packet $i]
    set sod [field2 $packet [expr {$i + 1}]]
    set jd [expr {$tjd - 10281 + [utcclock::jd "1996-07-17T00:00:00"]}]
    set seconds [expr {[utcclock::fromjd $jd] + $sod}]
    return $seconds
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
    157 "icecubecoinc"
    158 "icecubehese"
    159 "icecubetest"
    160 "caletgbmfltlc"
    161 "caletgbmgndlc"
    164 "lvcretraction"
    166 "icecubecluster"
    168 "gwhencoinc"
    169 "icecubeehe"
    170 "amonantaresfermilatcoinc"
    171 "hawcburstmonitor"
    172 "amonnuemcoinc"
    173 "icecubeastrotrackgold"
    174 "icecubeastrotrackbronze"
    175 "sksupernova"
    176 "icecubecascade"
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
      log::warning "while serving connection from [servername $address] ($address): $message"
    }
    log::info "closing connection from [servername $address] ($address)."
    catch {close $channel}
    set serving false
    log::info "waiting for connection."
  }

  proc accept {channel address port} {
    log::info "accepting connection from [servername $address] ($address)."
    variable serving
    if {$serving} {
      log::warning "closing connection from [servername $address] ($address): already serving another connection."
      catch {close $channel}
    } else {
      log::info "serving connection from [servername $address] ($address)."
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
    log::info "waiting for connection."
    socket -server gcntan::accept $packetport
    server::setrequestedactivity "idle"  
  }

  ######################################################################

  # Test the code by putting the decimal representation of a packet (40
  # integers) as a list in the second argument below and uncommenting the
  # call. This packet will be processed when the server starts.

  # processpacket [utcclock::combinedformat] {}

  ######################################################################

}
