#!/bin/sh

proposalidentifier=2018A-2000

rm -f $proposalidentifier-*

i=0
while test $i != 50
do
  visitidentifier=$i
  filename=$(printf $proposalidentifier-%03d $visitidentifier)
  echo $filename
  cat <<EOF >$filename
proposal::setidentifier "$proposalidentifier"
block::setidentifier "0"
visit::setidentifier "$visitidentifier"
visit::setname "Lester Fox: GD 133"
block::settotalexposures 0
visit::settargetcoordinates equatorial 11:19:10.0 +02:20:00.0 2000

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "astronomicaltwilight"] &&
    [maxfocusdelay 3600] &&
    [minmoonseparation "15d"] &&
    [maxairmass 2.0]
  }]
}

proc EXECUTE {args} {

  set exposuretime       30
  set exposuresperdither 60
  
  executor::setsecondaryoffset 0
  executor::track

  executor::setreadmode 1MHz
  executor::setwindow "default"
  executor::setbinning 2
  movefilterwheel "BB"

  executor::waituntiltracking

  executor::correctpointing C0 \$exposuretime
  executor::offset 0as 0as "default"
  executor::waituntiltracking

  set i 1
  while {\$i < \$exposuresperdither} {
    executor::expose object \$exposuretime
    incr i
  }

  return true
}
EOF
  i=$(expr $i + 1)
done