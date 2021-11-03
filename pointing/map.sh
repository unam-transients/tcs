rotation=$1
shift

rm -f map-model.txt map-requested.txt map-residuals.txt map-simple-residuals.txt

sh select.sh $rotation "$@" | ./fitmodel
mv residuals.dat residuals-$rotation.dat

exit
