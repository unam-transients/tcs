#!/bin/sh

rm -f pointing*h*d

for h in -5 -4 -3 -2 -1 1 2 3 4 5
do
  case $h in
  -5|+5)
    deltamin=40
    ;;
  -4|+4)
    deltamin=10
    ;;
  -3|+3)
    deltamin=-10
    ;;
  *)
    deltamin=-20
    ;;
  esac
  delta=80
  while test $delta -ge $deltamin
  do
    echo $h $delta
    H=$(printf "%+1dh" $h)
    DELTA=$(printf "%+02dd" $delta)
    cat >pointing$H$DELTA <<EOF
proposal::setidentifier "2017A-0008"
visit::setidentifier "0"
visit::setname "pointing model at $H $DELTA"
block::settotalexposures 0
visit::settargetcoordinates fixed $H $DELTA now

proc SELECTABLE {args} {
  return [expr {
    [maxfocusdelay 3600] &&
    [withintelescopepointinglimits] && 
    [maxskybrightness "nauticaltwilight"] &&
    [minmoonseparation "15d"]
  }]
}

proc EXECUTE {args} {

  setsecondaryoffset 0
  setbinning 1
  setreadmode 1MHz
  movefilterwheel "W"
  tracktopocentric
  expose object 30
  return true
}
EOF
    delta=$(expr $delta - 10)
  done
done

  