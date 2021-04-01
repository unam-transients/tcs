(import (scheme process-context))

(define (rad->deg x)
  (* x (/ 180.0 π)))

(define (rad->arcmin x)
  (* x (/ (* 180.0 60.0) π)))

(define (rad->arcsec x)
  (* x (/ (* 180.0 60.0 60.0) π)))

(define (deg->rad x)
  (* x (/ π 180.0)))

(define (fold-angle x)
  (cond
    ((> x (+ π)) (- x (* 2 π)))
    ((< x (- π)) (+ x (* 2 π)))
    (else        x)))
  
(define (fold-angle-positive x)
  (cond
    ((> x (* 2 π)) (- x (* 2 π)))
    ((< x 0)       (+ x (* 2 π)))
    (else          x)))
  
(define (read-from-file file-name)
  (let* (
      (p (open-input-file file-name))
      (x (read p))
    )
    (close-input-port p)
    x))

(define (raw-pointing-name raw-pointing)
  (list-ref raw-pointing 0))
(define (raw-pointing-night raw-pointing)
  (list-ref raw-pointing 1))
(define (raw-pointing-requested-alpha raw-pointing)
  (deg->rad (list-ref raw-pointing 2)))
(define (raw-pointing-requested-delta raw-pointing)
  (deg->rad (list-ref raw-pointing 3)))
(define (raw-pointing-observed-alpha raw-pointing)
  (deg->rad (list-ref raw-pointing 4)))
(define (raw-pointing-observed-delta raw-pointing)
  (deg->rad (list-ref raw-pointing 5)))
(define (raw-pointing-mount-h raw-pointing)
  (deg->rad (list-ref raw-pointing 6)))
(define (raw-pointing-mount-alpha raw-pointing)
  (deg->rad (list-ref raw-pointing 7)))
(define (raw-pointing-mount-delta raw-pointing)
  (deg->rad (list-ref raw-pointing 8)))
(define (raw-pointing-mount-rotation raw-pointing)
  (deg->rad (list-ref raw-pointing 9)))
(define (raw-pointing-image-alpha raw-pointing)
  (deg->rad (list-ref raw-pointing 10)))
(define (raw-pointing-image-delta raw-pointing)
  (deg->rad (list-ref raw-pointing 11)))
(define (raw-pointing-raw-e2v-pointing raw-pointing)
  (list-ref raw-pointing 12))

(define (pointing-name pointing)
  (list-ref pointing 0))
(define (pointing-night pointing)
  (list-ref pointing 1))
(define (pointing-mount-h pointing)
  (list-ref pointing 2))
(define (pointing-mount-delta pointing)
  (list-ref pointing 3))
(define (pointing-mount-rotation pointing)
  (list-ref pointing 4))
(define (pointing-image-alpha pointing)
  (list-ref pointing 5))
(define (pointing-ima6e-delta pointing)
  (list-ref pointing 6))
(define (pointing-x-error pointing)
  (list-ref pointing 7))
(define (pointing-y-error pointing)
  (list-ref pointing 8))
  
(define (pointing-mount-z pointing)
  (let* (
      (h     (pointing-mount-h     pointing))
      (delta (pointing-mount-delta pointing))
      (z     (acos (+ (* (sin delta) (sin phi)) (* (cos delta) (cos phi) (cos h))))))
    z))

(define (pointing-lst pointing)
  (fold-angle (+ (pointing-image-alpha pointing) (pointing-mount-h pointing) (deg->rad +32))))

  
(define (raw-pointing->pointing raw-pointing)
  (let* (

      (mount-alpha     (raw-pointing-mount-alpha raw-pointing))
      (mount-delta     (raw-pointing-mount-delta raw-pointing))
      (mount-h         (raw-pointing-mount-h raw-pointing))
      (mount-rotation  (raw-pointing-mount-rotation raw-pointing))

      (image-alpha (raw-pointing-image-alpha raw-pointing))
      (image-delta (raw-pointing-image-delta raw-pointing))
      
      (apply-correction #t)
      
      (requested-alpha 
      	(let* ((requested-alpha (raw-pointing-requested-alpha raw-pointing))
	       (observed-alpha  (raw-pointing-observed-alpha raw-pointing))
      	       (applied-model-dalpha (fold-angle (- mount-alpha observed-alpha))))
      	       (if apply-correction
      	         (fold-angle (+ requested-alpha applied-model-dalpha))
      	         requested-alpha)))
      (requested-delta 
      	(let* ((requested-delta (raw-pointing-requested-delta raw-pointing))
	       (observed-delta  (raw-pointing-observed-delta raw-pointing))
      	       (applied-model-ddelta (fold-angle (- mount-delta observed-delta))))
      	       (if apply-correction
      	         (fold-angle (+ requested-delta applied-model-ddelta))
      	         requested-delta)))

      (x-error (* (fold-angle (- image-alpha requested-alpha)) (cos image-delta)))
      (y-error (fold-angle (- requested-delta image-delta)))
      
      ;(axis-h     (if (zero? mount-rotation) mount-h (+ π mount-h)))
      ;(axis-delta (if (zero? mount-rotation) mount-delta (- π mount-delta)))
      ;(x-error     (if (zero? mount-rotation) x-error (- x-error)))
      ;(y-error     (if (zero? mount-rotation) y-error (- y-error)))
    )
    (list 
      (raw-pointing-name raw-pointing)
      (raw-pointing-night raw-pointing)
      mount-h
      mount-delta
      mount-rotation
      image-alpha
      image-delta
      x-error
      y-error)))
      
(define (raw-pointing->differential-pointing raw-pointing)
  (let* (
      (finder-pointing (raw-pointing->finder-pointing raw-pointing))
      (e2v-pointing (raw-e2v-pointing->e2v-pointing (raw-pointing-raw-e2v-pointing raw-pointing)))
    ) 
    (list
      (string-append (pointing-name finder-pointing) " and " (pointing-name e2v-pointing))
      (pointing-night finder-pointing)
      (pointing-mount-h finder-pointing)
      (pointing-mount-delta finder-pointing)
      (pointing-image-alpha finder-pointing)
      (pointing-image-delta finder-pointing)
      (* (cos (pointing-image-delta finder-pointing))
        (fold-angle (- (pointing-image-alpha finder-pointing) (pointing-image-alpha e2v-pointing))))
      (fold-angle (- (pointing-image-delta e2v-pointing) (pointing-image-delta finder-pointing)))
      finder-pointing
      e2v-pointing)))
  
;(define pointings (map raw-pointing->differential-pointing (read)))
;(define pointings (map polima-pointing->pointing (read)))
;(define pointings (map raw-pointing->finder-pointing (read)))
;(define pointings (map raw-pointing->e2v-pointing (read)))
;(define pointings (map raw-pointing->C1-pointing (read)))
(define pointings (map raw-pointing->pointing (read)))

(for-each
  (lambda (pointing)
    (write pointing)
    (newline))
  pointings)
(newline)

(define phi (* (/ π 180.0) (+ 31.0 (/ 02.0 60.0) (/ 43.0 3600.0))))

(define (sgn x)
  (if (negative? x) -1.0 +1.0))
  
(define (model-x-error p pointing)
  (let* (
      (night (pointing-night       pointing))
      (h     (pointing-mount-h     pointing))
      (delta (pointing-mount-delta pointing))
      (ddelta (- delta phi))
      (z     (acos (+ (* (sin delta) (sin phi)) (* (cos delta) (cos phi) (cos h)))))
      (A     (atan (sin h) (- (* (cos phi) (tan delta)) (* (sin phi) (cos h)))))
    )
    (+ 
      (* (model-term 'IH      p) (cos delta))
      (* (model-term (string->symbol (string-append "IH" (number->string night))) p) (cos delta))
      (* (model-term 'CH      p) 1.0)
      (* (model-term 'CHS     p) (sgn h))
      (* (model-term (string->symbol (string-append "IH" (number->string night))) p) (cos delta))
      (* (model-term 'NP      p) (sin delta))
      (* (model-term 'NPS     p) (* (sgn h) (sin delta)))
      (* (model-term 'MA      p) (- (* (sin delta) (cos h))))
      (* (model-term 'ME      p) (sin delta) (sin h))
      (* (model-term 'TF      p) (* (cos phi) (sin h)))
      (* (model-term 'DAF     p) (- (cos z)))
      (* (model-term 'HHSH    p) (cos delta) (sin h))
      (* (model-term 'HHCH    p) (cos delta) (cos h))
      (* (model-term 'HHSH2   p) (cos delta) (sin (* 2.0 h)))
      (* (model-term 'HHCH2   p) (cos delta) (cos (* 2.0 h)))
      (* (model-term 'HHSH3   p) (cos delta) (sin (* 3.0 h)))
      (* (model-term 'HHCH3   p) (cos delta) (cos (* 3.0 h)))
      (* (model-term 'HHSH4   p) (cos delta) (sin (* 4.0 h)))
      (* (model-term 'HHCH4   p) (cos delta) (cos (* 4.0 h)))
      (* (model-term 'HXSH    p) (sin h))
      (* (model-term 'HXCH    p) (cos h))
      (* (model-term 'HXSH2   p) (sin (* 2.0 h)))
      (* (model-term 'HXCH2   p) (cos (* 2.0 h)))
      (* (model-term 'HXSH3   p) (sin (* 3.0 h)))
      (* (model-term 'HXCH3   p) (cos (* 3.0 h)))
      (* (model-term 'HXSH4   p) (sin (* 4.0 h)))
      (* (model-term 'HXCH4   p) (cos (* 4.0 h)))
      (* (model-term 'PXD     p) (expt (- delta phi) 1) (expt h 0))
      (* (model-term 'PXH     p) (expt (- delta phi) 0) (expt h 1))
      (* (model-term 'PXD2    p) (expt (- delta phi) 2) (expt h 0))
      (* (model-term 'PXDH    p) (expt (- delta phi) 1) (expt h 1))
      (* (model-term 'PXH2    p) (expt (- delta phi) 0) (expt h 2))
      (* (model-term 'PXD3    p) (expt (- delta phi) 3) (expt h 0))
      (* (model-term 'PXD2H   p) (expt (- delta phi) 2) (expt h 1))
      (* (model-term 'PXDH2   p) (expt (- delta phi) 1) (expt h 2))
      (* (model-term 'PXH3    p) (expt (- delta phi) 0) (expt h 3))
      (* (model-term 'HHSHSD  p) (cos delta) (sin h) (sin delta))
      (* (model-term 'HHSHCD  p) (cos delta) (sin h) (cos delta))
      (* (model-term 'HHCHSD  p) (cos delta) (cos h) (sin delta))
      (* (model-term 'HHCHCD  p) (cos delta) (cos h) (cos delta))
      (* (model-term 'HHSHSD2 p) (cos delta) (sin h) (sin (* 2.0 delta)))
      (* (model-term 'HHSHCD2 p) (cos delta) (sin h) (cos (* 2.0 delta)))
      (* (model-term 'HHCHSD2 p) (cos delta) (cos h) (sin (* 2.0 delta)))
      (* (model-term 'HHCHCD2 p) (cos delta) (cos h) (cos (* 2.0 delta)))
      (* (model-term 'HHSH2SD p) (cos delta) (sin (* 2.0 h)) (sin delta))
      (* (model-term 'HHSH2CD p) (cos delta) (sin (* 2.0 h)) (cos delta))
      (* (model-term 'HHCH2SD p) (cos delta) (cos (* 2.0 h)) (sin delta))
      (* (model-term 'HHCH2CD p) (cos delta) (cos (* 2.0 h)) (cos delta))
      (* (model-term 'HXSHSD  p) (sin h) (sin delta))
      (* (model-term 'HXSHCD  p) (sin h) (cos delta))
      (* (model-term 'HXCHSD  p) (cos h) (sin delta))
      (* (model-term 'HXCHCD  p) (cos h) (cos delta))
      (* (model-term 'HXSHSD2 p) (sin h) (sin (* 2.0 delta)))
      (* (model-term 'HXSHCD2 p) (sin h) (cos (* 2.0 delta)))
      (* (model-term 'HXCHSD2 p) (cos h) (sin (* 2.0 delta)))
      (* (model-term 'HXCHCD2 p) (cos h) (cos (* 2.0 delta)))
      (* (model-term 'HXSH2SD p) (sin (* 2.0 h)) (sin delta))
      (* (model-term 'HXSH2CD p) (sin (* 2.0 h)) (cos delta))
      (* (model-term 'HXCH2SD p) (cos (* 2.0 h)) (sin delta))
      (* (model-term 'HXCH2CD p) (cos (* 2.0 h)) (cos delta))
      (* (model-term 'HBL p) (if (> h 0) 1.0 0.0))
      (* (model-z-error p pointing)     
        (/ (* (cos phi) (sin h)) (sin z)))
      )))
    
(define (model-y-error p pointing)
  (let* (
      (night (pointing-night       pointing))
      (h     (pointing-mount-h     pointing))
      (delta (pointing-mount-delta pointing))
      (z     (acos (+ (* (sin delta) (sin phi)) (* (cos delta) (cos phi) (cos h)))))
      (A     (atan (sin h) (- (* (cos phi) (tan delta)) (* (sin phi) (cos h)))))
      (lst   (pointing-lst pointing))
    )
    (+ 
      (* (model-term 'ID    p)    1.0)
      (* (model-term (string->symbol (string-append "ID" (number->string night))) p) 1.0
	 (if ignore-IDx 0 1))
      (* (model-term 'MA    p)    (sin h))
      (* (model-term 'ME    p)    (cos h))
      (* (model-term 'TF    p) (- (* (cos phi) (cos h) (sin delta)) (* (sin phi) (cos delta))))
      (* (model-term 'FO    p)    (cos h))
      (* (model-term 'HDSD  p)  (sin delta))
      (* (model-term 'HDCD  p)  (cos delta))
      (* (model-term 'HDSD2 p) (sin (* 2.0 delta)))
      (* (model-term 'HDCD2 p) (cos (* 2.0 delta)))
      (* (model-term 'HDSD3 p) (sin (* 3.0 delta)))
      (* (model-term 'HDCD3 p) (cos (* 3.0 delta)))
      (* (model-term 'HDSD4 p) (sin (* 4.0 delta)))
      (* (model-term 'HDCD4 p) (cos (* 4.0 delta)))
      (* (model-term 'PDD   p) (expt (- delta phi) 1) (expt h 0))
      (* (model-term 'PDH   p) (expt (- delta phi) 0) (expt h 1))
      (* (model-term 'PDD2  p) (expt (- delta phi) 2) (expt h 0))
      (* (model-term 'PDDH  p) (expt (- delta phi) 1) (expt h 1))
      (* (model-term 'PDH2  p) (expt (- delta phi) 0) (expt h 2))
      (* (model-term 'PDD3  p) (expt (- delta phi) 3) (expt h 0))
      (* (model-term 'PDD2H p) (expt (- delta phi) 2) (expt h 1))
      (* (model-term 'PDDH2 p) (expt (- delta phi) 1) (expt h 2))
      (* (model-term 'PDH3  p) (expt (- delta phi) 0) (expt h 3))
      (* (model-term 'DBL   p) (if (> delta (deg->rad 32.5)) 1.0 0.0))
      (* (model-z-error p pointing) 
        (/ (- (* (cos phi) (cos h) (sin delta)) (* (sin phi) (cos delta))) (sin z)))
      (* (model-term 'A0    p) lst (if ignore-A0 0 1))
      (* (model-term 'A1    p) (case night ((1 3 5) 0) (else 1)))
      (* (model-term 'A2    p) (if (and (= night 2) (> delta 0.8)) 1 0))
      )))
      
(define (model-z-error p pointing)
  (let* (
      (h     (pointing-mount-h     pointing))
      (delta (pointing-mount-delta pointing))
      (z     (acos (+ (* (sin delta) (sin phi)) (* (cos delta) (cos phi) (cos h)))))
      (A     (atan (sin h) (- (* (cos phi) (tan delta)) (* (sin phi) (cos h)))))
    )
    (+
      (* 0 (model-term 'TF p)    (sin z))
      (* (model-term 'TFSA p)  (sin z) (sin A))
      (* (model-term 'TFCA p)  (sin z) (cos A))
      (* (model-term 'TFSA2 p) (sin z) (sin (* 2.0 A)))
      (* (model-term 'TFCA2 p) (sin z) (cos (* 2.0 A)))
      (* (model-term 'TFSA3 p) (sin z) (sin (* 3.0 A)))
      (* (model-term 'TFCA3 p) (sin z) (cos (* 3.0 A)))
      (* (model-term 'TFSA4 p) (sin z) (sin (* 4.0 A)))
      (* (model-term 'TFCA4 p) (sin z) (cos (* 4.0 A)))
      (* (model-term 'TX p)    (tan z))
      (* (model-term 'PZZ p)   z)
      (* (model-term 'PZZ2 p)  (expt z 2))
      (* (model-term 'PZZ3 p)  (expt z 3))
      (* (model-term 'PZZ4 p)  (expt z 4))
      )))

(define (model-x-tf p pointing)
  (let* (
      (h     (pointing-mount-h     pointing))
      (delta (pointing-mount-delta pointing))
      (z     (acos (+ (* (sin delta) (sin phi)) (* (cos delta) (cos phi) (cos h)))))
      (A     (atan (sin h) (- (* (cos phi) (tan delta)) (* (sin phi) (cos h)))))
    )
    (* 
      (/ 30 206000) ;(model-term 'TF p)    
      (sin z) 
      (/ (* (cos phi) (sin h)) (sin z)))))
      
(define (model-y-tf p pointing)
  (let* (
      (h     (pointing-mount-h     pointing))
      (delta (pointing-mount-delta pointing))
      (z     (acos (+ (* (sin delta) (sin phi)) (* (cos delta) (cos phi) (cos h)))))
      (A     (atan (sin h) (- (* (cos phi) (tan delta)) (* (sin phi) (cos h)))))
    )
    (* 
      (/ 30 206000) ; (model-term 'TF p)    
      (sin z) 
      (/ (- (* (cos phi) (cos h) (sin delta)) (* (sin phi) (cos delta))) (sin z)))))
      
(define (model-z-error p pointing)
  (let* (
      (h     (pointing-mount-h     pointing))
      (delta (pointing-mount-delta pointing))
      (z     (acos (+ (* (sin delta) (sin phi)) (* (cos delta) (cos phi) (cos h)))))
      (A     (atan (sin h) (- (* (cos phi) (tan delta)) (* (sin phi) (cos h)))))
    )
    (+
      (* (model-term 'TF p)    (sin z))
      (* (model-term 'TFSA p)  (sin z) (sin A))
      (* (model-term 'TFCA p)  (sin z) (cos A))
      (* (model-term 'TFSA2 p) (sin z) (sin (* 2.0 A)))
      (* (model-term 'TFCA2 p) (sin z) (cos (* 2.0 A)))
      (* (model-term 'TFSA3 p) (sin z) (sin (* 3.0 A)))
      (* (model-term 'TFCA3 p) (sin z) (cos (* 3.0 A)))
      (* (model-term 'TFSA4 p) (sin z) (sin (* 4.0 A)))
      (* (model-term 'TFCA4 p) (sin z) (cos (* 4.0 A)))
      (* (model-term 'TX p)    (tan z))
      (* (model-term 'PZZ p)   z)
      (* (model-term 'PZZ2 p)  (expt z 2))
      (* (model-term 'PZZ3 p)  (expt z 3))
      (* (model-term 'PZZ4 p)  (expt z 4))
      )))


(define (model-variable-x-error p pointing)
  (let (
      (h     (pointing-mount-h     pointing))
      (delta (pointing-mount-delta pointing))
    )
    (-
      (model-x-error p pointing) 
      (* (model-term 'IH p) (cos delta))
      (* (model-term 'CH p) 1.0)
      (* (model-term 'CHS p) (sgn h)))))

(define (model-variable-y-error p pointing)
  (- 
    (model-y-error p pointing) 
    (model-term 'ID p)))

(define model-term-names
  '(
    ; Simple terms
    ; ID IH CH
    ;ID CH 
  
    ; Differential terms
    ; ID CH 
    ; TF 
    ; PXD PXH PDD PDH 
    ; PXD2 PXDH PXH2 PDD2 PDDH PDH2

    ;PXD3 PXD2H PXDH2 PXH3 
    ;PDD3 PDD2H PDDH2 PDH3
    
    ;PDH4 PDD4 PDH5 PDD5 PDH6 PDD6

    ;ID0 CH0 ID1 CH1

    
    ; Absolute terms for finder CCD
    ;IH ID
    ;IH0 ID0 
    ;IH1 ID1 
    ;IH2 ID2
    ;IH ID ID2 ID3 ID4 ID5 ID6
    ;CH NP MA ME TF 
    ;HHSH HHCH HDSD HDCD 
    ;HHSH2 HHCH2 HDSD2 HDCD2
    
    ;HHSH3 HHCH3 HDSD3 HDCD3
    ;HHSH4 HHCH4 HDSD4 HDCD4
    ;HHSHSD HHSHCD
    ;HHCHSD HHCHCD

    ;HHSHSD2 HHSHCD2
    ;HHSH2SD HHSH2CD
    ;HHCH2SD HHCH2CD
    
    ;HXSHSD HXSHCD
    ;HXCHSD HXCHCD
    ;HXSHSD2 HXSHCD2
    ;HXSH2SD HXSH2CD

    ;DBL
    ;HBL
    

    ; Absolute terms for science CCD
    IH ID 
    ;IH0 ID0 
    ;IH1 ID1
    ;IH2 ID2
    ;IH3 ID3
    CH NP
    MA ME 
    ;TF 

    ;HHSH HHCH 
    ;HHSH2 HHCH2 
    ;HHSH3 HHCH3
    ;HHSH4 HHCH4

    ;HDSD HDCD 
    ;HDSD2 HDCD2
    ;HDSD3 HDCD3
    ;HDSD4 HDCD4

    ;PXH PXD 
    ;PXH2 PXD2 
    ;PXH3 PXD3 
    ;PDH PDD 
    ;PDH2 PDD2 PDH3 PDD3
    ;DBL HBL

    ;ID CH IA
    ;NP MA ME 
    TF 
    ;TX
    FO
    DAF
    
    ;TFSA TFCA 
    ;TFSA2 TFCA2
    ;TFSA3 TFCA3
    ;TFSA4 TFCA4

    ;HHSH  HHCH 
    ;HHSH2 HHCH2 

    ;HXSH  HXCH 
    ;HXSH2 HXCH2 
    ;HXSH3 HXCH3
    ;HXSH4 HXCH4
    
    ;HDSD HDCD 
    ;HDSD2 HDCD2

    ;PXH  PXD 
    ;PXH2 PXD2
    ;PXH3 PXD3
    ;PXH4 PXD4
    ;PXHD
    ;PXHD2
    ;PXD
    ;PXD2

    ;PDH  PDD
    ;PDH2 PDD2
    ;PDH3 PDD3
    ;PDH4 PDD4
    ;PDHD

    ;PZZ
    ;PZZ2
    ;PZZ3
    ;PZZ4

    ;A0
    ;A1
    ;A2

    ))

(display model-term-names)
(newline)

(define m (length model-term-names))
(display m)
(newline)

(define (model-term name p)
  (let loop ((names model-term-names) (p p))
    (cond
      ((null? p) 0.0)
      ((eqv? name (car names)) (car p))
      (else (loop (cdr names) (cdr p))))))

(define (model-x-residual p pointing)
  (- (pointing-x-error pointing) (model-x-error p pointing)))
  
(define (model-y-residual p pointing)
  (- (pointing-y-error pointing) (model-y-error p pointing)))

(define (model-residual p pointing)
  (norm (model-x-residual p pointing) (model-y-residual p pointing)))

(define (model-root-mean-square-x-residual . p)
  (apply root-mean-square (map (lambda (pointing) (model-x-residual p pointing)) pointings)))
  
(define (model-root-mean-square-y-residual . p)
  (apply root-mean-square (map (lambda (pointing) (model-y-residual p pointing)) pointings)))
  
(define (model-root-mean-square-residual . p)
  (norm (apply model-root-mean-square-x-residual p) (apply model-root-mean-square-y-residual p)))
  
(define (model-max-residual . p)
  (apply max (map (lambda (pointing) (model-residual p pointing)) pointings)))
  
(define (model-max-x-residual . p)
  (apply max (map (lambda (pointing) (model-x-residual p pointing)) pointings)))
  
(define (model-max-y-residual . p)
  (apply max (map (lambda (pointing) (model-y-residual p pointing)) pointings)))
  
(define p0 (make-list m 0.0))

;(define p '(-0.00011831664699790318 2.340063762007056e-05 -0.0002844174642485268 4.288508573710784e-05 9.14273429474171e-07 -0.00012791662864909117 0.00010488871498468465 5.0470855053210435e-05 -0.0003700539548401676 0.00014175109004182647 -5.386189689861295e-05 -8.700334762406275e-05))

;(define dp (make-list m 0.0))
(define dp0 (make-list m 0.01))
;(define dp (append '(0.01 0.01) (make-list (- m 2) 0.0)))
;(define dp (append '(0.01 0.0 0.01) (make-list (- m 3) 0.0)))
;(define dp (append '(0.01 0.01 0.01) (make-list (- m 3) 0.0)))

(define ignore-IDx #f)
(define ignore-A0 #f)

(let* (
    (minimize (make-nelder-mead-minimizer 1e-11))
  )
  (let-values (((p1 dp1) (minimize model-root-mean-square-residual p0 dp0)))
    (let-values (((p dp) (minimize model-root-mean-square-residual p1 dp0)))
    
    (set! ignore-IDx #f)
    (set! ignore-A0 #f)

    (display ";; number of pointings:\n;; ")
    (display (length pointings))
    (display "\n")
    
    (display ";; number of parameters:\n;; ")
    (display m)
    (display "\n")

    (display ";; root-mean-square-residual:\n;; ")
    (display (rad->arcsec (apply model-root-mean-square-residual p)))
    (display " arcsec\n")
    (write (apply model-root-mean-square-residual p))
    (newline)

    (display ";; root-mean-square-x-residual:\n;; ")
    (display (rad->arcsec (apply model-root-mean-square-x-residual p)))
    (display " arcsec\n")
    (write (apply model-root-mean-square-x-residual p))
    (newline)

    (display ";; root-mean-square-y-residual:\n;; ")
    (display (rad->arcsec (apply model-root-mean-square-y-residual p)))
    (display " arcsec\n")
    (write (apply model-root-mean-square-y-residual p))
    (newline)

    (display ";; max-residual:\n;; ")
    (display (rad->arcsec (apply model-max-residual p)))
    (display " arcsec\n")
    (write (apply model-max-residual p))
    (newline)

    (display ";; max-x-residual:\n;; ")
    (display (rad->arcsec (apply model-max-x-residual p)))
    (display " arcsec\n")
    (write (apply model-max-x-residual p))
    (newline)

    (display ";; max-y-residual:\n;; ")
    (display (rad->arcsec (apply model-max-y-residual p)))
    (display " arcsec\n")
    (write (apply model-max-y-residual p))
    (newline)

    (display ";; p:\n")
    (for-each 
      (lambda (name) 
        (display " ")
        (display name)
        (display " ")
        (display (rad->arcsec (model-term name p)))
        (display " arcsec\n")) 
      model-term-names)
    (write p)
    (newline)

    (display ";; dp:\n")
    (for-each 
      (lambda (name) 
        (display ";; ")
        (display name)
        (display " ")
        (display (rad->arcsec (model-term name dp)))
        (display " arcsec\n")) 
      model-term-names)
    (write dp)
    (newline)
    
    (display "{\n")
    (for-each 
      (lambda (name) 
        (display "  ")
        (display name)
        (display " ")
        (display (model-term name p))
        (display "\n")) 
      model-term-names)
    (display "}\n")
    (newline)
    
    (for-each
      (lambda (pointing)
        (display ";; ")
        (display (pointing-name pointing))
        (display "\t")
        (display (pointing-night pointing))
        (display "\t")
        (display (exact (round (rad->deg (pointing-mount-h pointing)))))
        (display "\t")
        (display (exact (round (rad->deg (pointing-mount-delta pointing)))))
        (display "\t")
        (display (exact (round (rad->deg (pointing-mount-rotation pointing)))))
        (display "\t")
        (display (exact (round (rad->arcsec (pointing-x-error pointing)))))
        (display "\t")
        (display (exact (round (rad->arcsec (pointing-y-error pointing)))))
        (display "\t")
        (display (exact (round (rad->arcsec (model-x-error p pointing)))))
        (display "\t")
        (display (exact (round (rad->arcsec (model-y-error p pointing)))))
        (display "\t")
        (display (exact (round (rad->arcsec (model-x-residual p pointing)))))
        (display "\t")
        (display (exact (round (rad->arcsec (model-y-residual p pointing)))))
        (newline))
      pointings)
    
    (with-output-to-file "residuals.dat"
      (lambda ()
        (let ((scale 1.0))
          (for-each
            (lambda (pointing)
              (display (rad->deg (pointing-mount-h pointing)))
              (display "\t")
              (display (rad->deg (pointing-mount-delta pointing)))
              (display "\t")
              (display (rad->deg (pointing-mount-z pointing)))
              (display "\t")
              (display (* scale (rad->arcsec (model-x-residual p pointing))))
              (display "\t")
              (display (* scale (rad->arcsec (model-y-residual p pointing))))
              (newline))
            pointings))))

    )))

(exit)
