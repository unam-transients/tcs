#!/bin/sh

rm -f 0011-sky-brightness-*

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
  position = 0;
  for (ha = -5; ha <= 5; ha += 2.0)
    for (delta = -50; delta < 90; delta += 20) {
      z = zenithdistance(ha * 15, delta)
      if (z < 70)
        printf("%03d %+.1fh %+.1fd %.1fd\n", position++, ha, delta, z);
    }
}
' |
while read position ha delta z
do
    cat >0011-sky-brightness-dark-$position <<EOF
proposal::setidentifier "[utcclock::semester]-0011"
block::setidentifier 0
visit::setidentifier 0
visit::setname "sky brightness at $ha $delta -- dark"
block::settotalexposures 0
visit::settargetcoordinates fixed $ha $delta now

constraints::setmaxfocusdelay 1200
constraints::setmaxskybrightness "dark"
constraints::setmustbeonfavoredsideforswift true

visit::setcommand "skybrightnessvisit"
EOF
    cat >0011-sky-brightness-not-dark-$position <<EOF
proposal::setidentifier "[utcclock::semester]-0011"
block::setidentifier 0
visit::setidentifier 0
visit::setname "sky brightness at $ha $delta -- not dark"
block::settotalexposures 0
visit::settargetcoordinates fixed $ha $delta now

constraints::setmaxfocusdelay 1200
constraints::setmaxskybrightness "bright"
constraints::setminskybrightness "grey"
constraints::setmustbeonfavoredsideforswift true

visit::setcommand "skybrightnessvisit"
EOF
    cat >0011-sky-brightness-astronomical-twilight-$position <<EOF
proposal::setidentifier "[utcclock::semester]-0011"
block::setidentifier 0
visit::setidentifier 0
visit::setname "sky brightness at $ha $delta -- astronomical twilight"
block::settotalexposures 0
visit::settargetcoordinates fixed $ha $delta now

constraints::setmaxfocusdelay 1200
constraints::setmaxskybrightness "astronomicaltwilight"
constraints::setminskybrightness "astronomicaltwilight"
constraints::setmustbeonfavoredsideforswift true

visit::setcommand "skybrightnessvisit"
EOF
    cat >0011-sky-brightness-nautical-twilight-$position <<EOF
proposal::setidentifier "[utcclock::semester]-0011"
block::setidentifier 0
visit::setidentifier 0
visit::setname "sky brightness at $ha $delta -- nautical twilight"
block::settotalexposures 0
visit::settargetcoordinates fixed $ha $delta now

constraints::setmaxfocusdelay 1200
constraints::setmaxskybrightness "nauticaltwilight"
constraints::setminskybrightness "nauticaltwilight"

visit::setcommand "skybrightnessvisit"
EOF
done
