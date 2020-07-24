if test $# != 3
then
  echo 1>&2 "usage: $0 eventidentifier blockidentifier date"
  exit 1
fi

eventidentifier=$1
blockidentifier=$2
date=$3

################################################################################

case $date in
"")
  date=$(date +%Y%m%d -d tomorrow)
  ;;
*)
  date=$(date +%Y%m%d -d "$date")
  ;;
esac
echo "$date"
dir=/usr/local/var/tcs/$date/visits

################################################################################

rm -f 2019B-1002-${blockidentifier}-*

export IFS=, 
while read name visit alpha delta
do
  cat <<EOF >2019B-1002-${blockidentifier}-$(printf "%04d" ${visit})
proposal::setidentifier "2019B-1002"
block::setidentifier "${blockidentifier}"
visit::setidentifier "${visit}"
visit::setname "${eventidentifier} ${visit} ${name}"
block::settotalexposures 0
visit::settargetcoordinates equatorial ${alpha}d ${delta}d 2000.0

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "astronomicaltwilight"] &&
    [maxairmass 2.5] &&
    [minmoonseparation "15d"] &&
    [maxfocusdelay 1800]
  }]
}

proc EXECUTE {args} {

  set exposuretime       30
  set exposuresperdither 2
  set filters {w}
  
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

sudo mkdir -p $dir
sudo rm -f $dir/a-2019B-1002-${blockidentifier}-*
for file in 2019B-1002-${blockidentifier}-*
do
  sudo cp $file $dir/a-$file
done


