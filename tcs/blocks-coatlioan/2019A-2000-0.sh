for visitidentifier in \
  00 01 02 03 04 05 06 07 08 09 \
  10 11 12 13 14 15 16 17 18 19 \
  20 21 22 23 24 25 26 27 28 29
do
cat <<EOF >2019A-2000-0-$visitidentifier

proposal::setidentifier "2019A-2000"
block::setidentifier "0"
visit::setidentifier "$visitidentifier"
visit::setname "NGC 4395 (Diego Hernandez)"
block::settotalexposures 0
visit::settargetcoordinates equatorial 12:25:48.86 +33:32:48.69 2000

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "bright"] &&
    [maxairmass 1.5] &&
    [maxha +1.5] &&
    [minmoonseparation "15d"] &&
    [maxfocusdelay 1200]
  }]
}

proc EXECUTE {args} {

  set exposuretime       60
  set exposuresperdither 2
  set filters {BV}
  
  executor::setsecondaryoffset 0
  executor::track

  executor::setreadmode "1MHz"
  executor::setwindow "default"
  executor::setbinning 2

  executor::waituntiltracking

  foreach {eastoffset northoffset} {
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
    executor::offset \$eastoffset \$northoffset "default"
    executor::waituntiltracking
    foreach filter \$filters {
      executor::movefilterwheel \$filter
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
done
