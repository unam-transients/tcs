export PATH=/Users/Alan/Library/Tools/bin/:$PATH

rm -f map-model.txt map-requested.txt map-residuals.txt map-simple-residuals.txt

cat "$@" |
chibi-scheme -m"srfi 95" -llibrary-prolog-chibi.scm -l library.scm -l library-epilog-chibi.scm -l map.scm

exit

cat "$@" |
mzscheme -e '(define scheme-library-directory ".")' -f library.scm -f library-mzscheme.scm -f map.scm

cat "$@" |
guile -l library-prolog-guile.scm -l library.scm -l library-epilog-guile.scm -l map.scm

