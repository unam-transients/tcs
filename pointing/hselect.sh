#!/bin/sh
night=$1
shift
echo "("
for fits in "$@"
do
  dirname="$(dirname "$fits")"
  basename="$(basename "$fits" .fits)"
  wcs="$dirname"/"$basename".wcs
  if test -f "$wcs"
  then
    printf "( "
    printf "\"%s/%s\" " "$fits" $(fitsheadervalue EXPTIME "$fits")
    printf "%s " $night
    for key in STRSTRA STRSTDE SMTRORA SMTRODE SMTMHA SMTMRA SMTMDE SMTMRO
    do
      if fitsheadervalue $key "$fits" >/dev/null
      then
        printf "%s " "$(fitsheadervalue $key "$fits")"
      else
        printf "%s " "unknown"
      fi
    done
    IFS=" " set -- $(tcs fitsdatawindow "$fits")
    sx=$1
    sy=$2
    nx=$3
    ny=$4
    cpix1=$(echo $* | awk '{ print $1 + $3 / 2 + 1; }')
    cpix2=$(echo $* | awk '{ print $2 + $4 / 2 + 1; }')
    printf "%s " "$(fitswcsvalue $cpix1 $cpix2 "$wcs")"
    echo ")"
  else 
    printf ";; \"%s/%s\" did not solve." "$fits" $(fitsheadervalue EXPTIME "$fits")
    echo
  fi
done
echo ")"
