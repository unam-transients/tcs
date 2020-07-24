#!/bin/sh

rm -f 2017A-0010-*

targetid=100
sed '/^#/d' <<EOF1 |
SA92-500        00:55:58.0 +01:10:25
SA92-SF2        00:56:06.7 +00:52:03
F-24            02:35:17.0 +03:42:54
PG0231+051      02:23:36.9 +13:27:47
SA95-112        03:53:40.1 -00:01:11
SA95-SF3        03:53:35.0 -00:01:07
GD-71           05:52:23.2 +15:53:29
SA98-SF1        06:51:59.0 -00:22:50
SA98-SF2        06:52:21.2 -00:18:38
Ru149           07:24:15.2 -00:32:12
Ru152           07:29:59.9 -02:05:38
PG0942-029      09:45:11.5 -03:08:04
SA101-341       09:57:29.8 -00:21:54
GD-108          10:00:47.8 -07:32:41
G163-50C        11:07:33.8 -05:14:20
SA104-SF1       12:43:07.9 -00:30:50
PG1323-086      13:25:52.4 -08:49:47
PG1407-013      14:10:30.0 -01:27:40
PG1525-071      15:28:14.0 -07:15:35
PG1528+062      15:30:49.9 +06:00:56
SA107-SF1       15:38:46.8 -00:20:48
SA107-SF2       15:39:04.6 -00:15:19
PG1633+099      16:35:34.6 +09:48:23
PG1657+078      16:59:31.3 +07:43:04
SA110-315       18:43:52.8 +00:00:49
SA110-SF2       18:42:50.0 +00:05:47
SA110-SF3       18:43:09.2 +00:29:26
Mark-A          20:43:58.7 -10:46:24
G93-48          21:52:17.8 +02:22:23
SA113-SF1       21:40:52.9 +00:24:49
SA113-SF3       21:42:27.1 +00:41:01
SA113-SF4       21:43:30.7 +00:16:59
PG2213-006      22:16:20.6 -00:19:57
GD-246          23:12:24.2 +10:47:43
EOF1
while read name alpha delta
do
  file=$(printf "2017A-0010-%03d" $targetid)
  cat <<EOF2 >$file
proposal::setidentifier "2017A-0010"
block::setidentifier "$targetid"
visit::setidentifier "0"
visit::setname "Landolt standard field -- $name"
block::settotalexposures 0
visit::settargetcoordinates equatorial $alpha $delta 2000

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [minairmass 1.0] &&
    [maxairmass 1.5] &&
    [minmoonseparation "15d"] &&
    [onfavoredsideforswift] &&
    [maxfocusdelay 1200] &&
    ([maxha "-1h"] || [minha "+0h"])
  }]
}

proc EXECUTE {args} {

  set exposuretime       30
  set exposuresperdither 1
  set filters            {BB BV BR BI w}
  
  executor::setsecondaryoffset 0
  executor::track

  executor::setreadmode 1MHz
  executor::setwindow "default"
  executor::setbinning 2

  executor::waituntiltracking

  foreach {eastoffset northoffset} {
      0as   0as
    +30as +30as
    +30as -30as
    -30as -30as
    -30as +30as
      0as -30as
    +30as   0as
      0as +30as
    -30as   0as
  } {
    executor::offset \$eastoffset \$northoffset "default"
    executor::waituntiltracking
    foreach filter \$filters {
      executor::movefilterwheel \$filter
      set i 0
      while {\$i < \$exposuresperdither} {
        executor::expose object \$exposuretime
        incr i
      }
    }
  }

  return true
}
  
EOF2
  targetid=$(expr $targetid + 1)
done
