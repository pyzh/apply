#lang racket
;;  Copyright (C) 2017  Zaoqi

;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU Affero General Public License as published
;;  by the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.

;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU Affero General Public License for more details.

;;  You should have received a copy of the GNU Affero General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

(provide c)
(require racket/sandbox)
(require "p.rkt")

(define-syntax-rule (includes f)
  (include/reader
   f
   (λ (source-name in)
     (let ([x (read-line in)])
       (if (eof-object? x)
           eof
           (let loop ([s x])
             (let ([x (read-line in)])
               (if (eof-object? x)
                   (datum->syntax #f s)
                   (loop (string-append s "\n" x))))))))))

(define-syntax-rule (ps [x v] ...)
  (make-hasheq
   (list
    (cons (quote x) (symbol->string (quote v))) ...)))

(define ids (ps
             [+ add]
             [- sub]
             [* mul]
             [/ quo]
             [> gt]
             [< lt]
             [= eq]
             [>= gteq]
             [<= lteq]
             [and2 and2]
             [or2 or2]
             [not notf]
             [luatype type]
             [null? is_null]
             [pair? is_pair]
             [cons cons]
             [car car]
             [cdr cdr]
             [vec vector]
             [vec? is_vector]
             [vec-ref vector_ref]
             [symbol? is_symbol]
             [string->symbol symbol]
             [symbol->syring sym2str]
             [string? is_string]
             [void voidf]
             [equal? eq]
             [atom? is_atom]
             [atom! atom]
             [atom-map! atom_map]
             [atom-set! atom_set]
             [atom-get atom_get]
             [assert assert]))

(define-syntax-rule (exp x ...)
  (stream "(" x ... ")"))

(define-syntax-rule (block x ...)
  (stream (exp "function()"
               x ...
               " end") "()"))

(define-syntax-rule (var nme xc)
  (let ([x xc])
    (begin
      (set! nme (upme nme x))
      (stream "local " (newvarid x) "=nil "))))

(define-syntax-rule (setc me ms x v)
  (stream (id me x) "=" (EVAL me ms v) " "))

(define (APPLY me ms f xs)
  (let ([f (macroexpand ms f)])
    (cond
      [(eq? f 'λ)
       (let ([me me])
         (for ([x (car xs)])
           (set! me (upme me x)))
         (exp "function(" (mkss (car xs)) ")"
              "return " (BEGIN me ms (cdr xs))
              " end"))]
      [(eq? f 'letrec) (LETREC me ms xs)]
      [(eq? f 'if)
       (block "if " (EVAL me ms (car xs))
              " then return " (EVAL me ms (second xs))
              " else return " (EVAL me ms (third xs))
              " end")]
      [(eq? f 'begin) (BEGIN me ms xs)]
      [(eq? f 'set!) (setc me ms (car xs) (second xs))]
      [(eq? f 'ffi) (FFI (car xs))]
      [(eq? f 'quote) (QUOTE (car xs))]
      [else (stream (EVAL me ms f) "(" (%apply me ms xs) ")")])))

(define (%apply me ms xs)
  (cond
    [(null? xs) ""]
    [(null? (cdr xs)) (EVAL me ms (car xs))]
    [else (stream (EVAL me ms (car xs)) "," (%apply me ms (cdr xs)))]))

(define (mkss xs)
  (cond
    [(null? xs) ""]
    [(null? (cdr xs)) (newvarid (car xs))]
    [else (stream (newvarid (car xs)) "," (mkss (cdr xs)))]))

(define (BEGIN me ms xs)
  (let ([xs (filter-not (λ (x) (equal? x '(void)))
                        (map (λ (x) (macroexpand ms x)) xs))])
    (if (null? (cdr xs))
        (EVAL me ms (car xs))
        (let ([me me])
          (block
           (map (λ (x)
                  (var me (second x)))
                (filter (λ (x) (and (pair? x) (eq? (car x) 'def))) xs))
           (let loop ([x (car xs)] [xs (cdr xs)])
             (if (and (pair? x) (or (eq? (car x) 'set!) (eq? (car x) 'def)))
                 (stream
                  (setc me ms (second x) (third x))
                  (if (null? xs)
                      "return void"
                      (loop (car xs) (cdr xs))))
                 (if (null? xs)
                     (stream
                      "return " (EVAL me ms x))
                     (stream
                      "ig(" (EVAL me ms x) ")"
                      (loop (car xs) (cdr xs)))))))))))

(define (upme me x)
  (if (macrosym? x)
      (set-add me x)
      me))

(define idc 0)
(define (mknewid x)
  (set! idc (+ 1 idc))
  (string-append
   "zs"
   (number->string idc)
   "_"
   (list->string (map
                  (λ (x) (if (or (char-alphabetic? x) (char-numeric? x)) x #\_))
                  (string->list (symbol->string x))))))

(define (id me x)
  (cond
    [(set-member? me x) (newvarid x)]
    [(symbol? x) (hash-ref! ids x (λ () (mknewid x)))]
    [else (id me (macrosym-sym2 x))]))

(define (macrosym-id2 x)
  (if (macrosym? x)
      (macrosym-id x)
      (let ([v (struct->vector x)])
        (and (eq? (vector-ref v 0) 'struct:macrosym)
             (vector-ref v 1)))))

(define (macrosym-sym2 x)
  (if (macrosym? x)
      (macrosym-id x)
      (let ([v (struct->vector x)])
        (and (eq? (vector-ref v 0) 'struct:macrosym)
             (vector-ref v 2)))))

(define (newvarid x)
  (if (symbol? x)
      (id (set) x)
      (string-append
       "zsm"
       (number->string (macrosym-id2 x))
       "_"
       (symbol->string (macrosym-sym2 x)))))

(define (LETREC me ms xs)
  (BEGIN me ms (append (map (λ (p) (list 'def (car p) (cdr p))) (car xs)) (cdr xs))))

(define (EVAL me ms x)
  (let ([x (macroexpand ms x)])
    (cond
      [(symbol? x) (id me x)]
      [(struct? x) (id me x)]
      [(pair? x) (APPLY me ms (car x) (cdr x))]
      [(null? x) "null"]
      [(number? x) (number->string x)]
      [(eq? x #t) "true"]
      [(eq? x #f) "false"]
      [(string? x) (stream "\"" x "\"")]
      [else (error)])))

(define (e x)
  (cond
    [(or (null? x) (and (stream? x) (stream-empty? x))) ""]
    [(stream? x) (string-append (e (stream-first x)) (e (stream-rest x)))]
    [(list? x) (string-append (e (car x)) (e (cdr x)))]
    [else x]))

(define pre (includes "prelude.lua"))
(define (rs s)
  (read (open-input-string (string-append "(" s ")"))))
(define prescm (rs (includes "prelude.scm")))

(define (c x)
  (endc
   (e
    (EVAL (set) (make-hasheq)
          (append (list 'begin)
                  prescm
                  x)))))

(define (endc x)
  (string-append
   pre
   "return " x))

(define (FFI x)
  (stream "l2sv(" (symbol->string x) ")"))

(define evalr (make-evaluator 'racket #:requires '("p.rkt")))

(define (macroexpand ms x)
  (cond
    [(and (pair? x) (eq? (car x) 'defmacro))
     (hash-set! ms (second x) (evalr (third x)))
     '(void)]
    [(and (pair? x) (hash-ref ms (car x) #f)) => (λ (mf) (macroexpand ms (apply mf (cdr x))))]
    [else x]))

(define (QUOTE x)
  (cond
    [(symbol? x) (stream "symbol(\"" (symbol->string x) "\")")]
    [(pair? x) (stream "cons(" (QUOTE (car x)) "," (QUOTE (cdr x)) ")")]
    [(null? x) "null"]
    [(eq? x #t) "true"]
    [(eq? x #f) "false"]
    [(number? x) (number->string x)]
    [(string? x) (stream "\"" x "\"")]
    [(struct? x) (QUOTE (macrosym-sym2 x))]
    [else (error)]))

(define (read* port)
  (let ([x (read-line port)])
    (if (eof-object? x)
        ""
        (string-append x "\n" (read* port)))))

(displayln (c (rs (read* (current-input-port)))))
