#!/bin/sh

sed '/^#/d' <<EOF |
# 10 05:32:28.64 -02:34:42.0 -4h -2h OSW
# 11 05:32:28.64 -02:34:42.0 -1h +1h OSW
# 12 05:32:28.64 -02:34:42.0 +2h +4h OSW
# 20 06:00:00.78 -02:30:38.2 -4h -2h OSE
# 21 06:00:00.78 -02:30:38.2 -1h +1h OSE
# 22 06:00:00.78 -02:30:38.2 +2h +4h OSE
# 30 05:32:44.69 +08:11:51.2 -4h -2h ONW
# 31 05:32:44.69 +08:11:51.2 -1h +1h ONW
# 32 05:32:44.69 +08:11:51.2 +2h +4h ONW
# 40 05:59:34.30 +08:11:37.8 -4h -2h ONE
# 41 05:59:34.30 +08:11:37.8 -1h +1h ONE
# 42 05:59:34.30 +08:11:37.8 +2h +4h ONE
50 11:15:46.70 +87:39:50.9 Polaris
60 11:13:59.30 +75:46:17.5 Spider
70 09:33:52.60 +68:37:39.0 Ursa01
80 08:33:22.50 +61:00:11.2 Ursa02
EOF
while read i alpha delta name
do
  while read j minha maxha
  do
    blockid=$(expr $i + $j)
cat >2001-roman-$blockid <<EOF
{
  "project": {
    "identifier": "2001",
    "name": "Roman"
  },
  "identifier": "$blockid",
  "name": "$name",
  "visits": [
    {
      "identifier": "2000",
      "name": "focusing",
      "targetcoordinates": {
        "type"   : "equatorial",
        "alpha"  : "$alpha",
        "delta"  : "$delta",
        "equinox": "2000"
      },
      "command": "focusvisit",
      "estimatedduration": "5m"
    },
    {
      "identifier": "0",
      "name": "science exposures",
      "targetcoordinates": {
        "type"   : "equatorial",
        "alpha"  : "$alpha",
        "delta"  : "$delta",
        "equinox": "2000"
      },
      "command": "gridvisit 1 5 1 60",
      "estimatedduration": "6m"
    }
  ],
  "constraints": {
    "maxskybrightness": "nauticaltwilight",
    "minha": "$minha",
    "maxha": "$maxha",
    "minmoondistance": "30d",
    "maxfocusdelay": "3600"
  },
  "persistent": "false"
}

EOF
  done <<EOF
0 -6h -4h
1 -4h -2h
2 -2h 0h
3  0h +2h
4 +2h +4h
5 +4h +6h
6 +6h +8h
7 +8h +10h
EOF
done
