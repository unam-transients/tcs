#!/bin/sh

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
function zenithdistance(ha, delta) {
  ha = degtorad(ha);
  delta = degtorad(delta);
  latitude = degtorad(31);
  z = acos(sin(latitude) * sin(delta) + cos(latitude) * cos(delta) * cos(ha));
  return radtodeg(z);
}
BEGIN {
  blockid = 0;
  for (ha = -11; ha <= 11; ha += 1.5)
    for (delta = -50; delta < 90; delta += 20) {
      z = zenithdistance(ha * 15, delta)
      if (z < 70)
        printf("%03d %+.1fh %+.1fd %.1fd\n", blockid++, ha, delta, z);
    }
}
' |
while read blockid ha delta z
do
    cat >0010-focus-map-$blockid <<EOF
proposal::setidentifier "[utcclock::semester]-0010"
block::setidentifier $blockid
visit::setidentifier 0
visit::setname "focus map at $ha $delta"
block::settotalexposures 0
visit::settargetcoordinates fixed $ha $delta now

constraints::setmaxfocusdelay    3600
constraints::setminmoondistance  "30d"
constraints::setmaxskybrightness "nauticaltwilight"

visit::setcommand "focusmapvisit"
EOF
done
