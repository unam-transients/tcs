#!/bin/sh

rm -f 0008-pointing-map-*

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
function zenithdistance(h, delta) {
  h = degtorad(h);
  delta = degtorad(delta);
  latitude = degtorad(31.045055555555556);
  z = acos(sin(latitude) * sin(delta) + cos(latitude) * cos(delta) * cos(h));
  return radtodeg(z);
}
BEGIN {
  targetid = 0;
  for (h = -170; h <= 170; h += 10)
    for (delta = -50; delta < 90; delta += 10) {
      z = zenithdistance(h, delta)
      if (z < 80)
        printf("%03d %+.1fd %+.1fd %.1fd\n", targetid++, h, delta, z);
    }
}
' |
while read targetid h delta z
do
    cat >0008-pointing-map-$targetid <<EOF
proposal::setidentifier "[utcclock::semester]-0008"
block::setidentifier "0"
visit::setidentifier "0"
visit::setname "pointing map at $h $delta"
block::settotalexposures 0
visit::settargetcoordinates fixed $h $delta now

constraints::setmaxskybrightness "nauticaltwilight"
constraints::setmustbeonfavoredsideforswift true
constraints::setmaxfocusdelay 3600

visit::setcommand "pointingmapvisit"
EOF
done
