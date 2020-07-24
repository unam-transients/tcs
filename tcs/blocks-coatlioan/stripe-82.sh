#!/bin/sh

rm -f 0009-stripe-82-*

awk '
BEGIN {
  
  # -50d < alpha < +59d
  # -1.25d < delta < +1.25d
  
  alphamin = -45.0; 
  alphamax = +55.0; 
  dalpha   =   1.0;
  deltamin =  -1.0;
  deltamax =  +1.0;
  ddelta   =   1.0;
  
  targetid = 0;
  
  for (alpha = alphamin; alpha <= alphamax; alpha += dalpha)
    for (delta = deltamin; delta <= deltamax; delta += ddelta)
      printf("%+06.1fd %+05.1fd %04d\n", alpha < 0 ? 360 + alpha : alpha, delta, targetid++);
} ' /dev/null |
while read alpha delta targetid
do
  cat >0009-stripe-82-$targetid-low-airmass <<EOF
proposal::setidentifier "[utcclock::semester]-0009";
block::setidentifier $targetid
visit::setidentifier 0
visit::setname "SDSS Stripe 82 $targetid $alpha $delta -- low airmass"
block::settotalexposures 0
visit::settargetcoordinates equatorial $alpha $delta 2000

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [maxfocusdelay 1200] &&
    [minmoonseparation "15d"] && 
    [maxairmass 1.25] &&
    [onfavoredsideforswift]
  }]
}

proc EXECUTE {args} {

  setsecondaryoffset 0
  track

  executor::setreadmode 1MHz
  executor::setwindow "default"
  executor::setbinning 2
  movefilterwheel "w"

  waituntiltracking

  expose object 30
  expose object 30
  expose object 30
  expose object 30

  return true
}
EOF
done
