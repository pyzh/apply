(defmacro define-macro
  (λ (p . v)
    `(defmacro ,(car p)
       (λ ,(cdr p)
         ,@v))))

(define-macro (let p . v)
    `((λ ,(map car p)
        ,@v)
      ,@(map second p)))

(defmacro define
  (λ (f . v)
    (if (pair? f)
        `(def ,(car f)
           (λ ,(cdr f)
             ,@v))
        `(def ,f
           ,@v))))

(define first car)
(define (second x) (car (cdr x)))
(define cadr second)
(define (third x) (car (cdr (cdr x))))
(define caddr third)
(define (cadar x) (car (cdr (car x))))

(defmacro and
  (λ xs
    (cond
      [(null? xs) #t]
      [(null? (cdr xs)) (car xs)]
      [else (let ([a (mcsym 'a)])
              `(let ([,a ,(car xs)])
                 (if ,a
                     ,a
                     (and ,@(cdr xs)))))])))

(defmacro vector
  (λ xs
    `(vec '_v ,@xs)))

(define (vector? x)
  (and (vec? x) (equal? (car x) '_v)))
