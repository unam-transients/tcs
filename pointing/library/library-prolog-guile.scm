;;; The Guile-specific definitions of my standard library.

(define scheme-library-directory ".")

(define (list-sort a p?)
  (sort a p?))
  
(define (inexact x)
  (exact->inexact x))
  
(define (exact x)
  (inexact->exact x))
