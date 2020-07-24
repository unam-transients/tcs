#!/bin/sh

# These are VT ≈ 12.0 and VT ≈ 7.5 Tycho 2 stars spaced every hour at +25d.
# They were selected using http://vizier.u-strasbg.fr/.

rm -f focus-?? refocus-??

while read suffix visitidentifier tyc alpha delta TYC ALPHA DELTA
do
  cat <<EOF >focus-$suffix
# focus-$suffix

proposal::setidentifier "2017A-0004"
visit::setidentifier "$visitidentifier"
visit::setname "initial focusing on TYC-$TYC and TYC-$tyc"
block::settotalexposures 0
visit::settargetcoordinates equatorial $ALPHA $DELTA 2000

proc SELECTABLE {args} {
  return [expr {
    [minfocusdelay [expr {4 * 3600}]] &&
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [minha "-03:00:00"] &&
    [maxha "+01:00:00"] &&
    [minmoonseparation "15d"]
  }]
}

proc EXECUTE {args} {

  setsecondaryoffset 0

  visit::settargetcoordinates equatorial $ALPHA $DELTA 2000
  track
  setbinning 4
  setreadmode 6MHz
  movefilterwheel "BI"
  focussecondary C0 10 250 25 false
  correctpointing C0 30

  visit::settargetcoordinates equatorial $alpha $delta 2000
  track
  setbinning 1
  setreadmode 6MHz
  movefilterwheel "BI"
  focussecondary C0 10 100 5 false
  focussecondary C0 10 100 5 true

  visit::settargetcoordinates fixed -1h +30d 2000
  tracktopocentric
  setbinning 1
  setreadmode 1MHz
  movefilterwheel "W"
  correctpointing C0 30

  visit::settargetcoordinates fixed +1h +30d 2000
  tracktopocentric
  setbinning 1
  setreadmode 1MHz
  movefilterwheel "W"
  correctpointing C0 30

  setfocused

  return false
}
EOF
  cat <<EOF >refocus-$suffix
# refocus-$suffix

proposal::setidentifier "2017A-0004"
visit::setidentifier "$visitidentifier"
visit::setname "focusing on TYC-$tyc"
block::settotalexposures 0
visit::settargetcoordinates equatorial $alpha $delta 2000

proc SELECTABLE {args} {
  return [expr {
    [minfocusdelay 1200] &&
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [minha "-03:00:00"] &&
    [maxha "+01:00:00"] &&
    [minmoonseparation "15d"]
  }]
}

proc EXECUTE {args} {
  setsecondaryoffset 0
  setreadmode 6MHz
  setbinning 1
  track
  movefilterwheel "BI"
  focussecondary C0 10 100 5 true
  setfocused
  return false
}
EOF

cat <<EOF >donut-$suffix
# donut-$suffix

proposal::setidentifier "2017A-0007"
visit::setidentifier "$visitidentifier"
visit::setname "donut images of TYC-$TYC"
block::settotalexposures 0
visit::settargetcoordinates equatorial $ALPHA $DELTA 2000

proc SELECTABLE {args} {
  return [expr {
    [maxfocusdelay 1200] &&
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [minha "-01:00:00"] &&
    [maxha "+01:00:00"] &&
    [minmoonseparation "15d"]
  }]
}

proc EXECUTE {args} {
  setreadmode 1MHz
  setbinning 1
  movefilterwheel "BI"
  setsecondaryoffset 200
  track
  expose object 10
  setsecondaryoffset -200
  track
  expose object 10
  return true
}
EOF


# The faint star for 00 was 2252-0179-1 23:57:47.895 +24:58:33.35, but this has a bright companion to the north.

done <<EOF
00  0 1729-1345-1 00:01:25.132 +24:29:01.26 2252-0220-1 23:58:03.867 +24:20:27.55
01  1 1743-1900-1 01:01:07.885 +25:01:30.20 1740-0016-1 00:58:26.441 +24:31:19.49
02  2 1760-1711-1 02:00:45.709 +25:16:19.72 1757-0089-1 01:59:18.892 +24:49:44.86
03  3 1786-1183-1 02:59:22.275 +25:17:22.08 1782-1335-1 02:58:35.998 +24:08:01.65
04  4 1817-1054-1 03:59:59.096 +25:06:56.48 1817-0797-1 03:57:11.838 +25:16:58.37
05  5 1849-2019-1 05:01:25.985 +24:43:45.09 1832-0425-1 05:00:24.285 +24:09:45.83
06  6 1868-0263-1 06:00:00.118 +24:51:57.33 1867-0896-1 05:58:36.727 +24:47:52.15
07  7 1899-1774-1 06:59:18.315 +25:04:24.79 1899-1873-1 07:02:07.209 +25:25:32.15
08  8 1930-0496-1 08:00:55.368 +24:49:19.04 1930-1485-1 08:00:26.146 +25:02:02.32
09  9 1950-0832-1 09:00:48.685 +24:53:37.88 1953-1593-1 08:58:49.860 +25:24:18.04
10 10 1964-1168-1 09:59:55.048 +25:15:51.05 1961-1385-1 10:00:01.702 +24:33:09.88
11 11 1978-0914-1 11:01:42.496 +25:28:27.65 1978-0327-1 10:58:09.069 +24:22:31.84
12 12 1986-2193-1 12:00:17.976 +24:41:05.47 1986-0478-1 12:02:42.122 +24:26:47.37
13 13 1993-1837-1 13:00:19.382 +25:09:07.55 1993-1637-1 13:01:03.572 +24:18:58.68
14 14 2009-0925-1 14:00:03.938 +25:05:43.59 2006-0758-1 13:58:54.197 +24:41:31.89
15 15 2017-0341-1 15:01:38.501 +24:46:10.61 2020-0985-1 14:58:49.631 +25:02:52.74
16 16 2038-1213-1 16:00:31.074 +25:04:45.09 2037-1325-1 15:59:29.014 +25:26:05.53
17 17 2063-1046-1 17:00:32.650 +24:52:44.00 2064-0226-1 17:02:02.163 +25:02:16.43  
18 18 2095-1342-1 18:00:09.435 +24:31:35.29 2095-1458-1 18:01:34.218 +25:29:22.65
19 19 2126-2069-1 19:00:00.738 +25:00:24.42 2113-2457-1 18:58:31.544 +25:14:55.29
20 20 2145-1208-1 20:00:02.030 +24:59:30.42 2145-0514-1 20:00:01.951 +25:10:32.51
21 21 2176-1129-1 21:00:44.991 +25:05:02.02 2172-0155-1 20:57:57.490 +24:15:08.65
22 22 2207-1050-1 22:00:39.919 +25:06:15.26 2207-2545-1 21:56:58.131 +25:16:04.00
23 23 2238-1491-1 23:01:02.534 +24:56:30.99 2239-1157-1 23:05:03.396 +24:31:18.68
EOF
