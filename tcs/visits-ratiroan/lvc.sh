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

rm -f 2012A-1002-${blockidentifier}-*

export IFS=, 
while read name visit alpha delta
do
  cat <<EOF >2012A-1002-${blockidentifier}-$(printf "%04d" ${visit})
visit::setname "${eventidentifier} ${visit} ${name}"
proposal::setidentifier "2012A-1002"
visit::setidentifier $visit
visit::settargetcoordinates equatorial ${alpha}d ${delta}d 2000 1as

proc SELECTABLE {args} {
  return [expr {
    [withintelescopepointinglimits] && 
    [maxskybrightness "astronomicaltwilight"] &&
    [maxairmass 2] &&
    [minmoonseparation "15d"] &&
    [maxfocusdelay 3600]
  }]
}

block::settotalexposures 0
block::setexpectedduration 40m

proc EXECUTE {alertfile} {

  executor::setsecondaryoffset 0

  set exposurelist {
    g riYHcenter +10as +60as
    g riYHcenter  +0as -80as
    g riYHcenter -10as   0as
    g riYHcenter -10as -60as
    g riYHcenter   0as   0as
    g riYHcenter -10as +60as
    g riYHcenter +10as   0as
    g riYHcenter   0as +80as
    g riYHcenter +10as -60as
  }
  
  set lastfilter ""
  set first true

  foreach {filter aperture eoffset noffset} \$exposurelist {

    if {[string equal \$lastfilter ""] || ![string equal \$filter \$lastfilter]} {
      executor::movefilterwheel \$filter
      set lastfilter \$filter
    }
    
    if {\$first} {
      executor::track \$aperture \$eoffset \$noffset finder
      set first false
    } else {
      executor::offset \$aperture \$eoffset \$noffset finder
    }

    executor::exposeobject 50 50 30 30 4 4

  }

  return true
}
EOF
done

sudo mkdir -p $dir
sudo rm -f $dir/a-2012A-1002-${blockidentifier}-*
for file in 2012A-1002-${blockidentifier}-*
do
  sudo cp $file $dir/a-$file
done
