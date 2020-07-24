#!/bin/sh

rm -f 0005-sdss-standard-*

awk -F, '
BEGIN {
  targetid = 0;
}
function dex(x) {
  return exp(x * log(10));
}
NR > 2 {
  r = $4;
  # n = DN/s
  n = 2.4e9 * dex(-0.4 * r) / 6.4;
  # exptime assumes we spread this over four pixels.
  exptime = 8192 / n * 4;  
  printf ("%03d %d %s %s %.0f %s\n", targetid, targetid, $2, $3, exptime, $1);
  ++targetid;
} 
' sdss-standards.txt |
while read suffix targetid alpha delta exptime targetname
do
  cat <<EOF >0005-sdss-standard-$suffix-low-airmass
proposal::setidentifier "[utcclock::semester]-0005";
block::setidentifier $targetid
visit::setidentifier 0
visit::setname "SDSS standard $targetid $targetname -- low airmass"
block::settotalexposures 0
visit::settargetcoordinates equatorial $alpha $delta 2000

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [maxfocusdelay 1200] &&
    [minmoonseparation "15d"] && 
    [maxairmass 1.3] &&
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

  expose object $exptime

  return true
}
EOF
  cat <<EOF >0005-sdss-standard-$suffix-medium-airmass
proposal::setidentifier "[utcclock::semester]-0005";
block::setidentifier $targetid
visit::setidentifier 1
visit::setname "SDSS standard $targetid $targetname -- medium airmass"
block::settotalexposures 0
visit::settargetcoordinates equatorial $alpha $delta 2000

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [maxfocusdelay 1200] &&
    [minmoonseparation "15d"] && 
    [minairmass 1.3] &&
    [maxairmass 1.7] &&
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

  expose object $exptime

  return true
}
EOF
  cat <<EOF >0005-sdss-standard-$suffix-high-airmass
proposal::setidentifier "[utcclock::semester]-0005";
block::setidentifier $targetid
visit::setidentifier 2
visit::setname "SDSS standard $targetid $targetname -- high airmass"
block::settotalexposures 0
visit::settargetcoordinates equatorial $alpha $delta 2000

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [maxfocusdelay 1200] &&
    [minmoonseparation "15d"] && 
    [minairmass 1.7] &&
    [maxairmass 2.0] &&
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

  expose object $exptime

  return true
}
EOF
done
