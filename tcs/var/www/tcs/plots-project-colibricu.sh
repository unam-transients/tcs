#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

# $Id: plots.sh 3524 2020-03-18 21:32:13Z Alan $

########################################################################

# Copyright © 2012, 2013, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

export PATH=/usr/local/bin:/usr/bin:/bin

cd "$(dirname "$0")"
mkdir -p plots
cd plots

if test -z "$when"
then
  when=$(date -u +%Y%m%d)
fi

for days in 1 4 30 120 360 1600
do

  lines=$(expr $days / 4)
  if test "$lines" = 0
  then
    lines=1
  fi

  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/C0-data.txt | sed -n "1,/$when/p" | tail -$days) | awk "NR % $lines == 0 { print; }"
  ) >C0.dat

  xrange=$(
    tclsh <<EOF
      set now [clock scan "$when" -timezone UTC]
      set min [clock format [expr {\$now - 24 * 3600 * ($days - 1)}] -format "%Y-%m-%d" -timezone UTC]
      set max [clock format [expr {\$now + 24 * 3600 * 1}] -format "%Y-%m-%d" -timezone UTC]
      puts "\[\"\$min\":\"\$max\"\]"
EOF
  )

  gnuplot <<EOF

    set rmargin 40
    set lmargin 10
    set tmargin 1
    set bmargin 0

    set xdata time
    set timefmt "%Y-%m-%d"
    set xrange $xrange
    set timefmt "%Y-%m-%dT%H:%M:%S"
    set grid back
    set grid xtics

    set style line  1 linewidth 1 linecolor  1
    set style line  2 linewidth 1 linecolor  2
    set style line  3 linewidth 1 linecolor  3
    set style line  4 linewidth 1 linecolor  4
    set style line  5 linewidth 1 linecolor  5
    set style line  6 linewidth 1 linecolor  6
    set style line  7 linewidth 1 linecolor  7
    set style line  8 linewidth 1 linecolor  8
    set style line  9 linewidth 1 linecolor  9
    set style line 10 linewidth 1 linecolor 10
    set style line 11 linewidth 1 linecolor 11

    set key outside

    set terminal pngcairo enhanced size 1200,1800
    set output "ccds.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-140:+60]
    set ytics -140,20,60
    set format y "%+.0f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "C0.dat" using 1:2  title "C0 Detector"     with lines linestyle 1, \
      "C0.dat" using 1:7  title "C0 Cold End"     with lines linestyle 2, \
      "C0.dat" using 1:11 title "C0 Power Supply" with lines linestyle 3

    set yrange [-111:-109]
    set ytics -111,0.5,-109
    set format y "%+.1f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "C0.dat" using 1:2  title "C0 Detector" with lines linestyle 1

    set yrange [1e-3:1000]
    set ylabel "Pressure (mbar)"
    set logscale y
    set ytics 1e-8,10,1000 logscale
    set format y "10^{%L}"
    set key on
    plot "C0.dat" using 1:8 title "C0 Chamber" with lines linestyle 1
    set nologscale
    set format y "%+g"

    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    set yrange [0:+400]
    set ytics 0,50,400
    set format y "%.0f"
    set ylabel "Pressure (psi)"
    set key on
    plot \
      "C0.dat" using 1:9  title "C0 Supply" with lines linestyle 1, \
      "C0.dat" using 1:10 title "C0 Return" with lines linestyle 2

    unset multiplot

EOF

  for component in ccds
  do
    mv $component.png.new $component-$days.png
  done

done
