########################################################################

# This file is part of the UNAM telescope control system.

# $Id: astrometry-test.tcl 3591 2020-06-09 22:33:22Z Alan $

########################################################################

# Copyright © 2009, 2010, 2011, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

source [file join "/usr/local/lib/tcs/packages.tcl"]

package require "config"

config::setdefaultvalue "astrometry" "longitude" "-115:28:00"
config::setdefaultvalue "astrometry" "latitude"  "+31:02:43.0"
config::setdefaultvalue "astrometry" "altitude"  "2790.0"

package require "astrometry"

puts [astrometry::degtohms [astrometry::dmstodeg "359 59 59.96"] 1 false]
puts [astrometry::degtohms [astrometry::dmstodeg "359 59 59.96"] 1 true]
puts [astrometry::degtohms [astrometry::hmstodeg "+18:08:30"] 1 true]

puts [astrometry::degtohms [astrometry::hmstodeg "+23:59:59.9"] 0 false]
puts [astrometry::degtodms [astrometry::dmstodeg "+359:59:59.9"] 0 false]

puts [expr {[astrometry::parseha "+12:00:00"] == [astrometry::pi]}]
puts [expr {[astrometry::parseha "-12:00:00"] == -[astrometry::pi]}]
puts [expr {[astrometry::parsedelta "+90:00:00"] == 0.5 * [astrometry::pi]}]
puts [expr {[astrometry::parsedelta "-90:00:00"] == -0.5 * [astrometry::pi]}]

puts [astrometry::formatdistance "180as"]

set alphalist [list [astrometry::parsealpha 350d] [astrometry::parsealpha  340d] [astrometry::parsealpha 10d] [astrometry::parsealpha 20d]]
set deltalist [list [astrometry::parsedelta  -10d] [astrometry::parsedelta -10d] [astrometry::parsedelta 10d] [astrometry::parsedelta 10d]]
puts [astrometry::formatalpha [astrometry::meanalpha $alphalist $deltalist]]
puts [astrometry::formatdelta [astrometry::meandelta $alphalist $deltalist]]

set alphalist [list [astrometry::parsealpha  0d] [astrometry::parsealpha 90d] [astrometry::parsealpha 180d] [astrometry::parsealpha 270d]]
set deltalist [list [astrometry::parsedelta 85d] [astrometry::parsedelta 85d] [astrometry::parsedelta  85d] [astrometry::parsedelta  85d]]
puts [astrometry::formatalpha [astrometry::meanalpha $alphalist $deltalist]]
puts [astrometry::formatdelta [astrometry::meandelta $alphalist $deltalist]]

set alphalist [list [astrometry::parsealpha  0d] [astrometry::parsealpha 180d]]
set deltalist [list [astrometry::parsedelta 80d] [astrometry::parsedelta 85d]]
puts [astrometry::formatalpha [astrometry::meanalpha $alphalist $deltalist]]
puts [astrometry::formatdelta [astrometry::meandelta $alphalist $deltalist]]

puts [astrometry::radtohms [astrometry::last] 1 false]

proc testobserved {alpha delta epoch} {
  set alpha [astrometry::hmstorad $alpha]
  set delta [astrometry::dmstorad $delta]
  puts -nonewline "[astrometry::radtohms $alpha 1 false] "
  puts -nonewline "[astrometry::radtodms $delta 0 true] "
  puts -nonewline "[astrometry::radtohms [astrometry::observedalpha $alpha $delta $epoch] 1 false] "
  puts -nonewline "[astrometry::radtodms [astrometry::observeddelta $alpha $delta $epoch] 0 true] "
  puts ""
}

testobserved [astrometry::radtohms [astrometry::last] 1 false] "+31:00:00" 2009.6
testobserved [astrometry::radtohms [astrometry::last] 1 false] "+31:00:00" 2009.6
testobserved "15:16:00" "+31:00:00" 2009.6
testobserved "07:16:00" "+31:00:00" 2009.6
testobserved [astrometry::radtohms [astrometry::last] 1 false] "+00:00:00" 2009.67

set alpha [astrometry::hmstorad "01:02:03"]
set delta [astrometry::dmstorad "04:05:06"]
puts [astrometry::radtohms [astrometry::precessedalpha $alpha $delta 2050 2000] 2 false]
puts [astrometry::radtodms [astrometry::precesseddelta $alpha $delta 2050 2000] 1 true ]

puts [astrometry::radtohms [astrometry::moonobservedalpha] 2 false]
puts [astrometry::radtodms [astrometry::moonobserveddelta] 1 true ]
puts [astrometry::radtohms [astrometry::sunobservedalpha] 2 false]
puts [astrometry::radtodms [astrometry::sunobserveddelta] 1 true ]

puts [astrometry::radtodeg [astrometry::latitude]]
puts [astrometry::radtodeg [astrometry::equatorialtozenithdistance -00:00:00 30:02:43.0]]

puts [astrometry::radtodeg [astrometry::parallacticangle -00:00:45 30:02:43.0]]
puts [astrometry::radtodeg [astrometry::parallacticangle +00:00:45 30:02:43.0]]

puts [astrometry::radtodeg [astrometry::parallacticangle -00:05:00 30:02:43.0]]
puts [astrometry::radtodeg [astrometry::parallacticangle +00:05:00 30:02:43.0]]


