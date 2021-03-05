rotation=$1
shift

rm -f map-model.txt map-requested.txt map-residuals.txt map-simple-residuals.txt


sh select.sh $rotation "$@" |
chibi-scheme -m "srfi 95" -l library/library-prolog-chibi.scm -l library/library.scm -l library/library-epilog-chibi.scm -l ./map.scm | tee map-$rotation.txt
mv residuals.dat residuals-$rotation.dat

exit

cat "$@" |
mzscheme -e '(define scheme-library-directory ".")' -f library.scm -f library-mzscheme.scm -f map.scm

cat "$@" |
guile -l library-prolog-guile.scm -l library.scm -l library-epilog-guile.scm -l map.scm

