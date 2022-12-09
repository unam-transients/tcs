########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "detectorsi" 0.0

load [file join [directories::prefix] "lib" "detectorsi.so"] "detector"

namespace eval "detector" {
  
  variable bscale 1.0
  variable bzero  32768.0

  ######################################################################

  variable rawsiimagechannel ""
  
  variable rawcameraidentifier             1
  variable rawacquisitiontypeshutteropen   ""
  variable rawacquisitiontypeshutterclosed ""
  variable rawacquisitionmodesingleimage   ""

  variable rawacquiring                    false
  variable rawretrieving                   false

  ######################################################################
  
  variable rawdescription ""
  
  ######################################################################
  
  proc detectorrawstart {} {
  }

  ######################################################################

  proc detectorrawopen {identifier} {

    variable rawsiimagechannel

    log::debug "detectorrawopen: start."

    set host [lindex [split $identifier ":"] 0]
    set port [lindex [split $identifier ":"] 1]
    log::debug "detectorrawopen: host = $host port = $port."

    if {![string equal $rawsiimagechannel ""]} {
      log::debug "detectorrawopen: closing channel."
      catch {::close $rawsiimagechannel}
      set rawsiimagechannel ""
    }    

    log::debug "detectorrawopen: opening channel."
    if {[catch {set rawsiimagechannel [socket $host $port]} message]} {
      set rawsiimagechannel ""
      error "unable to open $identifier: $message."
    }
    log::debug "detectorrawopen: opened channel."

    chan configure $rawsiimagechannel -buffering "none"
    chan configure $rawsiimagechannel -encoding "binary"
    chan configure $rawsiimagechannel -translation "binary"
    
    log::info "checking camera is open."
    if {[catch {
      rawputsiimagecommandpacket "getstatus"
      rawgetsiimagedatapacket "getstatus"
    } message]} {
      log::error "camera is closed: $message"
      exit
    }
    
    # Determine the description.
    rawputsiimagecommandpacket "getparameters"
    set data [rawgetsiimagedatapacket "getparameters"]
    foreach line $data {
      log::debug "getparameters: line is \"$line\"."
      if {[scan $line "Factory,Instrument Model,%s" value] == 1} {
        set model $value
      } elseif {[scan $line "Factory,Instrument SN,%s" value] == 1} {
        set serialnumber $value
      } elseif {[scan $line "Setup,CCD Temperature Setpoint,%d" value] == 1} {
        variable rawcoolersettemperature
        set rawcoolersettemperature [format "%+.1f" [expr {-273 + 0.1 * $value}]]
      }
    }
    variable rawdescription
    set rawdescription "SI $model-$serialnumber"
    
    # Determine the aquisition types for open and closed images.
    log::info "determining shutter settings."
    rawputsiimagecommandpacket "getacquisitiontypes"
    set data [rawgetsiimagedatapacket "getacquisitiontypes"]
    variable rawacquisitiontypeshutteropen
    variable rawacquisitiontypeshutterclosed
    foreach line $data {
      log::debug "line is $line."
      if {[scan $line "Light,%d" value] == 1} {
        log::debug "detectorrawopen: shutter open = $value."
        set rawacquisitiontypeshutteropen $value
      }
      if {[scan $line "Dark,%d" value] == 1} {
        log::debug "detectorrawopen: shutter closed = $value."
        set rawacquisitiontypeshutterclosed $value
      }
    }
    if {[string equal $rawacquisitiontypeshutteropen ""]} {
      error "unable to determine the acquisition type for shutter open."
    }
    if {[string equal $rawacquisitiontypeshutterclosed ""]} {
      error "unable to determine the acquisition type for shutter closed."
    }
      
    # Determine the aquisition mode for single image.
    log::info "determining acquisition modes."
    rawputsiimagecommandpacket "getacquisitionmodes"
    set data [rawgetsiimagedatapacket "getacquisitionmodes"]
    variable rawacquisitionmodesingleimage
    foreach line $data {
      log::debug "line is $line."
      if {[scan $line "Single Image,%d," value] == 1} {
        log::debug "detectorrawopen: single image = $value."
        set rawacquisitionmodesingleimage $value
      }
    }
    if {[string equal $rawacquisitionmodesingleimage ""]} {
      error "unable to determine the acquisition mode for single image."
    }
    
    log::info "setting continuous clearing."
    rawputsiimagecommandpacket "setcontinuousclearmode" 0
    rawgetsiimagedatapacket "setcontinuousclearmode"

    log::info "setting acquisition mode to single image."
    rawputsiimagecommandpacket "setacquisitionmode" $rawacquisitionmodesingleimage
    rawgetsiimagedatapacket "setacquisitionmode"
    
    log::info "setting image packet parameters."
    rawputsiimagecommandpacket "setimagepacket" [expr {64 * 1024 - 1}] 0
    rawgetsiimagedatapacket "setimagepacket"
        
    detectorrawsetisopen true
    
    detectorrawsetunbinnedwindow 0 0 0 0

    detectorrawupdatestatus
        
    log::debug "open specific: done."

    return "ok"
  }
  
  proc detectorrawclose {} {
    variable rawsiimagechannel
    catch {::close $rawsiimagechannel}
    set rawsiimagechannel ""
    detectorrawsetisopen false
    return "ok"
  }
  
  ######################################################################

  proc detectorrawreset {} {
    return "ok"
  }
  
  ######################################################################
  
  variable rawsiimagecommanddict {
    "getstatus"                { 1011  0 ""       true  2012  log::debug }
    "getparameters"            { 1048  0 ""       true  2010  log::debug }
    "getacquisitiontypes"      { 1061  0 ""       true  2013  log::debug }
    "setacquisitiontype"       { 1036  1 "c"      true  2007  log::debug }
    "getacquisitionmodes"      { 1066  0 ""       true  2013  log::debug }
    "setacquisitionmode"       { 1034  1 "c"      true  2007  log::debug }
    "setexposuretime"          { 1035  8 "Q"      true  2007  log::debug }
    "acquire"                  { 1037  0 ""       true  2007  log::debug }
    "inquireacquisitionstatus" { 1017  0 ""       false 2004  log::debug }
    "terminateacquisition"     { 1018  0 ""       false 2007  log::debug }
    "setimagepacket"           { 1022  4 "SuSu"   true  2007  log::debug }
    "retrieveimage"            { 1019  2 "Su"     true  false log::debug }
    "getimageheader"           { 1024  2 "Su"     true  2006  log::debug }
    "setcameramode"            { 1042  1 "c"      true  2007  log::debug }
    "setformat"                { 1043 24 "IIIIII" true  2007  log::debug }
    "setcooler"                { 1046  1 "c"      true  2007  log::debug }
    "setcontinuousclearmode"   { 1062  1 "c"      true  2007  log::debug }
    "resetcamerasoftware"      { 1063  0 ""       true  2007  log::debug }
    "resetcamerahardware"      { 1064  0 ""       true  2007  log::debug }
  }
  
  proc rawsiimagecheckcommand {command} {
    variable rawsiimagecommanddict
    if {[dict exists $rawsiimagecommanddict $command]} {
      return true
    } else {
      return false
    }
  }
  
  proc rawsiimagefunctionnumber {command} {
    variable rawsiimagecommanddict
    return [lindex [dict get $rawsiimagecommanddict $command] 0]
  }
  
  proc rawsiimageparameterlength {command} {
    variable rawsiimagecommanddict
    return [lindex [dict get $rawsiimagecommanddict $command] 1]
  }
  
  proc rawsiimageparameterformat {command} {
    variable rawsiimagecommanddict
    return [lindex [dict get $rawsiimagecommanddict $command] 2]
  }
  
  proc rawsiimageisacknowledged {command} {
    variable rawsiimagecommanddict
    return [lindex [dict get $rawsiimagecommanddict $command] 3]
  }
  
  proc rawsiimagedatatype {command} {
    variable rawsiimagecommanddict
    return [lindex [dict get $rawsiimagecommanddict $command] 4]
  }
  
  proc rawsiimagelogprocedure {command} {
    variable rawsiimagecommanddict
    return [lindex [dict get $rawsiimagecommanddict $command] 5]
  }
  
  ######################################################################

  proc rawgetpacket {command} {
    variable rawsiimagechannel
    set logprocedure [rawsiimagelogprocedure $command]
    $logprocedure "rawgetpacket: $command: start."
    set start [read $rawsiimagechannel 4]
    if {[string length $start] < 4} {
      error "rawgetpacket: $command: truncated packet."
    }
    binary scan $start Iu packetlength
    $logprocedure "rawgetpacket: $command: packet length = $packetlength."
    set rest [read $rawsiimagechannel [expr {$packetlength - 4}]]
    set packet [binary format "a*a*" $start $rest]
    if {[string length $packet] != $packetlength} {
      error "rawgetpacket: $command: truncated packet."
    }
    $logprocedure "rawgetpacket: $command: end."
    return $packet    
  }
  
  proc rawputpacket {command packet} {
    variable rawsiimagechannel
    set logprocedure [rawsiimagelogprocedure $command]
    $logprocedure "rawputpacket: $command: start."
    set packetlength [string length $packet]
    $logprocedure "rawputpacket: $command: packet length = $packetlength."
    puts -nonewline $rawsiimagechannel $packet
    flush $rawsiimagechannel
    $logprocedure "rawputpacket: $command: end."
  }

  ######################################################################

  proc rawputsiimagecommandpacket {command args} {

    # Send a command packet to the TCP/IP server. If appropriate, wait
    # for an acknowledgement.
    
    # The format of command packets is given in §5.1.1 and §5.3 of the
    # SI Image manual.

    # The format of acknowledgement packets is given in §5.1.2 of the SI
    # Image manual.
 
    variable rawcameraidentifier
    variable rawacquiring
    variable rawretrieving

    if {![rawsiimagecheckcommand $command]} {
      error [format "rawputsiimagecommandpacket: $command: invalid command \"%s\"." $command]
    }

    set logprocedure [rawsiimagelogprocedure $command]

    $logprocedure [format "rawputsiimagecommandpacket: $command: parameters are \"%s\"." $args]
    set packetlength [expr {10 + [rawsiimageparameterlength $command]}]
    set commandpacket [eval binary format "IccSS[rawsiimageparameterformat $command]" \
      $packetlength 128 $rawcameraidentifier [rawsiimagefunctionnumber $command] [rawsiimageparameterlength $command] \
      $args \
    ]

    rawputpacket $command $commandpacket
    
    if {[string equal $command "acquire"]} {
      set rawacquiring true
    } elseif {[string equal $command "retrieveimage"]} {
      set rawretrieving true
    }
    
    if {[rawsiimageisacknowledged $command]} {
      rawgetsiiacknowledgementpacket $command
    }  
  }
  
  ######################################################################

  proc rawgetsiiacknowledgementpacket {command} {
  
    # Get an acknowledgement packet from the TCP/IP server.

    variable rawsiimagechannel
    variable rawcameraidentifier
    variable rawacquiring

    if {![rawsiimagecheckcommand $command]} {
      error [format "rawgetsiiacknowledgementpacket: $command: invalid command \"%s\"." $command]
    }

    set logprocedure [rawsiimagelogprocedure $command]
    
    set packet [rawgetpacket $command]
    
    binary scan $packet Iucucua* packetlength packetidentifier packetcameraidentifier packetrest
    $logprocedure "rawgetsiiacknowledgementpacket: $command: packet length is $packetlength."
    $logprocedure "rawgetsiiacknowledgementpacket: $command: packet identifier is $packetidentifier."
    $logprocedure "rawgetsiiacknowledgementpacket: $command: packet rawcameraidentifier is $packetcameraidentifier."

    if {$packetcameraidentifier != $rawcameraidentifier} {
      error "rawgetsiiacknowledgementpacket: $command: invalid packet: camera identifier is $packetcameraidentifier instead of $rawcameraidentifier."
    }
    
    if {$packetidentifier == 129} {

      if {$packetlength != 8} {
        error "rawgetsiiacknowledgementpacket: $command: invalid acknowledgement packet: incorrect packet length."
      }
      binary scan $packetrest Su packetaccepted
      $logprocedure "rawgetsiiacknowledgementpacket: $command: packet accepted is $packetaccepted."
      if {!$packetaccepted} {
        error "rawgetsiiacknowledgementpacket: $command: acknowledgement packet: command not accepted."
      }

    } elseif {$packetidentifier == 131} {
    
      # In addition to the acknowledgement packet we are expecting, we
      # could potentially receive a delayed end-of-acquisition command
      # done packet from a previous acquire command. If this is the
      # case, we note that the acquisition has finished and continue to
      # read another packet.

      binary scan $packetrest ISuIa* packeterrorcode packetdatatype packetdatalength packetstructure
      if {$packetdatalength + 16 != $packetlength} {
        error "rawgetsiiacknowledgementpacket: $command: invalid data packet: packet length is $packetlength but data length is $packetdatalength."     
      }
      if {$packeterrorcode != 0} {
        error "rawgetsiiacknowledgementpacket: $command: invalid command done data packet: error code is $packeterrorcode."     
      }
      if {$packetdatatype != 2007} {
        error "rawgetsiiacknowledgementpacket: $command: invalid command done data packet: data type is $packetdatatype."     
      }
      if {$packetlength != 18} {
        error "rawgetsiiacknowledgementpacket: $command: invalid command done data packet: packet length is $packetlength."
      }
      if {$packetdatalength != 2} {
        error "rawgetsiiacknowledgementpacket: $command: invalid command done data packet: data length is $packetdatalength."     
      }
      $logprocedure "rawgetsiiacknowledgementpacket: $command: packeterrorcode is $packeterrorcode."
      binary scan $packetstructure S packetfunctionnumber
      $logprocedure "rawgetsiiacknowledgementpacket: $command: packetfunctionnumber is $packetfunctionnumber."
      if {
        $packetfunctionnumber == [rawsiimagefunctionnumber "acquire"] ||
        $packetfunctionnumber == [rawsiimagefunctionnumber "inquireacquisitionstatus"]
      } {
        if {!$rawacquiring} {
          error "rawgetsiiacknowledgementpacket: $command: received end-of-acquisition packet while not rawacquiring."
        }
        $logprocedure "rawgetsiiacknowledgementpacket: $command: received end-of-acquisition packet."
        set rawacquiring false
        rawgetsiiacknowledgementpacket $command
      } else {
        error "rawgetsiiacknowledgementpacket: $command: invalid packet function number $packetfunctionnumber."
      }

    } else {
  
      error "rawgetsiiacknowledgementpacket: $command: invalid packet identifier $packetidentifier"

    }
  }
  
  ######################################################################

  proc rawgetsiimagedatapacket {command} {

    # Receive a data packet from the TCP/IP server.
    
    # The format of data packets is given in §5.1.3 and §5.2 of the SI
    # Image manual.
    
    variable rawsiimagechannel
    variable rawcameraidentifier    
    variable rawacquiring

    if {![rawsiimagecheckcommand $command]} {
      error [format "rawgetsiimagedatapacket: $command: invalid command \"%s\"." $command]
    }

    set logprocedure [rawsiimagelogprocedure $command]
    
    set packet [rawgetpacket $command]

    binary scan $packet Iucucua* packetlength packetidentifier packetcameraidentifier packetrest
    $logprocedure "rawgetsiimagedatapacket: $command: packet length is $packetlength."
    $logprocedure "rawgetsiimagedatapacket: $command: packet identifier is $packetidentifier."
    $logprocedure "rawgetsiimagedatapacket: $command: packet rawcameraidentifier is $packetcameraidentifier."

    if {$packetcameraidentifier != $rawcameraidentifier} {
      error "rawgetsiimagedatapacket: $command: invalid packet: camera identifier is $packetcameraidentifier instead of $rawcameraidentifier."
    }
    
    if {$packetidentifier != 131} {
       error "rawgetsiimagedatapacket: $command: invalid data packet: packet identifier is $packetidentifier."
    } 
    
    binary scan $packetrest ISuIa* packeterrorcode packetdatatype packetdatalength packetstructure
    $logprocedure "rawgetsiimagedatapacket: $command: packet error code is $packeterrorcode."
    $logprocedure "rawgetsiimagedatapacket: $command: packet data type is $packetdatatype."
    $logprocedure "rawgetsiimagedatapacket: $command: packet data length is $packetdatalength."

    if {$packetdatalength + 16 != $packetlength} {
      error "rawgetsiiacknowledgementpacket: $command: invalid data packet: packet length is $packetlength but data length is $packetdatalength."     
    }
    if {$packeterrorcode != 0} {
       error "rawgetsiimagedatapacket: $command: invalid data packet: error code is $packeterrorcode."
    }

    # In addition to the data packet we are expecting, we could
    # potentially receive a delayed end-of-acquisition command done
    # packet from a previous acquire command. If this is the case, we
    # note that the acquisition has finished and continue to read
    # another packet.

    if {$packetdatatype == 2007} {
      # 2007: Command Done §5.2.5
      $logprocedure "rawgetsiimagedatapacket: $command: data: command done."
      binary scan $packetstructure S packetfunctionnumber
      # There is a bug in SI Image: the command done packet for an
      # acquire command can sometimes be reported as coming from an
      # acquire acquisition status command. I reported this to Dan
      # Gilmore on 2020-04-02, and he confirmed it is a bug. He's
      # working on a fix.
      if {
        $packetfunctionnumber == [rawsiimagefunctionnumber "acquire"] ||
        $packetfunctionnumber == [rawsiimagefunctionnumber "inquireacquisitionstatus"]
      } {
        if {!$rawacquiring} {
          error "rawgetsiimagedatapacket: $command: received end-of-acquisition packet while not rawacquiring."
        }
        $logprocedure "rawgetsiimagedatapacket: $command: received end-of-acquisition packet."
        set rawacquiring false
        return [rawgetsiimagedatapacket $command]
      } 
    }
    
    if {$packetdatatype != [rawsiimagedatatype $command]} {
      error "rawgetsiimagedatapacket: $command: invalid data packet: data type is $packetdatatype instead of [rawsiimagedatatype $command]."
    }
    
    switch $packetdatatype {
      2004 {
        # 2004: Acquisition Status §5.2.3
        $logprocedure "rawgetsiimagedatapacket: $command: data: acquisition status."
        binary scan $packetstructure SuSuIuI percentexposuredone percentreadoutdone relativepositionofreadout currentimage
        $logprocedure "rawgetsiimagedatapacket: $command: data: structure is $percentexposuredone $percentreadoutdone $relativepositionofreadout $currentimage."
        return [list $percentexposuredone $percentreadoutdone $relativepositionofreadout $currentimage]
      }
      2006 {
        # 2006: Image Header §5.2.4
        $logprocedure "rawgetsiimagedatapacket: $command: data: image header."
        set i 0
        set records {}
        while {true} {
          set record [string range $packetstructure $i [expr {$i +  79}]]
          if {[string equal "END" [string trimright $record]]} {
            break
          }
          lappend records $record
          incr i 80
        }
        return $records
      }
      2007 {
        # 2007: Command Done §5.2.5
        $logprocedure "rawgetsiimagedatapacket: $command: data: command done."
        binary scan $packetstructure S datafunctionnumber
        $logprocedure "rawgetsiiacknowledgementpacket: $command: packetfunctionnumber is $packetfunctionnumber."
        if {$datafunctionnumber != [rawsiimagefunctionnumber $command]} {
          error "rawgetsiimagedatapacket: $command: invalid data: function number is $datafunctionnumber instead of [rawsiimagefunctionnumber $command]."
        }
        return
      }
      2010 {
        # 2010: Camera Parameters §5.2.9
        $logprocedure "rawgetsiimagedatapacket: $command: data: camera parameters."
        return [split $packetstructure "\n"]
      }
      2012 {
        # 2012: Status §5.2.1 
        $logprocedure "rawgetsiimagedatapacket: $command: data: status."
        return [split $packetstructure "\n"]
      }
      2013 {
        # 2013: Menu Information §5.2.9
        $logprocedure "rawgetsiimagedatapacket: $command: data: menu."
        return [split $packetstructure "\n"]
      }
      default {
        error "rawgetsiimagedatapacket: $command: unhandled data type $packetdatatype."
        return
      }
    }

  }
  
  ######################################################################

  proc rawgetsiimageimagepacket {} {

    # Receive a image packet from the TCP/IP server.
    
    # The format of image packets is given in §5.1.4 of the SI Image manual.
    
    variable rawcameraidentifier    
    variable rawretrieving
    
    set command "retrieveimage"

    if {![rawsiimagecheckcommand $command]} {
      error [format "rawgetsiimageimagepacket: $command: invalid command \"%s\"." $command]
    }

    set logprocedure [rawsiimagelogprocedure $command]
    
    set packet [rawgetpacket $command]

    binary scan $packet Iucucua* packetlength packetidentifier packetcameraidentifier packetrest
    $logprocedure "rawgetsiimageimagepacket: $command: packet length is $packetlength."
    $logprocedure "rawgetsiimageimagepacket: $command: packet identifier is $packetidentifier."
    $logprocedure "rawgetsiimageimagepacket: $command: packet rawcameraidentifier is $packetcameraidentifier."

    if {$packetcameraidentifier != $rawcameraidentifier} {
      error "rawgetsiimageimagepacket: $command: invalid packet: camera identifier is $packetcameraidentifier instead of $rawcameraidentifier."
    }
    
    if {$packetidentifier == 129} {
    }
    
    if {$packetidentifier != 132} {
       error "rawgetsiimageimagepacket: $command: invalid image packet: packet identifier is $packetidentifier."
    } 
    
    binary scan $packetrest ISuSuSuSuIIIIua* \
      packeterrorcode packetimageidentifier packetimagetype packetseriallength packetparallellength \
      packettotalnumber packetcurrentnumber packetoffset packetbytes packetstructure
      
    $logprocedure "rawgetsiimageimagepacket: $command: packet error code is $packeterrorcode."
    $logprocedure "rawgetsiimageimagepacket: $command: packet image type is $packetimagetype."
    $logprocedure "rawgetsiimageimagepacket: $command: packet serial length is $packetseriallength."
    $logprocedure "rawgetsiimageimagepacket: $command: packet parallel length is $packetparallellength."
    $logprocedure "rawgetsiimageimagepacket: $command: packet total number is $packettotalnumber."
    $logprocedure "rawgetsiimageimagepacket: $command: packet current number is $packetcurrentnumber."
    $logprocedure "rawgetsiimageimagepacket: $command: packet offset is $packetoffset."
    $logprocedure "rawgetsiimageimagepacket: $command: packet bytes is $packetbytes."

    if {$packetbytes + 34 != $packetlength} {
      error "rawgetsiiacknowledgementpacket: $command: invalid image packet: packet length is $packetlength but packet bytes is $packetbytes."     
    }
    if {$packeterrorcode} {
       error "rawgetsiimageimagepacket: $command: invalid image packet: error code is $packeterrorcode."
    }
    
    if {$packetcurrentnumber == $packettotalnumber - 1} {
      set rawretrieving false
    }
    
    return $packetstructure
  }
  

  ######################################################################

  variable lastcameraflags      0
  variable lastrawcooler        ""
  variable lastrawcoolerlowflow ""
  variable lastrawcompressor    ""
  
  variable lastgetstatustimestamp ""
  variable detectorrawupdatestatusvalue "error"

  proc detectorrawupdatestatus {} {

    log::debug "detectorrawupdatestatus: start."

    variable rawsiimagechannel
    variable rawacquiring
    variable rawretrieving
    variable estimatedexposureend
    variable lastgetstatustimestamp
    variable detectorrawupdatestatusvalue

    log::debug "detectorrawupdatestatus: lastgetstatustimestamp = $lastgetstatustimestamp."
    
    # Avoid sending getstatus commands: (a) while reading (or in the last second
    # of reading), since they will hang; (b) while retrieving to avoid
    # interrupting the flow of image packets; and (c) within 15 seconds of the
    # previous one (since SI Image imposes a minimum delay of 10 seconds).
    
    if {$rawacquiring && [utcclock::diff $estimatedexposureend "now"] < 2} {
      log::debug "detectorrawupdatestatus: acquiring."
    } elseif {$rawretrieving} {
      log::debug "detectorrawupdatestatus: retrieving."
    } elseif {
      ![string equal "" $lastgetstatustimestamp] &&
      [utcclock::diff "now" $lastgetstatustimestamp] < 15
    } {
      log::debug [format "detectorrawupdatestatus: only %.1f seconds since last getstatus command." [utcclock::diff "now" $lastgetstatustimestamp]]
    } elseif {[catch {
      log::debug "detectorrawupdatestatus: sending getstatus command."
      set lastgetstatustimestamp [utcclock::format]
      rawputsiimagecommandpacket "getstatus"
      set data [rawgetsiimagedatapacket "getstatus"]
    }]} {
      set detectorrawupdatestatusvalue "getstatus command failed."
    } else {

      log::debug "detectorrawupdatestatus: processing getstatus data."
      foreach line $data {
        log::debug "detectorrawupdatestatus: getstatus line: \"$line\"."
        if {[scan $line "CCD 0 CCD Temp.,%f," value] == 1} {
          log::debug "rawdetectortemperature is $value."
          variable rawdetectortemperature
          set rawdetectortemperature $value
        } elseif {[scan $line "Cold End Temperature,%f," value] == 1} {
          log::debug "rawcoldendtemperature is $value."
          variable rawcoldendtemperature
          set rawcoldendtemperature $value
        } elseif {[scan $line "PS Case Temp,%f," value] == 1} {
          log::debug "rawpowersupplytemperature is $value."
          variable rawpowersupplytemperature
          set rawpowersupplytemperature $value
        } elseif {[scan $line "Chamber Pressure,%f," value] == 1} {
          # Convert to mbar
          set value [expr {$value / 750.06 * 1e3}]
          log::debug "rawchamberpressure is $value."
          variable rawchamberpressure
          set rawchamberpressure $value
        } elseif {[scan $line "PS Pressure 2,%f," value] == 1} {
          log::debug "rawcompressorsupplypressure is $value."
          variable rawcompressorsupplypressure
          set rawcompressorsupplypressure $value
        } elseif {[scan $line "PS Pressure 1,%f," value] == 1} {
          log::debug "rawcompressorreturnpressure is $value."
          variable rawcompressorreturnpressure
          set rawcompressorreturnpressure $value
        } elseif {[scan $line "Cryo Current,%f," value] == 1} {
          log::debug "compressor current is $value."
          variable rawcompressorcurrent
          set rawcompressorcurrent $value
        } elseif {[scan $line "CCD Heater Current,%f," value] == 1} {
          log::debug "rawdetectorheatercurrent is $value."
          variable rawdetectorheatercurrent
          set rawdetectorheatercurrent $value
        } elseif {[scan $line "Cold End Heater Current,%f," value] == 1} {
          log::debug "rawcoldendheatercurrent is $value."
          variable rawcoldendheatercurrent
          set rawcoldendheatercurrent $value
        } elseif {[scan $line "Camera Flags,%d," value] == 1} {
          log::debug "camera flags are $value."
          variable lastcameraflags
          set cameraflags $value
          if {$cameraflags != $lastcameraflags} {
            log::debug [format "camera flags changed from %x to %x." $lastcameraflags $cameraflags]
          }
          set lastcameraflags $cameraflags
        }

        variable rawcooler
        if {$cameraflags & 0x20} {
          set rawcooler on
        } else {
          set rawcooler off
        }
        variable lastrawcooler
        if {[string equal "" $lastrawcooler]} {
          log::info "cooler state is \"$rawcooler\"."
        } elseif {![string equal $rawcooler $lastrawcooler]} {
          log::info "cooler state changed from \"$lastrawcooler\" to \"$rawcooler\"."
        }
        set lastrawcooler $rawcooler

	variable lastrawcompressor
	variable rawcompressorcurrent
	if {$rawcompressorcurrent > 0.5} {
	  set rawcompressor "on"
	} else {
	  set rawcompressor "off"
	}
        if {[string equal "" $lastrawcompressor]} {
          log::info "compressor is \"$rawcompressor\"."
        } elseif {![string equal $lastrawcompressor $rawcompressor]} {
          log::info "compressor changed from \"$lastrawcompressor\" to \"$rawcompressor\"."
        }
        set lastrawcompressor $rawcompressor

        variable rawcoolerlowflow
        if {$cameraflags & 0x10} {
          set rawcoolerlowflow on
        } else {
          set rawcoolerlowflow off
        }
        variable lastrawcoolerlowflow
        if {[string equal "" $lastrawcoolerlowflow]} {
          log::info "cooler low flow is \"$rawcooler\"."
        } elseif {![string equal $rawcoolerlowflow $lastrawcoolerlowflow]} {
          variable rawcoldendtemperature
          log::info [format "cooler low flow changed from \"$lastrawcoolerlowflow\" to \"$rawcoolerlowflow\" with cold end at %+.1f C." $rawcoldendtemperature]
        }
        set lastrawcoolerlowflow $rawcoolerlowflow
        
        set detectorrawupdatestatusvalue "ok"
      }
    }

    log::debug "detectorrawupdatestatus: end"

    return $detectorrawupdatestatusvalue
  }
  
  proc detectorrawgetvalue {name} {
  
    switch $name {
      "description" {
        variable rawdescription
        return $rawdescription
      }
      "detectortemperature" {
        variable rawdetectortemperature
        return $rawdetectortemperature
      }
      "coldendtemperature" {
        variable rawcoldendtemperature
        return $rawcoldendtemperature
      }
      "powersupplytemperature" {
        variable rawpowersupplytemperature
        return $rawpowersupplytemperature
      }
      "chamberpressure" {
        variable rawchamberpressure
        return $rawchamberpressure
      }
      "compressorsupplypressure" {
        variable rawcompressorsupplypressure
        return $rawcompressorsupplypressure
      }
      "compressorreturnpressure" {
        variable rawcompressorreturnpressure
        return $rawcompressorreturnpressure
      }
      "coolersettemperature" {
        variable rawcoolersettemperature
        return $rawcoolersettemperature
      }
      "compressorcurrent" {
        variable rawcompressorcurrent
        return $rawcompressorcurrent
      }
      "compressor" {
        variable rawcompressor
        return $rawcompressor
      }
      "detectorheatercurrent" {
        variable rawdetectorheatercurrent
        return $rawdetectorheatercurrent
      }
      "coldendheatercurrent" {
        variable rawcoldendheatercurrent
        return $rawcoldendheatercurrent
      }
      "coolersettemperature" {
        variable rawcoolersettemperature
        return $rawcoolersettemperature
      }
      "cooler" {
        variable rawcooler
        return $rawcooler
      }
      "coolerlowflow" {
        variable rawcoolerlowflow
        return $rawcoolerlowflow
      }
      "readmode" {
        variable rawreadmode
        return $rawreadmode
      }
      "unbinnedwindowsx" {
        variable rawunbinnedwindowsx
        return $rawunbinnedwindowsx
      }
      "unbinnedwindowsy" {
        variable rawunbinnedwindowsy
        return $rawunbinnedwindowsy
      }
      "unbinnedwindownx" {
        variable rawunbinnedwindownx
        return $rawunbinnedwindownx
      }
      "unbinnedwindowny" {
        variable rawunbinnedwindowny
        return $rawunbinnedwindowny
      }
      "binning" {
        variable rawbinning
        return $rawbinning
      }
      default {
        return [detectorrawgetdatavalue $name]
      }
    }
  }
  
  ######################################################################

  proc detectorrawsetcooler {state} {
    switch $state {
      "on" {
        set value 1
      }
      "off" {
	set value 0
      }
      default {
        return "invalid cooler state \"$state\"."
      }
    }
    rawputsiimagecommandpacket "setcooler" $value
    rawgetsiimagedatapacket "setcooler"
    return "ok"
  }
  
  ######################################################################

  variable rawdetectortemperature      ""
  variable rawdetectorheatercurrent    ""
  variable rawcoldendtemperature       ""
  variable rawcoldendheatercurrent     ""
  variable rawpowersupplytemperature   ""
  variable rawchamberpressure          ""
  variable rawcompressorsupplypressure ""
  variable rawcompressorreturnpressure ""
  variable rawcompressorcurrent        ""
  variable rawcooler                   ""
  variable rawcoolerlowflow            ""
  variable rawcoolersettemperature     ""

  proc detectorrawgetdetectortemperature {} {
    variable rawdetectortemperature
    return $rawdetectortemperature
  }

  proc detectorrawgetchamberpressure {} {
    variable chamberpressure
    return $chamberpressure
  }

  ######################################################################

  variable rawreadmode ""

  proc detectorrawsetreadmode {newreadmode} {
    variable rawreadmode
    if {[string equal $newreadmode ""]} {
      set newreadmode 0
    }
    rawputsiimagecommandpacket "setcameramode" $newreadmode
    rawgetsiimagedatapacket "setcameramode"
    set rawreadmode $newreadmode
    return [detectorrawsetunbinnedwindow 0 0 0 0]
  }

  ######################################################################

  variable rawunbinnedwindowsx
  variable rawunbinnedwindowsy
  variable rawunbinnedwindownx
  variable rawunbinnedwindowny

  proc detectorrawsetunbinnedwindow {newunbinnedwindowsx newunbinnedwindowsy newunbinnedwindownx newunbinnedwindowny} {
  
    variable rawunbinnedwindowsx
    variable rawunbinnedwindowsy
    variable rawunbinnedwindownx
    variable rawunbinnedwindowny
    variable rawbinning
  
    set fullnx 4196
    set fullny 4112
  
    if {$newunbinnedwindownx == 0} {
      set newunbinnedwindownx $fullnx
    }
    if {$newunbinnedwindowny == 0} {
      set newunbinnedwindowny $fullny
    }

    # The SI CCD we have is four-ported. The raw window refers to the
    # window read from each port and must be the same for each port. In
    # order to stay sane, we impose the requirement that the total
    # window must be continuous. This means that windows must be
    # centered.

    if {2 * $newunbinnedwindowsx + $newunbinnedwindownx != $fullnx} {
      error "invalid window: not centered in x."
    }
    if {2 * $newunbinnedwindowsy + $newunbinnedwindowny != $fullny} {
      error "invalid window: not centered in y."
    }
    
    set rawunbinnedwindowsx $newunbinnedwindowsx
    set rawunbinnedwindowsy $newunbinnedwindowsy
    set rawunbinnedwindownx $newunbinnedwindownx
    set rawunbinnedwindowny $newunbinnedwindowny
    
    return [detectorrawsetbinning 1]
  }

  proc detectorrawgetunbinnedwindowsx {} {
    variable rawunbinnedwindowsx
    return $rawunbinnedwindowsx
  }

  proc detectorrawgetunbinnedwindowsy {} {
    variable rawunbinnedwindowsy
    return $rawunbinnedwindowsy
  }

  proc detectorrawgetunbinnedwindownx {} {
    variable rawunbinnedwindownx
    return $rawunbinnedwindownx
  }

  proc detectorrawgetunbinnedwindowny {} {
    variable rawunbinnedwindowny
    return $rawunbinnedwindowny
  }

  ######################################################################

  variable rawbinning

  proc detectorrawsetbinning {newbinning} {

    variable rawbinning
    
    variable rawunbinnedwindowsx
    variable rawunbinnedwindownx
    variable rawunbinnedwindowsy
    variable rawunbinnedwindowny

    # To be conservative, we reject binnings that are not commensurate
    # with the window.

    if {
      ($rawunbinnedwindownx / 2) % $newbinning != 0 ||
      ($rawunbinnedwindowny / 2) % $newbinning != 0
    } {
      error "binning is not commensurate with the window."
    }
    
    set rawbinning $newbinning

    # The SI CCD we have is four-ported, and the SI Image concept of a
    # window refers to each port. The SI Image interface wants sx and sy
    # in unbinned pixels but nx and ny in binned pixels. See §3.2.1 of
    # the SI Image manual.

    set sx $rawunbinnedwindowsx
    set sy $rawunbinnedwindowsy
    set nx [expr {$rawunbinnedwindownx / 2 / $rawbinning}]
    set ny [expr {$rawunbinnedwindowny / 2 / $rawbinning}]
    
    rawputsiimagecommandpacket "setformat" $sx $nx $rawbinning $sy $ny $rawbinning
    rawgetsiimagedatapacket "setformat"
    
    detectorrawsetpixnx [expr {$nx * 2}]
    detectorrawsetpixny [expr {$ny * 2}]

    return "ok"
  }

  ######################################################################
  
  proc detectorrawexpose {exposuretime shutter} {
    variable estimatedexposureend
    variable rawacquisitiontypeshutterclosed
    variable rawacquisitiontypeshutteropen
    rawputsiimagecommandpacket "setexposuretime" $exposuretime
    rawgetsiimagedatapacket "setexposuretime"
    if {[string equal $shutter "open"]} {
      rawputsiimagecommandpacket "setacquisitiontype" $rawacquisitiontypeshutteropen
      rawgetsiimagedatapacket "setacquisitiontype"
    } elseif {[string equal $shutter "closed"]} {
      rawputsiimagecommandpacket "setacquisitiontype" $rawacquisitiontypeshutterclosed
      rawgetsiimagedatapacket "setacquisitiontype"
    } else {
      error "detectorrawexpose: invalid shutter argument \"$shutter\"."
    }
    set estimatedexposureend [expr {[utcclock::seconds] + $exposuretime}]
    rawputsiimagecommandpacket "acquire"
    return "ok"
  }
  
  ######################################################################

  variable startreading
  
  proc detectorrawgetreadytoberead {} {

    variable rawacquiring

    log::debug "detectorrawgetreadytoberead: start."

    log::debug "detectorrawgetreadytoberead: rawacquiring is $rawacquiring."

#    if {!$rawacquiring} {
#      log::info "detectorrawgetreadytoberead: true."
#      return true
#    }
    
    rawputsiimagecommandpacket "inquireacquisitionstatus"
    set data [rawgetsiimagedatapacket "inquireacquisitionstatus"]
    set percentexposuredone [lindex $data 0]
    log::debug "detectorrawgetreadytoberead: percentexposuredone = $percentexposuredone."
    
    variable startreading
    if {$percentexposuredone == 100} {
      set startreading [utcclock::seconds]
    }
    
    if {$percentexposuredone == 100} {
      return true
    } else {
      return false
    }
  }
  
  ######################################################################
  
  proc detectorrawaugmentfitsheader {channel} {
    rawputsiimagecommandpacket "getimageheader" 1
    set data [rawgetsiimagedatapacket "getimageheader"]
    fitsheader::writecomment $channel "Start of SI Image section."
    foreach line $data {
      switch -glob $line {
        "SIMPLE  =*" -
        "BITPIX  =*" -
        "NAXIS   =*" -
        "NAXIS1  =*" -
        "NAXIS2  =*" -
        "BSCALE  =*" -
        "BZERO   =*" -
        "DATE-OBS=*" -
        "DATE    =*" -
        "TIME    =*" {
        }
        default {
          puts -nonewline $channel $line
        }
      }
    }
    fitsheader::writecomment $channel "End of SI Image section."
  }

  ######################################################################

  proc detectorrawread {} {

    variable rawacquiring
    variable rawretrieving

    log::debug "detectorrawread: waiting while reading the detector."
    while {true} {
      rawputsiimagecommandpacket "inquireacquisitionstatus"
      set data [rawgetsiimagedatapacket "inquireacquisitionstatus"]
      set percentreaddone [lindex $data 1]
      log::debug "detectorrawread: percentreaddone = $percentreaddone."
      if {!$rawacquiring && $percentreaddone == 100} {
        break
      }
      coroutine::after 100
    }
    log::debug "detectorrawread: finished reading the detector."
    
    variable startreading
    set end [utcclock::seconds]
    log::debug [format "detectorrawread: reading the detector took %.2f seconds." [expr {$end - $startreading}]]

    log::debug "detectorrawread: retrieving image."
    set start [utcclock::seconds]
    rawputsiimagecommandpacket "retrieveimage" 0
    log::debug "detectorrawread: getting packets."
    while {$rawretrieving} {
      set data [rawgetsiimageimagepacket]
      set result [detectorrawpixnexthex [binary encode hex $data]]
      if {![string equal $result "ok"]} {
        return $result
      }
    }
    set end [utcclock::seconds]
    log::debug [format "detectorrawread: retrieving the image took %.2f seconds." [expr {$end - $start}]]

    log::debug "detectorrawread: done."

    return "ok"
  }

  ######################################################################

  proc detectorrawcancel {} {

    variable rawacquiring
    
    if {$rawacquiring} {

      # There is a bug in the firmware of the PCIe card that causes the blue PC
      # to hang if an exposure is aborted. See email with
      # <dgilmore@specinst.com> in 2020/2021. The best thing we can do in this
      # circumstance is simply wait for the exposure to end and then read it
      # out.

      #rawputsiimagecommandpacket "terminateacquisition"
      #rawgetsiimagedatapacket "terminateacquisition"
      #set rawacquiring false
      
      if {![detectorrawgetreadytoberead]} {
        return "wait"
      } else {
        detectorrawread
        return "ok"
      }

    }

    return "ok"
  }
  
  ######################################################################

}

source [file join [directories::prefix] "lib" "tcs" "detector.tcl"]
