#!/bin/sh

rm -f 2019A-0011-sky-brightness-*

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
  latitude = degtorad(43.932081);
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
    cat >2019A-0011-sky-brightness-dark-$position <<EOF
proposal::setidentifier "2019A-0011"
block::setidentifier 0
visit::setidentifier 0
visit::setname "sky brightness at $ha $delta -- dark"
block::settotalexposures 0
visit::settargetcoordinates fixed $ha $delta now

proc SELECTABLE {args} {
  return [expr {
    [maxfocusdelay 3600] &&
    [withintelescopepointinglimits] && 
    [maxskybrightness "dark"] &&
    [onfavoredsideforswift]
  }]
}

proc EXECUTE {args} {

  executor::tracktopocentric

  executor::setbinning 1
  executor::movefilterwheel "w"
  executor::waituntiltracking

  foreach {filter exposuretime visitidentifier} {
    "w"  60 0
  } {
    executor::movefilterwheel \$filter
    visit::setidentifier \$visitidentifier
    executor::expose object \$exposuretime
  }
  
  return true
}
EOF
    cat >2019A-0011-sky-brightness-not-dark-$position <<EOF
proposal::setidentifier "2019A-0011"
block::setidentifier 0
visit::setidentifier 0
visit::setname "sky brightness at $ha $delta -- not dark"
block::settotalexposures 0
visit::settargetcoordinates fixed $ha $delta now

proc SELECTABLE {args} {
  return [expr {
    [maxfocusdelay 3600] &&
    [withintelescopepointinglimits] && 
    [minskybrightness "grey"] &&
    [maxskybrightness "bright"] &&
    [onfavoredsideforswift]
  }]
}

proc EXECUTE {args} {

  executor::tracktopocentric

  executor::setbinning 1
  executor::movefilterwheel "w"
  executor::waituntiltracking

  foreach {filter exposuretime visitidentifier} {
    "w"  60 0
  } {
    executor::movefilterwheel \$filter
    visit::setidentifier \$visitidentifier
    executor::expose object \$exposuretime
  }
  
  return true
}
EOF
    cat >2019A-0011-sky-brightness-astronomical-twilight-$position <<EOF
proposal::setidentifier "2019A-0011"
block::setidentifier 0
visit::setidentifier 0
visit::setname "sky brightness at $ha $delta -- astronomical twilight"
block::settotalexposures 0
visit::settargetcoordinates fixed $ha $delta now

proc SELECTABLE {args} {
  return [expr {
    [maxfocusdelay 3600] &&
    [withintelescopepointinglimits] && 
    [minskybrightness "astronomicaltwilight"] &&
    [maxskybrightness "astronomicaltwilight"] &&
    [onfavoredsideforswift]
  }]
}

proc EXECUTE {args} {

  executor::tracktopocentric

  executor::setbinning 1
  executor::movefilterwheel "w"
  executor::waituntiltracking

  foreach {filter exposuretime visitidentifier} {
    "w"  60 0
  } {
    executor::movefilterwheel \$filter
    visit::setidentifier \$visitidentifier
    executor::expose object \$exposuretime
  }
  
  return true
}
EOF
    cat >2019A-0011-sky-brightness-nautical-twilight-$position <<EOF
proposal::setidentifier "2019A-0011"
block::setidentifier 0
visit::setidentifier 0
visit::setname "sky brightness at $ha $delta -- nautical twilight"
block::settotalexposures 0
visit::settargetcoordinates fixed $ha $delta now

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [minskybrightness "nauticaltwilight"] &&
    [maxskybrightness "nauticaltwilight"]
  }]
}

proc EXECUTE {args} {

  executor::tracktopocentric

  executor::setbinning 1
  executor::movefilterwheel "w"
  executor::waituntiltracking

  foreach {filter exposuretime visitidentifier} {
    "w"  10 0
  } {
    executor::movefilterwheel \$filter
    visit::setidentifier \$visitidentifier
    executor::expose object \$exposuretime
  }
  
  return true
}
EOF
done
