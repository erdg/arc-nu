#! /usr/bin/env racket
#lang racket/base

(require racket/cmdline)
(require racket/path)

(define all?   #f)
(define debug? #f)
(define repl?  #f)

(define arguments
  (command-line
    #:program "Arc/Nu"
    #:once-each
    [("-a" "--all")   "Execute every file rather than only the first"
                      (set! all? #t)]
    [("-d" "--debug") "Turns debug mode on, causing extra messages to appear"
                      (set! debug? #t)]
    [("-i" "--repl")  "Always execute the repl"
                      (set! repl? #t)]
    #:args args
    args))

(if all?
    (current-command-line-arguments (make-vector 0))
    (current-command-line-arguments (list->vector arguments)))

(define exec-dir  (path-only (normalize-path (find-system-path 'run-file))))
(define exec-path (build-path exec-dir "01 nu"))

(parameterize ((current-namespace (make-base-namespace)))
  (namespace-require exec-path)
  ((eval 'w/init) exec-dir exec-path
    (lambda (ac-load)
      #|(when debug?
        (nu-eval (= debug? t)))|#

      (unless (null? arguments)
        (if all?
            (for ((x arguments))
              (ac-load x))
            (ac-load (car arguments))))

      (when (or repl? (null? arguments))
        (ac-load (build-path exec-dir "05 repl"))))))
