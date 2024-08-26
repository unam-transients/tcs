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
  when=$(date -u +%Y%m%dT%H)
fi
whendate=$(echo $when | sed 's/T.*//')

for days in 1 4 30 120 360 1600
do

  lines=$(expr $days / 4)
  if test "$lines" = 0
  then
    lines=1
  fi

  if test $days = 1 || test $days = 4
  then
    xrange=$(
      tclsh <<EOF
        set now [clock scan "$when" -format "%Y%m%dT%H" -timezone UTC]
        set min [clock format [expr {\$now - (24 * $days - 1) * 3600}] -format "%Y-%m-%dT%H" -timezone UTC]
        set max [clock format [expr {\$now + 1 * 3600}] -format "%Y-%m-%dT%H" -timezone UTC]
        puts "\[\"\$min\":\"\$max\"\]"
EOF
    )
  else
    xrange=$(
      tclsh <<EOF
        set now [clock scan "$whendate" -format "%Y%m%d" -timezone UTC]
        set min [clock format [expr {\$now - 24 * 3600 * ($days - 1)}] -format "%Y-%m-%dT00" -timezone UTC]
        set max [clock format [expr {\$now + 24 * 3600 * 1}] -format "%Y-%m-%dT00" -timezone UTC]
        puts "\[\"\$min\":\"\$max\"\]"
EOF
    )
  fi
    
  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/C0-data.txt | sed -n "1,/$whendate/p" | tail -$(expr $days + 1)) | awk "NR % $lines == 0 { print; }"
  ) >C0.dat

  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/sensors-data.txt | sed -n "1,/$whendate/p" | tail -$(expr $days + 1)) | awk "NR % $lines == 0 { print; }"
  ) >sensors.dat

  (
    cd /usr/local/var/tcs
    cat $(ls [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/log/weather-data.txt | sed -n "1,/$whendate/p" | tail -$(expr $days + 1)) | awk "NR % $lines == 0 { print; }"
  ) >weather.dat

  gnuplot <<EOF

    set rmargin 40
    set lmargin 10
    set tmargin 1
    set bmargin 0

    set xdata time
    set timefmt "%Y-%m-%dT%H"
    set xrange $xrange
    set timefmt "%Y-%m-%dT%H:%M:%S"
    set grid back
    set grid xtics

    set style line  1 linewidth 1 linecolor  1 pointtype 7 pointsize 0.3
    set style line  2 linewidth 1 linecolor  2 pointtype 7 pointsize 0.3
    set style line  3 linewidth 1 linecolor  3 pointtype 7 pointsize 0.3
    set style line  4 linewidth 1 linecolor  4 pointtype 7 pointsize 0.3
    set style line  5 linewidth 1 linecolor  5 pointtype 7 pointsize 0.3
    set style line  6 linewidth 1 linecolor  7 pointtype 7 pointsize 0.3
    set style line  7 linewidth 1 linecolor  8 pointtype 7 pointsize 0.3
    set style line  8 linewidth 1 linecolor  9 pointtype 7 pointsize 0.3
    set style line  9 linewidth 1 linecolor 10 pointtype 7 pointsize 0.3
    set style line 10 linewidth 1 linecolor 11 pointtype 7 pointsize 0.3
    set style line 11 linewidth 1 linecolor 12 pointtype 7 pointsize 0.3

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
      "C0.dat" using 1:2  title "C0 Detector"     with points linestyle 1, \
      "C0.dat" using 1:7  title "C0 Cold End"     with points linestyle 2, \
      "C1.dat" using 1:2  title "C1 Detector"     with points linestyle 3, \
      "C1.dat" using 1:7  title "C1 Cold End"     with points linestyle 4
      

    set yrange [-111:-109]
    set ytics -111,0.5,-109
    set format y "%+.1f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "C0.dat" using 1:2  title "C0 Detector" with points linestyle 1, \
      "C1.dat" using 1:2  title "C1 Detector" with points linestyle 3

#    set yrange [1e-3:1000]
#    set ylabel "Pressure (Torr)"
#    set logscale y
#    set ytics 1e-8,10,1000 logscale
#    set format y "10^{%L}"
#    set key on
#    plot "C0.dat" using 1:(\$8/1.33) title "C0 Chamber" with points linestyle 1
#    set nologscale

    set format y "%+g"
    set yrange [1e-3:1000]
    set ylabel "Pressure (mbar)"
    set logscale y
    set ytics 1e-8,10,1000 logscale
    set format y "10^{%L}"
    set key on
    plot \
      "C0.dat" using 1:8 title "C0 Chamber" with points linestyle 1, \
      "C1.dat" using 1:8 title "C1 Chamber" with points linestyle 2
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
      "C0.dat" using 1:9  title "C0 Supply" with points linestyle 1, \
      "C0.dat" using 1:10 title "C0 Return" with points linestyle 2, \
      "C1.dat" using 1:9  title "C1 Supply" with points linestyle 3, \
      "C1.dat" using 1:10 title "C1 Return" with points linestyle 4
      
    unset multiplot

    set terminal pngcairo enhanced size 1200,1800
    set output "instrument.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-30:+40]
    set ytics -30,10,40
    set format y "%+.0f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 2:3   title "Instrument External" with points linestyle 1, \
      "sensors.dat" using 10:11 title "Instrument Internal" with points linestyle 2, \
      "sensors.dat" using 14:15 title "Instrument Tunnel"   with points linestyle 3, \
      "sensors.dat" using 18:19 title "Close Electronics"   with points linestyle 4
      
    set yrange [0:100]
    set ytics 0,10,100
    set format y "%g"
    set ylabel "RH (%)"
    set key on
    plot \
      "sensors.dat" using 4:(\$5*100)   title "Instrument External" with points linestyle 1, \
      "sensors.dat" using 12:(\$13*100) title "Instrument Internal" with points linestyle 2, \
      "sensors.dat" using 16:(\$17*100) title "Instrument Tunnel"   with points linestyle 3, \
      "sensors.dat" using 20:(\$21*100) title "Close Electronics"   with points linestyle 4
      
    set yrange [0:2000]
    set ytics 0,200,2000
    set format y "%.0f"
    set ylabel "Light Level (lux)"
    set key on
    plot \
      "sensors.dat" using 8:9   title "Instrument External" with points linestyle 1
      
    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    set yrange [900:1000]
    set ytics 900,10,1000
    set format y "%.0f"
    set ylabel "Pressure (mbar)"
    set key on
    plot \
      "sensors.dat" using 6:7   title "Instrument External" with points linestyle 1
      
    unset multiplot

    set terminal pngcairo enhanced size 1200,1800
    set output "building.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-15:+30]
    set ytics -15,5,30
    set format y "%+.0f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 2:3   title "External"       with points linestyle 1, \
      "sensors.dat" using 4:5   title "Observing Room" with points linestyle 2, \
      "sensors.dat" using 34:35 title "Column"         with points linestyle 3, \
      "sensors.dat" using 36:37 title "Control Room"   with points linestyle 4
      
    set yrange [-10:+10]
    set ytics -10,5,10
    set format y "%+.0f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 4:(\$3-\$5)  title "External - Observing Room"    with points linestyle 1, \
      "sensors.dat" using 4:(\$35-\$5) title "Column - Observing Room"      with points linestyle 3

    set yrange [-15:+50]
    set ytics -15,10,50
    set format y "%+.0f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 2:3   title "External"                with points linestyle 1, \
      "sensors.dat" using 4:5   title "Observing Room"          with points linestyle 2, \
      "sensors.dat" using 36:37 title "Control Room"            with points linestyle 4, \
      "sensors.dat" using 38:39 title "Telescope Cabinet"       with points linestyle 5, \
      "sensors.dat" using 58:59 title "PLC Cabinet"             with points linestyle 6, \
      "sensors.dat" using 60:61 title "Weather Station Cabinet" with points linestyle 7
      
    set yrange [0:100]
    set ytics 0,10,100
    set format y "%g"
    set ylabel "RH (%)"
    set key on
    plot \
      "sensors.dat" using 40:(\$41*100) title "External"                     with points linestyle 1, \
      "sensors.dat" using 42:(\$43*100) title "Observing Room"              with points linestyle 2

    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    set yrange [0:0.5]
    set ytics 0,0.1,0.5
    set format y "%g"
    set ylabel "Light Level"
    set key on
    plot \
      "sensors.dat" using 54:55 title "Observing Room"              with points linestyle 2, \
      "sensors.dat" using 56:57 title "Control Room"                with points linestyle 4

    unset multiplot

    set terminal pngcairo enhanced size 1200,1800
    set output "telescope.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-15:30]
    set ytics -15,5,30
    set format y "%+.0f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 2:3   title "External"       with points linestyle 1, \
      "sensors.dat" using 4:5   title "Observing Room" with points linestyle 2, \
      "sensors.dat" using 10:11 title "M1"             with points linestyle 3, \
      "sensors.dat" using 14:15 title "M2"             with points linestyle 4, \
      "sensors.dat" using 16:17 title "M3"             with points linestyle 5, \

    set yrange [-10:+10]
    set ytics -10,5,10
    set format y "%+.0f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 10:(\$11-\$5) title "M1 - Observing Room" with points linestyle 3, \
      "sensors.dat" using 14:(\$15-\$5) title "M2 - Observing Room" with points linestyle 4, \
      "sensors.dat" using 16:(\$17-\$5) title "M3 - Observing Room" with points linestyle 5
      
    set format x "%Y%m%dT%H"
    set xtics rotate by 90 right
    set xlabel "UTC"

    set yrange [-15:+30]
    set ytics -15,5,30
    set format y "%+.0f"
    set ylabel "Temperature (C)"
    set key on
    plot \
      "sensors.dat" using 2:3   title "External"       with points linestyle 1, \
      "sensors.dat" using 4:5   title "Observing Room" with points linestyle 2, \
      "sensors.dat" using 12:13 title "M1 Cell"        with points linestyle 3, \
      "sensors.dat" using 18:19 title "Spider 1"       with points linestyle 4, \
      "sensors.dat" using 20:21 title "Spider 2"       with points linestyle 5, \
      "sensors.dat" using 22:23 title "Pivot Box 1"    with points linestyle 6, \
      "sensors.dat" using 24:25 title "Pivot Box 2"    with points linestyle 7, \
      "sensors.dat" using 26:27 title "Front Ring 1"   with points linestyle 8, \
      "sensors.dat" using 28:29 title "Front Ring 2"   with points linestyle 9, \
      "sensors.dat" using 30:31 title "Fork Arm 1"     with points linestyle 10, \
      "sensors.dat" using 32:33 title "Fork Arm 2"     with points linestyle 11

    unset multiplot

    set terminal pngcairo enhanced size 1200,1800
    set output "weather.png.new"

    set multiplot layout 7,1

    set format x ""
    set xlabel ""

    set yrange [-10:40]
    set ytics -10,5,40
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

  for component in ccds instrument building telescope weather
  do
    mv $component.png.new $component-$days.png
  done

done
