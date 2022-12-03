########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2012, 2013, 2014, 2016, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

# Forget these tcllib package as they clash with our own packages.

package forget html
package forget log
package forget server
package forget coroutine

########################################################################

package ifneeded alert                 0.0 \
  [list source [file join [file dirname [info script]] alert.tcl]]
package ifneeded astrometry            0.0 \
  [list source [file join [file dirname [info script]] astrometry.tcl]]
package ifneeded block                 0.0 \
  [list source [file join [file dirname [info script]] block.tcl]]
package ifneeded ccd                   0.0 \
  [list source [file join [file dirname [info script]] ccd.tcl]]
package ifneeded ccdserver             0.0 \
  [list source [file join [file dirname [info script]] ccdserver.tcl]]
package ifneeded client                0.0 \
  [list source [file join [file dirname [info script]] client.tcl]]
package ifneeded config                0.0 \
  [list source [file join [file dirname [info script]] config.tcl]]
package ifneeded constraints           0.0 \
  [list source [file join [file dirname [info script]] constraints.tcl]]
package ifneeded controller            0.0 \
  [list source [file join [file dirname [info script]] controller.tcl]]
package ifneeded coversopentsi         0.0 \
  [list source [file join [file dirname [info script]] coversopentsi.tcl]]
package ifneeded coversserver          0.0 \
  [list source [file join [file dirname [info script]] coversserver.tcl]]
package ifneeded detectorandor         0.0 \
  [list source [file join [file dirname [info script]] detectorandor.tcl]]
package ifneeded detectordummy         0.0 \
  [list source [file join [file dirname [info script]] detectordummy.tcl]]
package ifneeded detectorfli           0.0 \
  [list source [file join [file dirname [info script]] detectorfli.tcl]]
package ifneeded detectorqsi           0.0 \
  [list source [file join [file dirname [info script]] detectorqsi.tcl]]
package ifneeded detectorsi            0.0 \
  [list source [file join [file dirname [info script]] detectorsi.tcl]]
package ifneeded directories           0.0 \
  [list source [file join [file dirname [info script]] directories.tcl]]
package ifneeded enclosurearts         0.0 \
  [list source [file join [file dirname [info script]] enclosurearts.tcl]]
package ifneeded enclosureplc          0.0 \
  [list source [file join [file dirname [info script]] enclosureplc.tcl]]
package ifneeded enclosureserver       0.0 \
  [list source [file join [file dirname [info script]] enclosureserver.tcl]]
package ifneeded environment           0.0 \
  [list source [file join [file dirname [info script]] environment.tcl]]
package ifneeded executor              0.0 \
  [list source [file join [file dirname [info script]] executor.tcl]]
package ifneeded executorcoatlioan     0.0 \
  [list source [file join [file dirname [info script]] executorcoatlioan.tcl]]
package ifneeded executorddotioan      0.0 \
  [list source [file join [file dirname [info script]] executorddotioan.tcl]]
package ifneeded executorserver        0.0 \
  [list source [file join [file dirname [info script]] executorserver.tcl]]
package ifneeded fans                  0.0 \
  [list source [file join [file dirname [info script]] fans.tcl]]
package ifneeded fansserver            0.0 \
  [list source [file join [file dirname [info script]] fansserver.tcl]]
package ifneeded filterwheeldummy      0.0 \
  [list source [file join [file dirname [info script]] filterwheeldummy.tcl]]
package ifneeded filterwheelfli        0.0 \
  [list source [file join [file dirname [info script]] filterwheelfli.tcl]]
package ifneeded filterwheelnull       0.0 \
  [list source [file join [file dirname [info script]] filterwheelnull.tcl]]
package ifneeded filterwheelqsi        0.0 \
  [list source [file join [file dirname [info script]] filterwheelqsi.tcl]]
package ifneeded fitfocus              0.0 \
  [list source [file join [file dirname [info script]] fitfocus.tcl]]
package ifneeded fitsheader            0.0 \
  [list source [file join [file dirname [info script]] fitsheader.tcl]]
package ifneeded focuserddoti          0.0 \
  [list source [file join [file dirname [info script]] focuserddoti.tcl]]
package ifneeded focuserfli            0.0 \
  [list source [file join [file dirname [info script]] focuserfli.tcl]]
package ifneeded focusergemini         0.0 \
  [list source [file join [file dirname [info script]] focusergemini.tcl]]
package ifneeded focusernull           0.0 \
  [list source [file join [file dirname [info script]] focusernull.tcl]]
package ifneeded fromjson              0.0 \
  [list source [file join [file dirname [info script]] fromjson.tcl]]
package ifneeded gcntan                0.0 \
  [list source [file join [file dirname [info script]] gcntan.tcl]]
package ifneeded gcntanserver          0.0 \
  [list source [file join [file dirname [info script]] gcntanserver.tcl]]
package ifneeded gpio                  0.0 \
  [list source [file join [file dirname [info script]] gpio.tcl]]  
package ifneeded heater                0.0 \
  [list source [file join [file dirname [info script]] heater.tcl]]
package ifneeded heaterserver          0.0 \
  [list source [file join [file dirname [info script]] heaterserver.tcl]]
package ifneeded html                  0.0 \
  [list source [file join [file dirname [info script]] html.tcl]]
package ifneeded htmlserver            0.0 \
  [list source [file join [file dirname [info script]] htmlserver.tcl]]
package ifneeded instrument            0.0 \
  [list source [file join [file dirname [info script]] instrument.tcl]]
package ifneeded instrumentserver      0.0 \
  [list source [file join [file dirname [info script]] instrumentserver.tcl]]
package ifneeded jsonrpc               0.0 \
  [list source [file join [file dirname [info script]] jsonrpc.tcl]]
package ifneeded log                   0.0 \
  [list source [file join [file dirname [info script]] log.tcl]]
package ifneeded lightsgpio            0.0 \
  [list source [file join [file dirname [info script]] lightsgpio.tcl]]
package ifneeded lightsplc             0.0 \
  [list source [file join [file dirname [info script]] lightsplc.tcl]]
package ifneeded lightspower          0.0 \
  [list source [file join [file dirname [info script]] lightspower.tcl]]
package ifneeded lightsserver          0.0 \
  [list source [file join [file dirname [info script]] lightsserver.tcl]]
package ifneeded moon                  0.0 \
  [list source [file join [file dirname [info script]] moon.tcl]]
package ifneeded moonserver            0.0 \
  [list source [file join [file dirname [info script]] moonserver.tcl]]
package ifneeded mountntm              0.0 \
  [list source [file join [file dirname [info script]] mountntm.tcl]]
package ifneeded mountopentsi          0.0 \
  [list source [file join [file dirname [info script]] mountopentsi.tcl]]
package ifneeded mountserver           0.0 \
  [list source [file join [file dirname [info script]] mountserver.tcl]]
package ifneeded opentsi               0.0 \
  [list source [file join [file dirname [info script]] opentsi.tcl]]
package ifneeded owsensors             0.0 \
  [list source [file join [file dirname [info script]] owsensors.tcl]]
package ifneeded owsensorsserver       0.0 \
  [list source [file join [file dirname [info script]] owsensorsserver.tcl]]
package ifneeded plccolibri            0.0 \
  [list source [file join [file dirname [info script]] plccolibri.tcl]]
package ifneeded plcserver             0.0 \
  [list source [file join [file dirname [info script]] plcserver.tcl]]
package ifneeded pointing              0.0 \
  [list source [file join [file dirname [info script]] pointing.tcl]]
package ifneeded power                 0.0 \
  [list source [file join [file dirname [info script]] power.tcl]]
package ifneeded powerserver           0.0 \
  [list source [file join [file dirname [info script]] powerserver.tcl]]
package ifneeded project              0.0 \
  [list source [file join [file dirname [info script]] project.tcl]]
package ifneeded queue                 0.0 \
  [list source [file join [file dirname [info script]] queue.tcl]]
package ifneeded coroutine             0.0 \
  [list source [file join [file dirname [info script]] coroutine.tcl]]
package ifneeded safetyswitch          0.0 \
  [list source [file join [file dirname [info script]] safetyswitch.tcl]]
package ifneeded safetyswitcharts      0.0 \
  [list source [file join [file dirname [info script]] safetyswitcharts.tcl]]
package ifneeded safetyswitchnone      0.0 \
  [list source [file join [file dirname [info script]] safetyswitchnone.tcl]]
package ifneeded safetyswitchplc       0.0 \
  [list source [file join [file dirname [info script]] safetyswitchplc.tcl]]
package ifneeded selector              0.0 \
  [list source [file join [file dirname [info script]] selector.tcl]]
package ifneeded selectorserver        0.0 \
  [list source [file join [file dirname [info script]] selectorserver.tcl]]
package ifneeded secondaryopentsi      0.0 \
  [list source [file join [file dirname [info script]] secondaryopentsi.tcl]]
package ifneeded secondaryoptec        0.0 \
  [list source [file join [file dirname [info script]] secondaryoptec.tcl]]
package ifneeded secondaryserver       0.0 \
  [list source [file join [file dirname [info script]] secondaryserver.tcl]]
package ifneeded sensors               0.0 \
  [list source [file join [file dirname [info script]] sensors.tcl]]
package ifneeded sensorsserver         0.0 \
  [list source [file join [file dirname [info script]] sensorsserver.tcl]]
package ifneeded server                0.0 \
  [list source [file join [file dirname [info script]] server.tcl]]
package ifneeded supervisor            0.0 \
  [list source [file join [file dirname [info script]] supervisor.tcl]]
package ifneeded supervisorserver      0.0 \
  [list source [file join [file dirname [info script]] supervisorserver.tcl]]
package ifneeded swift                 0.0 \
  [list source [file join [file dirname [info script]] swift.tcl]]
package ifneeded stack                 0.0 \
  [list source [file join [file dirname [info script]] stack.tcl]]
package ifneeded sun                   0.0 \
  [list source [file join [file dirname [info script]] sun.tcl]]
package ifneeded sunserver             0.0 \
  [list source [file join [file dirname [info script]] sunserver.tcl]]
package ifneeded target                0.0 \
  [list source [file join [file dirname [info script]] target.tcl]]
package ifneeded targetserver          0.0 \
  [list source [file join [file dirname [info script]] targetserver.tcl]]
package ifneeded telescope             0.0 \
  [list source [file join [file dirname [info script]] telescope.tcl]]
package ifneeded telescopecoatlioan    0.0 \
  [list source [file join [file dirname [info script]] telescopecoatlioan.tcl]]
package ifneeded telescopecolibriohp   0.0 \
  [list source [file join [file dirname [info script]] telescopecolibriohp.tcl]]
package ifneeded telescopeddotioan     0.0 \
  [list source [file join [file dirname [info script]] telescopeddotioan.tcl]]
package ifneeded telescopedummy        0.0 \
  [list source [file join [file dirname [info script]] telescopedummy.tcl]]
package ifneeded telescopeserver       0.0 \
  [list source [file join [file dirname [info script]] telescopeserver.tcl]]
package ifneeded telescopecontrolleropentsi  0.0 \
  [list source [file join [file dirname [info script]] telescopecontrolleropentsi.tcl]]
package ifneeded telescopecontrollerserver   0.0 \
  [list source [file join [file dirname [info script]] telescopecontrollerserver.tcl]]
package ifneeded tojson                0.0 \
  [list source [file join [file dirname [info script]] tojson.tcl]]
package ifneeded utcclock              0.0 \
  [list source [file join [file dirname [info script]] utcclock.tcl]]
package ifneeded visit                 0.0 \
  [list source [file join [file dirname [info script]] visit.tcl]]
package ifneeded weather               0.0 \
  [list source [file join [file dirname [info script]] weather.tcl]]
package ifneeded weatherserver         0.0 \
  [list source [file join [file dirname [info script]] weatherserver.tcl]]
