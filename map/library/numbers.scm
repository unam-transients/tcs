;;@chapter Numbers

(define π (* 4 (atan 1)))

;;@body
;;The @0 procedure returns the arithmetic mean of its arguments.
;;
;;@example
;;(arithmetic-mean 1 6 2)
;;  @result{} 3
;;(arithmetic-mean 1 6 2.0)
;;  @result{} 3.0
;;@end example

(define (arithmetic-mean . z)
  (/ (apply + z) (length z)))
  
;;@body
;;The @0 procedure is a synonym for the @code{arithmetic-mean} procedure.

(define (mean . z)
  '(DUMMY BODY FOR SCHMOOZ))
(define mean arithmetic-mean)

;;@body
;;The @0 procedure returns the range of its arguments (i.e., the
;;difference between the maximum argument and the minimum argument).
;;
;;@example
;;(range 1 6 2)
;;  @result{} 5
;;(range 1 6 2.0)
;;  @result{} 5.0
;;@end example

(define (range . x)
  (- (apply max x) (apply min x)))

;;@body
;;The @0 procedure returns the norm of its arguments (i.e., the
;;square root of the sum of the squares of its arguments). The result is always inexact.
;;
;;@example
;;(norm 0)
;;  @result{} 0.0
;;(norm 1)
;;  @result{} 1.0
;;(norm 3 4)
;;  @result{} 5.0
;;@end example

(define (norm . x)
  (sqrt (inexact (apply + (map (lambda (x) (* x x)) x)))))
  
;;@body
;;The @0 procedure returns the root mean square of its arguments (i.e., the
;;square root of the mean of the squares of its arguments). The result is always inexact.
;;
;;@example
;;(root-mean-square 0)
;;  @result{} 0.0
;;(root-mean-square 1)
;;  @result{} 1.0
;;(root-mean-square 1 2 2)
;;  @result{} 1.732050807568877
;;@end example

(define (root-mean-square . x)
  (sqrt (inexact (apply mean (map (lambda (x) (* x x)) x)))))
