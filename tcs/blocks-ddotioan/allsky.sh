#!/bin/sh

rm -f 3000*

awk '
BEGIN {
  pi = 4 * atan2(1, 1);
}
function degtorad(x) {
  return x * pi / 180;
}
function radtodeg(x) {
  return x * 180 / pi;
}
function asin(x) {
 return atan2(x, sqrt(1-x*x));
}
function acos(x) {
  return atan2(sqrt(1-x*x), x);
}
function atan(x) {
  return atan2(x,1);
}
function max(x, y) {
  if (x >= y)
    return x;
  else
    return y;
}
function zenithdistance(ha, delta) {
  ha = degtorad(ha);
  delta = degtorad(delta);
  latitude = degtorad(31);
  z = acos(sin(latitude) * sin(delta) + cos(latitude) * cos(delta) * cos(ha));
  return radtodeg(z);
}
BEGIN {
  ddelta = 10;
  dalpha = 3.4 * 2;
  idelta = 0;
  for (delta = -90 + 0.5 * ddelta; delta < 90; delta += ddelta) {
    f0 = cos(degtorad(delta + 5));
    f1 = cos(degtorad(delta - 5));
    f = max(f0, f1);
    ialpha = 0;
    for (alpha = 0; alpha < 360; alpha += dalpha / f) {
      z = zenithdistance(0, delta);
      if (z < 85)
        printf("%02d%02d %+5.1fd %5.1fd\n", idelta, ialpha, delta, alpha)
      ++ialpha;
    }
    ++idelta;
  }
}
' |
while read blockid delta alpha
do
  
  cat >d-3000-allsky-$blockid <<EOF
{
  "project": {
    "identifier": "3000",
    "name": "allsky"
  },
  "identifier": "$blockid",
  "name": "allsky at $alpha $delta",
  "visits": [
    {
      "identifier": "99",
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
      "command": "allskyvisit",
      "estimatedduration": "20m"
    }
  ],
  "constraints": {
    "maxskybrightness": "astronomicaltwilight",
    "minha": "0.0h",
    "maxha": "0.5h",
    "minmoondistance": "45d"
  },
  "persistent": "false"
}
EOF
  cat >e-3000-allsky-$blockid <<EOF
{
  "project": {
    "identifier": "3000",
    "name": "allsky"
  },
  "identifier": "$blockid",
  "name": "allsky at $alpha $delta",
  "visits": [
    {
      "identifier": "99",
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
      "command": "allskyvisit",
      "estimatedduration": "20m"
    }
  ],
  "constraints": {
    "maxskybrightness": "astronomicaltwilight",
    "minha": "0.0h",
    "minmoondistance": "45d",
    "maxzenithdistance": "45d"
  },
  "persistent": "false"
}
EOF
  cat >f-3000-allsky-$blockid <<EOF
{
  "project": {
    "identifier": "3000",
    "name": "allsky"
  },
  "identifier": "$blockid",
  "name": "allsky at $alpha $delta",
  "visits": [
    {
      "identifier": "99",
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
      "command": "allskyvisit",
      "estimatedduration": "20m"
    }
  ],
  "constraints": {
    "maxskybrightness": "astronomicaltwilight",
    "maxha": "-0.5h",
    "minmoondistance": "45d",
    "maxzenithdistance": "45d"
  },
  "persistent": "false"
}
EOF
done

sudo mkdir -p /usr/local/var/tcs/blocks
sudo cp *-3000-* /usr/local/var/tcs/blocks
