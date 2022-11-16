#!/bin/sh

while read id azimuth zenithdistance
do
  cat <<EOF >0002-bias-map-$id.json
{
  "project": {
    "identifier": "0002",
    "name": "biases map"
  },
  "identifier": "$id",
  "name": "biases map at $azimuth $zenithdistance",
  "visits": [
    {
      "identifier": "0",
      "name": "biases with binning 1",
      "targetcoordinates": {
        "type": "fixed",
        "azimuth": "$azimuth",
        "zenithdistance": "$zenithdistance"
      },
      "command": "biasesvisit 1",
      "estimatedduration": "2m"
    },
    {
      "identifier": "1",
      "name": "biases with binning 2",
      "targetcoordinates": {
        "type": "fixed",
        "azimuth": "$azimuth",
        "zenithdistance": "$zenithdistance"
      },
      "command": "biasesvisit 2",
      "estimatedduration": "2m"
    }
  ],
  "constraints": {
    "maxskybrightness": "civiltwilight"
  }
}
EOF
done <<EOF
00  45d 30d
01 135d 30d
02 225d 30d
03 315d 30d
04  45d 60d
05 135d 60d
06 225d 60d
07 315d 60d
EOF