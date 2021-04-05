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
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/weather-data.txt | sed -n "1,/$when/p" | tail -$days) | awk "NR % $lines == 0 { print; }"
  ) >weather.dat

  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/sensors-data.txt | sed -n "1,/$when/p" | tail -$days) | awk "NR % $lines == 0 { print; }"
  ) >sensors.dat

  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/nefinder-data.txt | sed -n "1,/$when/p" | tail -$days) | awk "NR % $lines == 0 { print; }"
  ) >nefinder.dat

  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/sefinder-data.txt | sed -n "1,/$when/p" | tail -$days) | awk "NR % $lines == 0 { print; }"
  ) >sefinder.dat

  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/cryostat-data.txt | sed -n "1,/$when/p" | tail -$days) | awk "NR % $lines == 0 { print; }"
  ) | awk '
  {
    print $1, $3, $5, $7, $9, $11, $13, $15, $17, $19, $21, $23;
  }
  ' >cryostat.dat

  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/C0-data.txt | sed -n "1,/$when/p" | tail -$days) | awk "NR % $lines == 0 { print; }"
  ) >C0.dat

  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/C1-data.txt | sed -n "1,/$when/p" | tail -$days) | awk "NR % $lines == 0 { print; }"
  ) >C1.dat

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
    set output "cryostat.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [0:25]
    set ytics 0,5,25
    set format y "%g"
    set ylabel "Current (A)"
    set key on
    plot \
      "sensors.dat" using 30:31            title "Compressor"  with lines linestyle 1

    set yrange [-20:30]
    set ytics -20,10,30
    set ylabel "Temperature (C)"
    set format y "%+g"
    set key on
    plot \
      "sensors.dat" using 14:15            title "Dome"                with lines linestyle 1, \
      ""            using 32:33            title "Compressor Cabinet"  with lines linestyle 2, \
      ""            using 48:49            title "Compressor External" with lines linestyle 3, \
      ""            using 34:35            title "Compressor Supply"   with lines linestyle 4, \
      ""            using 36:37            title "Compressor Return"   with lines linestyle 5, \
      ""            using 38:39            title "Cryostat External"   with lines linestyle 6, \
      ""            using 40:41            title "Cold Head External"  with lines linestyle 7

    set yrange [-5:15]
    set ytics -5,5,15
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 1:(\$33-\$15)  title "Compressor Cabinet - Dome"      with lines linestyle 1, \
      ""            using 1:(\$39-\$33) title "Compressor - Compressor Cabinet" with lines linestyle 2, \
      ""            using 1:(\$37-\$35) title "Compressor Return - Supply"      with lines linestyle 3, \
      ""            using 1:(\$39-\$15)  title "Cryostat - Dome"                with lines linestyle 4, \
      ""            using 1:(\$41-\$15)  title "Cold Head - Dome"               with lines linestyle 5

    set yrange [0:350]
    set ytics 0,50,350
    set format y "%g"
    set ylabel "Temperature (K)"
    set key on
    plot \
      "cryostat.dat" using 1:2  title "Cold Finger (A)"    with lines linestyle 1, \
      ""             using 1:3  title "Cold Plate (B)"     with lines linestyle 2, \
      ""             using 1:4  title "JADE2 1 (C1)"       with lines linestyle 7, \
      ""             using 1:5  title "JADE2 2 (C2)"       with lines linestyle 8, \
      ""             using 1:6  title "ASIC 1 (C3)"        with lines linestyle 3, \
      ""             using 1:7  title "ASIC 2 (C4)"        with lines linestyle 4, \
      ""             using 1:8  title "Detector 1 (D1)"    with lines linestyle 5, \
      ""             using 1:9  title "Detector 2 (D2)"    with lines linestyle 9, \
      ""             using 1:10 title "Cold Shield 1 (D3)" with lines linestyle 7, \
      ""             using 1:11 title "Cold Shield 2 (D4)" with lines linestyle 8

    set yrange [20:90]
    set ytics 20,10,90
    set format y "%g"
    set ylabel "Temperature (K)"
    set key on
    plot \
      "cryostat.dat" using 1:2  title "Cold Finger (A)"    with lines linestyle 1, \
      ""             using 1:3  title "Cold Plate (B)"     with lines linestyle 2, \
      ""             using 1:8  title "Detector 1 (D1)"    with lines linestyle 3, \
      ""             using 1:9  title "Detector 2 (D2)"    with lines linestyle 4

    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    set yrange [1e-8:1000]
    set ylabel "Pressure (mbar)"
    set logscale y
    set ytics 1e-8,10,1000 logscale
    set format y "10^{%L}"
    set key on
    plot "cryostat.dat" using 1:12 title "Cryostat" with lines linestyle 1
    set nologscale
    set format y "%+g"

    unset multiplot

    set terminal pngcairo enhanced size 1200,1800
    set output "building.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-20:40]
    set ytics -20,10,40
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "weather.dat" using 1:2   title "External"           with lines linestyle  1, \
      "sensors.dat" using 2:3   title "Control Room"       with lines linestyle  2, \
      ""            using 4:5   title "Bathroom"           with lines linestyle  3, \
      ""            using 6:7   title "Machine Room"       with lines linestyle  4, \
      ""            using 8:9   title "Dark Room"          with lines linestyle  5, \
      ""            using 10:11 title "Cistern Room"       with lines linestyle  6, \
      ""            using 12:13 title "Hallway"            with lines linestyle  7, \
      ""            using 14:15 title "Dome"               with lines linestyle  8

    set yrange [-20:40]
    set ytics -20,10,40
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "weather.dat" using 1:2   title "External"           with lines linestyle 1, \
      "sensors.dat" using 14:15 title "Dome"               with lines linestyle 2, \
      ""            using 28:29 title "Dome Cabinet"       with lines linestyle 3, \
      ""            using 32:33 title "Compressor Cabinet" with lines linestyle 4

    set yrange [-10:20]
    set ytics -10,5,20
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 1:(\$29-\$15) title "Dome Cabinet - Dome"       with lines linestyle 1, \
      ""            using 1:(\$33-\$15) title "Compressor Cabinet - Dome" with lines linestyle 2

    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    set yrange [0:0.4]
    set ytics 0.0,0.1,0.4
    set format y "%g"
    set ylabel "Light Level"
    set key on
    plot \
      "sensors.dat" using 16:17 title "Control Room" with lines linestyle 1, \
      ""            using 18:19 title "Bathroom"     with lines linestyle 2, \
      ""            using 20:21 title "Machine Room" with lines linestyle 3, \
      ""            using 22:23 title "Dark Room"    with lines linestyle 4, \
      ""            using 24:25 title "Hallway"      with lines linestyle 5, \
      ""            using 26:27 title "Dome"         with lines linestyle 7

    unset multiplot

    set terminal pngcairo enhanced size 1200,1800
    set output "ccds.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-50:+50]
    set ytics -40,10,50
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "nefinder.dat" using 1:2  title "NE Finder Detector" with lines linestyle 1, \
      "sefinder.dat" using 1:2  title "SE Finder Detector" with lines linestyle 2, \
      "C0.dat"       using 1:2  title "C0 Detector"        with lines linestyle 3, \
      "C1.dat"       using 1:2  title "C1 Detector"        with lines linestyle 4

    set yrange [-20:50]
    set ytics -20,10,50
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "weather.dat"  using 1:2   title "External"           with lines linestyle 1, \
      "sensors.dat"  using 42:43 title "CCD Coolant"        with lines linestyle 2, \
      ""             using 14:15 title "Dome"               with lines linestyle 3, \
      "nefinder.dat" using 1:3   title "NE Finder Housing"  with lines linestyle 4, \
      "sefinder.dat" using 1:3   title "SE Finder Housing"  with lines linestyle 5, \
      "C0.dat"       using 1:3   title "C0 Housing"         with lines linestyle 6, \
      "C1.dat"       using 1:3   title "C1 Housing"         with lines linestyle 7

    set yrange [-20:50]
    set ytics -20,10,50
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "weather.dat" using 1:2   title "External"         with lines linestyle 1, \
      "sensors.dat" using 42:43 title "CCD Coolant"      with lines linestyle 2, \
      ""            using 6:7   title "Machine Room"     with lines linestyle 3

    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    set yrange [0:50]
    set ytics 0,10,50
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 42:43 title "CCD Coolant"      with lines linestyle 1, \
      ""            using 6:7   title "Machine Room"     with lines linestyle 2, \
      ""            using 44:45 title "Finder CCD Pump"  with lines linestyle 3, \
      ""            using 46:47 title "Science CCD Pump" with lines linestyle 4

    unset multiplot

    set terminal pngcairo enhanced size 1200,1800
    set output "weather.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-20:30]
    set ytics -20,5,30
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "weather.dat" using 1:2 title "Temperature" with lines linestyle 1, \
      ""            using 1:6 title "Dewpoint"    with lines linestyle 2

    set yrange [0:100]
    set ytics 0,10,100
    set format y "%g"
    set ylabel "RH (%)"
    set key on
    plot \
      "weather.dat" using 1:(\$4*100) title "Humidity" with lines linestyle 1

    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    set yrange [0:100]
    set ytics 0,10,100
    set format y "%g"
    set ylabel "Wind Speed (km/h)"
    set key on
    plot \
      "weather.dat" using 1:10 title "Wind Average Speed"  with lines linestyle 1, \
      ""            using 1:11 title "Wind Gust Speed" with lines linestyle 2

    unset multiplot

EOF

  for component in building ccds cryostat weather
  do
    mv $component.png.new $component-$days.png
  done

done
