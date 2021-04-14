#!/bin/sh

rm -f 0004-initial-focus-?? 0004-focus-?? 0009-full-focus-?? 

while read blockid alpha delta
do

  suffix=$(printf '%02d' $blockid)

  cat <<EOF >0004-initial-focus-$suffix
{
  "project": {
    "identifier": "0004",
    "name": "initial focussing and pointing correction"
  },
  "identifier": "$blockid",
  "name": "initial focussing near $alpha $delta",
  "visits": [
    {
      "identifier": "0",
      "name": "initial focus",
      "targetcoordinates": {
        "type"   : "equatorial",
        "alpha"  : "$alpha",
        "delta"  : "$delta",
        "equinox": "2000"
      },
      "command": "initialfocusvisit",
      "estimatedduration": "10m"
    },
    {
      "identifier": "1",
      "name": "initial pointing correction near +1h 55d",
      "targetcoordinates": {
        "type"   : "fixed",
        "ha"     : "+1h",
        "delta"  : "+45d"
      },
      "command": "initialpointingcorrectionvisit",
      "estimatedduration": "5m"
    },
    {
      "identifier": "2",
      "name": "initial pointing correction near -1h 45d",
      "targetcoordinates": {
        "type"   : "fixed",
        "ha"     : "-1h",
        "delta"  : "+45d"
      },
      "command": "initialpointingcorrectionvisit",
      "estimatedduration": "5m"
    }
  ],
  "constraints": {
    "maxskybrightness": "nauticaltwilight",
    "minha": "-2h",
    "maxha": "+2h",
    "minmoondistance": "30d",
    "minfocusdelay": "14400"
  },
  "persistent": "true"
}
EOF

  cat <<EOF >0004-focus-$suffix
{
  "project": {
    "identifier": "0004",
    "name": "focussing"
  },
  "identifier": "$blockid",
  "name": "focussing near $alpha $delta",
  "visits": [
    {
      "identifier": "0",
      "name": "focus",
      "targetcoordinates": {
        "type"   : "equatorial",
        "alpha"  : "$alpha",
        "delta"  : "$delta",
        "equinox": "2000"
      },
      "command": "focusvisit",
      "estimatedduration": "10m"
    }
  ],
  "constraints": {
    "maxskybrightness": "nauticaltwilight",
    "minha": "-2h",
    "maxha": "+2h",
    "minmoondistance": "30d",
    "minfocusdelay": "1200"
  },
  "persistent": "true"
}
EOF

done <<EOF
0  00h +45d
1  01h +45d
2  02h +45d
3  03h +45d
4  04h +45d
5  05h +45d
6  06h +45d
7  07h +45d
8  08h +45d
9  09h +45d
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

#   cat <<EOF >0004-initial-focus-$suffix
# proposal::setidentifier "[utcclock::semester]-0004"
# block::setidentifier $suffix
# visit::setidentifier 0
# visit::setname "initial focusing at $alpha $delta"
# block::settotalexposures 0
# 
# visit::settargetcoordinates equatorial $alpha $delta 2000
# 
# constraints::setminfocusdelay    14400
# constraints::setmaxskybrightness "nauticaltwilight"
# constraints::setminha            "-02:00:00"
# constraints::setmaxha            "+02:00:00"
# constraints::setminmoondistance  "30d"
# 
# visit::setcommand "initialfocusvisit"
# EOF
# 
#   cat <<EOF >0004-focus-$suffix
# proposal::setidentifier "[utcclock::semester]-0004"
# block::setidentifier $suffix
# visit::setidentifier 1
# visit::setname "focusing at $alpha $delta"
# block::settotalexposures 0
# 
# visit::settargetcoordinates equatorial $alpha $delta 2000
# 
# constraints::setminfocusdelay    1200
# constraints::setmaxskybrightness "nauticaltwilight"
# constraints::setminha            "-02:00:00"
# constraints::setmaxha            "+02:00:00"
# constraints::setminmoondistance  "30d"
# 
# visit::setcommand "focusvisit"
# EOF
# 
#   cat <<EOF >0009-full-focus-$suffix
# proposal::setidentifier "[utcclock::semester]-0009"
# block::setidentifier $suffix
# visit::setidentifier 0
# visit::setname "full focusing at $alpha $delta"
# block::settotalexposures 0
# 
# visit::settargetcoordinates equatorial $alpha $delta 2000
# 
# constraints::setminfocusdelay    1200
# constraints::setmaxskybrightness "nauticaltwilight"
# constraints::setminha            "-02:00:00"
# constraints::setmaxha            "+02:00:00"
# constraints::setminmoondistance  "30d"
# 
# visit::setcommand "fullfocusvisit"
# EOF
# 
