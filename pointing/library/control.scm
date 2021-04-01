;;@chapter Control

;;@deffn {Syntax} assert
;;@end deffn

(define-syntax assert
  (syntax-rules ()
    ((_ expr)
      (when (not expr)
        (display "ASSERTION FAILED: ")
        (write 'expr)
        (newline)
        (exit)))))

(define-syntax when
  (syntax-rules ()
    ((_ expr body0 body1 ...)
      (if expr (begin body0 body1 ...)))))