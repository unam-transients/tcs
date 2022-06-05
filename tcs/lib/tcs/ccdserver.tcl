########################################################################

# This file is part of the UNAM telescope control system.

# $Id: ccdserver.tcl 3557 2020-05-22 18:23:30Z Alan $

########################################################################

# Copyright © 2013, 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "ccd"
package require "log"
package require "server"

package provide "ccdserver" 0.0

namespace eval "ccdserver" {

  variable svnid {$Id}

  ######################################################################

  proc slaveinitialize {} {
    ccd::initialize
  }

  proc slavestop {} {
    ccd::stop
  }

  proc slavereset {} {
    ccd::reset
  }

  proc slaveexpose {exposuretime {type "object"} {fitsfileprefix ""}} {
    ccd::expose $exposuretime $type $fitsfileprefix
  }
  
  proc slaveanalyze {type} {
    ccd::analyze $type
  }
  
  proc slavesetcooler {setting} {
    ccd::setcooler $setting
  }

  proc slavemovefilterwheel {position} {
    ccd::movefilterwheel $position
  }
  
  proc slavemovefocuser {position {setasinitial false}} {
    ccd::movefocuser $position $setasinitial
  }

  proc slavesetfocuser {position {setasinitial false}} {
    ccd::setfocuser $position $setasinitial
  }

  proc slavesetsoftwaregain {detectorsoftwaregain} {
    ccd::setsoftwaregain $detectorsoftwaregain
  }

  proc slavesetwindow {window} {
    ccd::setwindow $window
  }

  proc slavesetbinning {binning} {
    ccd::setbinning $binning
  }

  proc slavesetreadmode {readmode} {
    ccd::setreadmode $readmode
  }

  proc slavefocus {exposuretime {fitsfileprefix ""} {range 400} {step 50}} {
    ccd::focus $exposuretime $fitsfileprefix $range $step
  }

  proc slavemapfocus {exposuretime {fitsfileprefix ""} {range 400} {step 50}} {
    ccd::mapfocus $exposuretime $fitsfileprefix $range $step
  }

  proc slavecorrect {alpha delta equinox} {
    ccd::correct $alpha $delta $equinox
  }
  
  proc configureslave {slave} {
    interp alias $slave initialize      {} ccdserver::slaveinitialize
    interp alias $slave stop            {} ccdserver::slavestop
    interp alias $slave reset           {} ccdserver::slavereset
    interp alias $slave expose          {} ccdserver::slaveexpose
    interp alias $slave analyze         {} ccdserver::slaveanalyze
    interp alias $slave setcooler       {} ccdserver::slavesetcooler
    interp alias $slave movefilterwheel {} ccdserver::slavemovefilterwheel
    interp alias $slave movefocuser     {} ccdserver::slavemovefocuser
    interp alias $slave setfocuser      {} ccdserver::slavesetfocuser
    interp alias $slave setsoftwaregain {} ccdserver::slavesetsoftwaregain
    interp alias $slave setwindow       {} ccdserver::slavesetwindow
    interp alias $slave setbinning      {} ccdserver::slavesetbinning
    interp alias $slave setreadmode     {} ccdserver::slavesetreadmode
    interp alias $slave focus           {} ccdserver::slavefocus
    interp alias $slave mapfocus        {} ccdserver::slavemapfocus
    interp alias $slave correct         {} ccdserver::slavecorrect
  }
  
  ######################################################################

  proc start {} {
    ccd::start
    server::listen $ccd::identifier ccdserver::configureslave
  }

  ######################################################################

}
