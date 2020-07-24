;;@chapter Lists

;;@body
;;
;;The @0 procerdure sorts the proper list @1 under the comparison
;;predicate @2. The comparison predicate takes two arguments and returns
;;@code{#t} if ther are ordered and @code{#f} if they are not.

(define (list-sort a p?)
  (sort a p?))
  
;;@body
;;The @0 procedure returns a list of the first @1 exact non-negative
;;integers in increasing order.
;;
;;@example
;;(list-iota 0) 
;;  @result{} ()
;;(list-iota 4)
;;  @result{} (0 1 2 3)
;;@end example

(define (list-iota n)
  (let loop ((i n) (a '()))
    (if (zero? i)
      a
      (loop (- i 1) (cons (- i 1) a)))))
