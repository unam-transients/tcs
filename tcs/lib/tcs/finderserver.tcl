########################################################################

# This file is part of the UNAM telescope control system.

# $Id: finderserver.tcl 3557 2020-05-22 18:23:30Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2013, 2014, 2015, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "finder"
package require "log"
package require "server"

package provide "finderserver" 0.0

namespace eval "finderserver" {

  variable svnid {$Id}

  ######################################################################

  proc slaveinitialize {} {
    finder::initialize
  }

  proc slavestop {} {
    finder::stop
  }

  proc slavereset {} {
    finder::reset
  }

  proc slaveexpose {exposuretime {type "object"}} {
    finder::expose $exposuretime $type
  }
  
  proc slavesetcooler {setting} {
    finder::setcooler $setting
  }

  proc slavemovefilterwheel {position} {
    finder::movefilterwheel $position
  }
  
  proc slavemovefocuser {position {setasinitial false}} {
    finder::movefocuser $position $setasinitial
  }

  proc slavesetsoftwaregain {detectorsoftwaregain} {
    finder::setsoftwaregain $detectorsoftwaregain
  }

  proc slavesetbinning {position} {
    finder::setbinning $position
  }

  proc slavefocus {{exposuretime 0.0} {range 0} {step 0}} {
    finder::focus $exposuretime $range $step
  }

  proc slavecorrect {alpha delta equinox} {
    finder::correct $alpha $delta $equinox
  }

  proc configureslave {slave} {
    interp alias $slave initialize      {} finderserver::slaveinitialize
    interp alias $slave stop            {} finderserver::slavestop
    interp alias $slave reset           {} finderserver::slavereset
    interp alias $slave expose          {} finderserver::slaveexpose
    interp alias $slave setcooler       {} finderserver::slavesetcooler
    interp alias $slave movefilterwheel {} finderserver::slavemovefilterwheel
    interp alias $slave movefocuser     {} finderserver::slavemovefocuser
    interp alias $slave setsoftwaregain {} finderserver::slavesetsoftwaregain
    interp alias $slave setbinning      {} finderserver::slavesetbinning
    interp alias $slave focus           {} finderserver::slavefocus
    interp alias $slave correct         {} finderserver::slavecorrect
  }
  
  ######################################################################

  proc start {} {
    finder::start
    server::listen $finder::identifier finderserver::configureslave
  }

  ######################################################################

}
