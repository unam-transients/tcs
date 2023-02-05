#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

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
  
  for component in weather sensors C0 C1 C2 C3 C4 C5
  do
    (
      cd /usr/local/var/tcs
      cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/${component}-data.txt | sed -n "1,/$when/p" | tail -$days) | awk "NR % $lines == 0 { print; }"
    ) >$component.dat
  done

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
    set output "building.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-30:+50]
    set ytics -40,10,50
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on

    plot \
      "weather.dat"  using 1:2   title "External"        with lines linestyle 1, \
      "sensors.dat"  using 2:3   title "Shed"            with lines linestyle 2, \
      "sensors.dat"  using 4:5   title "Rack"            with lines linestyle 3
    
    plot \
      "weather.dat"  using 1:2   title "External"        with lines linestyle 1, \
      "sensors.dat"  using 6:7   title "Enclosure"       with lines linestyle 2, \
      "sensors.dat"  using 8:9   title "Platform Box"    with lines linestyle 3, \
      "sensors.dat"  using 10:11 title "Instrument0 Box" with lines linestyle 4, \
      "sensors.dat"  using 12:13 title "Instrument1 Box" with lines linestyle 5

    set yrange [0:100]
    set ytics 0,10,100
    set format y "%g"
    set ylabel "RH (%)"
    set key on

    plot \
      "weather.dat"  using 1:(\$4*100)   title "External"        with lines linestyle 1, \
      "sensors.dat"  using 14:(\$15*100) title "Shed"            with lines linestyle 2
    
    plot \
      "weather.dat"  using 1:(\$4*100)   title "External"        with lines linestyle 1, \
      "sensors.dat"  using 16:(\$17*100) title "Enclosure"       with lines linestyle 2, \
      "sensors.dat"  using 18:(\$19*100) title "Platform Box"    with lines linestyle 3, \
      "sensors.dat"  using 20:(\$21*100) title "Instrument0 Box" with lines linestyle 4, \
      "sensors.dat"  using 22:(\$23*100) title "Instrument1 Box" with lines linestyle 5

    set yrange [0:100]
    set ytics 0,10,100
    set format y "%g"
    set ylabel "Light Level (%)"
    set key on

    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    plot \
      "sensors.dat"  using 24:(\$25*100) title "Shed"        with lines linestyle 1, \
      "sensors.dat"  using 26:(\$27*100) title "Enclosure"   with lines linestyle 2

    unset multiplot

    set terminal pngcairo enhanced size 1200,1800
    set output "ccds.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-30:+50]
    set ytics -40,10,50
    set format y "%+g"
    set ylabel "Temperature (C)"
    set key on

    plot \
      "C0.dat"       using 1:2  title "C0 Detector" with lines linestyle 1, \
      "C0.dat"       using 1:3  title "C0 Housing"  with lines linestyle 2, \
      "weather.dat"  using 1:2  title "External"    with lines linestyle 3, \
      "sensors.dat"  using 6:7  title "Enclosure"   with lines linestyle 4

    plot \
      "C1.dat"       using 1:2  title "C1 Detector" with lines linestyle 1, \
      "C1.dat"       using 1:3  title "C1 Housing"  with lines linestyle 2, \
      "weather.dat"  using 1:2  title "External"    with lines linestyle 3, \
      "sensors.dat"  using 6:7  title "Enclosure"   with lines linestyle 4

    plot \
      "C2.dat"       using 1:2  title "C2 Detector" with lines linestyle 1, \
      "C2.dat"       using 1:3  title "C2 Housing"  with lines linestyle 2, \
      "weather.dat"  using 1:2  title "External"    with lines linestyle 3, \
      "sensors.dat"  using 6:7  title "Enclosure"   with lines linestyle 4

    plot \
      "C3.dat"       using 1:2  title "C3 Detector" with lines linestyle 1, \
      "C3.dat"       using 1:3  title "C3 Housing"  with lines linestyle 2, \
      "weather.dat"  using 1:2  title "External"    with lines linestyle 3, \
      "sensors.dat"  using 6:7  title "Enclosure"   with lines linestyle 4

    plot \
      "C4.dat"       using 1:2  title "C4 Detector" with lines linestyle 1, \
      "C4.dat"       using 1:3  title "C4 Housing"  with lines linestyle 2, \
      "weather.dat"  using 1:2  title "External"    with lines linestyle 3, \
      "sensors.dat"  using 6:7  title "Enclosure"   with lines linestyle 4

    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    plot \
      "C5.dat"       using 1:2  title "C5 Detector" with lines linestyle 1, \
      "C5.dat"       using 1:3  title "C5 Housing"  with lines linestyle 2, \
      "weather.dat"  using 1:2  title "External"    with lines linestyle 3, \
      "sensors.dat"  using 6:7  title "Enclosure"   with lines linestyle 4

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

  for component in building ccds weather
  do
    mv $component.png.new $component-$days.png
  done

done
