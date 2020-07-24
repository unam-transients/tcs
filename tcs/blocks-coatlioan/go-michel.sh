#!/bin/sh

rm -f 2017B-1002-*

i=0

(
  echo 0 TYC-2220-704-1 22:39:13.7005 +23:26:10.249
) | 
while read visitidentifier name alpha delta 
do
  filename=$(printf 2017B-1002-%03d $i)
  echo $filename $name
  cat <<EOF >$filename
proposal::setidentifier "2017B-1002"
visit::setidentifier "$visitidentifier"
visit::setname "Michel: $name"
block::settotalexposures 0
visit::settargetcoordinates equatorial $alpha $delta 2000

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [maxfocusdelay 1200] &&
    [minmoonseparation "15d"] &&
    [onfavoredsideforswift]    
  }]
}

proc EXECUTE {args} {

  set exposuretime       5
  set exposuresperdither 10
  set filters            {"w"}
  
  executor::setsecondaryoffset 0
  executor::track

  executor::setreadmode 1MHz
  executor::setwindow "default"
  executor::setbinning 2

  executor::waituntiltracking

  foreach {alphaoffset deltaoffset} {
      0as   0as
    +30as +30as
    +30as -30as
    -30as -30as
    -30as +30as
      0as -30as
    +30as   0as
      0as +30as
    -30as   0as
  } {

    executor::offset \$alphaoffset \$deltaoffset "default"
    executor::waituntiltracking

    foreach filter \$filters {
      movefilterwheel \$filter
      set i 0
      while {\$i < \$exposuresperdither} {
        executor::expose object \$exposuretime
        incr i
      }
    }

  }

  return true
}
EOF
  i=$(expr $i + 1)
done