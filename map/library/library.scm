(for-each 
  (lambda (file)
    (load (string-append scheme-library-directory "/" file ".scm")))
  '(
    "control"
    "numbers"
    "lists"
    "nelder-mead-minimizers"
  ))
