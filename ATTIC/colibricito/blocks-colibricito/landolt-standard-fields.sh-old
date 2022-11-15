#!/bin/sh

rm -f 2019A-0010-landolt-standard-field-*

awk '
BEGIN {
  targetid = 0;
}
{
  printf ("%02d %2d %s %s %s\n", targetid, targetid, $1, $2, $3);
  ++targetid;
} 
' landolt-standard-fields.txt |
while read suffix targetid name alpha delta
do
  cat <<EOF >2019A-0010-landolt-standard-field-$suffix-low-airmass
proposal::setidentifier "2019A-0010";
block::setidentifier $targetid
visit::setidentifier 0
visit::setname "Landolt standard field $targetid $name -- low airmass"
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

  track
  setbinning 2
  setreadmode 1MHz
  movefilterwheel "BB"
  waituntiltracking
  expose object 30
  movefilterwheel "BV"
  expose object 30
  movefilterwheel "BR"
  expose object 30
  movefilterwheel "BI"
  expose object 30

  return true
}
EOF
  cat <<EOF >2019A-0010-landolt-standard-field-$suffix-medium-airmass
proposal::setidentifier "2019A-0010";
block::setidentifier $targetid
visit::setidentifier 1
visit::setname "Landolt standard field $targetid $name -- medium airmass"
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

  track
  setbinning 2
  setreadmode 1MHz
  movefilterwheel "BB"
  waituntiltracking
  expose object 30
  movefilterwheel "BV"
  expose object 30
  movefilterwheel "BR"
  expose object 30
  movefilterwheel "BI"
  expose object 30

  return true
}
EOF
  cat <<EOF >2019A-0010-landolt-standard-field-$suffix-high-airmass
proposal::setidentifier "2019A-0010";
block::setidentifier $targetid
visit::setidentifier "2"
visit::setname "Landolt standard field $targetid $name -- high airmass"
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

  track
  setbinning 2
  setreadmode 1MHz
  movefilterwheel "BB"
  waituntiltracking
  expose object 30
  movefilterwheel "BV"
  expose object 30
  movefilterwheel "BR"
  expose object 30
  movefilterwheel "BI"
  expose object 30

  return true
}
EOF
done
