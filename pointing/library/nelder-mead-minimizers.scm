;;@body
;;
;;The @0 procedure returns a minimizer using the @url{http://en.wikipedia.org/wiki/Nelder-Mead_method, Nelder-Mead downhill simplex method}. 
;;The minimizer will terminate when the range of the y values at the
;;vertices of the simplex is less than @1.
  
(define (make-nelder-mead-minimizer y-tolerance)
  
  (lambda (f x dx)
    
    (let* (
        (m (length x))
        (n (+ m 1))
      )
      
      ;; We represent a simplex vertex as a list whose car is the value
      ;; of f at that point and cdr is a list of the m coordinates of
      ;; the point.
      
      (define (make-vertex x)
        (cons (apply f x) x))
        
      (define (vertex-y v)
        (car v))
        
      (define (vertex-x v)
        (cdr v))
        
      ;; We represent a simplex as a list of n vertices.
      
      (define (make-initial-simplex x dx)
        (map 
          (lambda (i)
            (make-vertex (map (lambda (x dx j) (+ x (if (= i j) dx 0))) x dx (list-iota m))))
          (list-iota n)))

      (define (make-reflected-simplex q s)
        (let* (
            (old-x (vertex-x (car q)))
            (reflection-x (apply map mean (map vertex-x (cdr q))))
            (new-x (map (lambda (old-x reflection-x) (+ reflection-x (* s (- old-x reflection-x)))) old-x reflection-x))
          )
          (cons (make-vertex new-x) (cdr q))))

      (define (make-contracted-simplex q)
        (let ((target-x (vertex-x (simplex-vertex q m))))
          (map (lambda (v) (make-vertex (map (lambda (old-x target-x) (/ (+ old-x target-x) 2)) (vertex-x v) target-x))) q)))
      
      (define (make-sorted-simplex q p?)
        (list-sort q (lambda (v0 v1) (p? (vertex-y v0) (vertex-y v1)))))
        
      (define (simplex-vertex q i)
        (list-ref q i))
        
      (define (simplex-y-range q)
        (apply range (map vertex-y q)))

      (define (simplex-x-mean q)
        (apply map mean (map vertex-x q)))
        
      (define (simplex-x-range q)
        (apply map range (map vertex-x q)))
        
      (define (make-next-simplex q)
        ;; Return the next simplex in the sequence.
        (let* (
            (q0 (make-sorted-simplex q >))
            (q1 (make-reflected-simplex q0 -1))
          )
          (cond
            ((< (vertex-y (simplex-vertex q1 0)) (vertex-y (simplex-vertex q1 m)))
              (let ((q2 (make-reflected-simplex q0 -2)))
                (if (< (vertex-y (simplex-vertex q2 0)) (vertex-y (simplex-vertex q1 0)))
                  q2
                  q1)))
            ((< (vertex-y (simplex-vertex q1 0)) (vertex-y (simplex-vertex q1 1)))
              q1)
            (else
              (let ((q3 (make-reflected-simplex q0 1/2)))
                (if (< (vertex-y (simplex-vertex q3 0)) (vertex-y (simplex-vertex q0 0)))
                  q3
                  (make-contracted-simplex q0)))))))
                          
      (let loop ((q (make-initial-simplex x dx)))
        (if (< (simplex-y-range q) y-tolerance)
          (values (simplex-x-mean q) (simplex-x-range q))
          (loop (make-next-simplex q)))))))
    