#!/bin/sh

rm -f 0004-initial-focus-?? 0004-focus-?? 0009-full-focus-?? 

while read suffix alpha delta
do
  cat <<EOF >0004-initial-focus-$suffix
proposal::setidentifier "[utcclock::semester]-0004"
block::setidentifier $suffix
visit::setidentifier 0
visit::setname "initial focusing at $alpha $delta"
block::settotalexposures 0

visit::settargetcoordinates equatorial $alpha $delta 2000

constraints::setminfocusdelay    14400
constraints::setmaxskybrightness "nauticaltwilight"
constraints::setminha            "-02:00:00"
constraints::setmaxha            "+02:00:00"
constraints::setminmoondistance  "30d"

visit::setcommand "initialfocusvisit"
EOF

  cat <<EOF >0004-focus-$suffix
proposal::setidentifier "[utcclock::semester]-0004"
block::setidentifier $suffix
visit::setidentifier 1
visit::setname "focusing at $alpha $delta"
block::settotalexposures 0

visit::settargetcoordinates equatorial $alpha $delta 2000

constraints::setminfocusdelay    1200
constraints::setmaxskybrightness "nauticaltwilight"
constraints::setminha            "-02:00:00"
constraints::setmaxha            "+02:00:00"
constraints::setminmoondistance  "30d"

visit::setcommand "focusvisit"
EOF

  cat <<EOF >0009-full-focus-$suffix
proposal::setidentifier "[utcclock::semester]-0009"
block::setidentifier $suffix
visit::setidentifier 0
visit::setname "full focusing at $alpha $delta"
block::settotalexposures 0

visit::settargetcoordinates equatorial $alpha $delta 2000

constraints::setminfocusdelay    1200
constraints::setmaxskybrightness "nauticaltwilight"
constraints::setminha            "-02:00:00"
constraints::setmaxha            "+02:00:00"
constraints::setminmoondistance  "30d"

visit::setcommand "fullfocusvisit"
EOF

done <<EOF
00 00h +45d
01 01h +45d
02 02h +45d
03 03h +45d
04 04h +45d
05 05h +45d
06 06h +45d
07 07h +45d
08 08h +45d
09 09h +45d
10 10h +45d
11 11h +45d
12 12h +45d
13 13h +45d
14 14h +45d
15 15h +45d
16 16h +45d
17 17h +45d
18 18h +45d
19 19h +45d
20 20h +45d
21 21h +45d
21 22h +45d
23 23h +45d
EOF
