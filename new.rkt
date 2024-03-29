#lang racket/base

(provide pkg-new)

(require racket/match
         racket/port
         racket/system
         racket/string
         racket/date
         racket/format
         setup/collection-name
         "print.rkt")

(define (package-name? package)
  (regexp-match-exact? #rx"[-_a-zA-Z0-9]*" package))

(define (pkg-new name)

  ;; Useful strings
  (define user
    (string-trim
     (with-output-to-string
         (lambda ()
           (match (system-type)
             [(or 'unix 'macosx)
              (system "whoami")]
             ['windows
              (system "echo %username%")]
             [else (pkg-error "not supported")])))))

  (define ====
    (make-string (string-length name) #\=))

  (define year
    (number->string (date-year (current-date))))

  (define sanitized-name
    (if (string->number name)
        (string-append "|" name "|")
        name))

  ;; Because I wish I had @-expressions
  (define (expand/display str [table (hash #"name" name #"user" user
                                           #"====" ==== #"year" year
                                           #"sanitized-name"
                                           sanitized-name)])
    (let ([in (open-input-string str)])
      (let loop ()
        (let ([m (regexp-match #rx"<<([^>]*)>>" in 0 #f (current-output-port))])
          (when m
            (display (hash-ref table (cadr m)))
            (loop))))))

  ;; Initialize the new package
  (cond
   [(directory-exists? name)
    (pkg-error (format "cannot make package, folder exists~n  path: ~a" name))]
   [(not (package-name? name))
    (pkg-error (format "cannot make package, invalid collection name~n  name:  ~a"
                       name))]
   [else
    (make-directory name)
    (parameterize ([current-directory name])

      ;; LICENSE.txt
      (with-output-to-file "LICENSE.txt"
        (lambda () (expand/display #<<EOS
<<name>>
Copyright (c) <<year>> <<user>>

This package is distributed under the GNU Lesser General Public
License (LGPL).  This means that you can link <<name>> into proprietary
applications, provided you follow the rules stated in the LGPL.  You
can also modify this package; if you distribute a modified version,
you must distribute it under the terms of the LGPL, which in
particular means that you must release the source code for the
modified software.  See http://www.gnu.org/copyleft/lesser.html
for more information.

EOS
)))

      ;; .gitignore
      (with-output-to-file ".gitignore"
        (lambda () (display #<<EOS
*~
\#*
.\#*
.DS_Store
compiled/
/doc/

EOS
)))

      ;; .travis.yml
      (with-output-to-file ".travis.yml"
        (lambda () (expand/display #<<EOS
language: c

# Based on: https://github.com/greghendershott/travis-racket

env:
  global:
    # Supply a global RACKET_DIR environment variable. This is where
    # Racket will be installed. A good idea is to use ~/racket because
    # that doesn't require sudo to install.
    - RACKET_DIR=~/racket
  matrix:
    # Supply at least one RACKET_VERSION environment variable. This is
    # used by the install-racket.sh script (run at before_install,
    # below) to select the version of Racket to download and install.
    #
    # Supply more than one RACKET_VERSION (as in the example below) to
    # create a Travis-CI build matrix to test against multiple Racket
    # versions.
    - RACKET_VERSION=6.12
    - RACKET_VERSION=7.0
    - RACKET_VERSION=7.1
    - RACKET_VERSION=HEAD

matrix:
  allow_failures:
#   - env: RACKET_VERSION=HEAD
  fast_finish: true

before_install:
- git clone https://github.com/greghendershott/travis-racket.git ~/travis-racket
- cat ~/travis-racket/install-racket.sh | bash # pipe to bash not sh!
- export PATH="${RACKET_DIR}/bin:${PATH}" #install-racket.sh can't set for us

install:
 - raco pkg install --auto --name <<name>>

before_script:

# Here supply steps such as raco make, raco test, etc.  You can run
# `raco pkg install --deps search-auto` to install any required
# packages without it getting stuck on a confirmation prompt.
script:
 - raco test -x -p <<name>>

after_success:
 - raco setup --check-pkg-deps --pkgs <<name>>
 - raco pkg install --auto cover cover-coveralls
 - raco cover -b -f coveralls -d $TRAVIS_BUILD_DIR/coverage .

EOS
)))
      ;; info.rkt
      (with-output-to-file "info.rkt"
        (lambda () (expand/display #<<EOS
#lang info
(define collection "<<name>>")
(define deps '("base"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/<<name>>.scrbl" ())))
(define pkg-desc "Description Here")
(define version "0.0")
(define pkg-authors '(<<user>>))

EOS
)))

      ;; README.md
      (with-output-to-file "README.md"
        (lambda () (expand/display #<<EOS
<<name>>
<<====>>
README text here.

EOS
)))

      ;; main.rkt
      (with-output-to-file "main.rkt"
(lambda () (display #<<EOS
#lang racket/base

(module+ test
  (require rackunit))

;; Notice
;; To install (from within the package directory):
;;   $ raco pkg install
;; To install (once uploaded to pkgs.racket-lang.org):
;;   $ raco pkg install <<name>>
;; To uninstall:
;;   $ raco pkg remove <<name>>
;; To view documentation:
;;   $ raco docs <<name>>
;;
;; For your convenience, we have included a LICENSE.txt file, which links to
;; the GNU Lesser General Public License.
;; If you would prefer to use a different license, replace LICENSE.txt with the
;; desired license.
;;
;; Some users like to add a `private/` directory, place auxiliary files there,
;; and require them in `main.rkt`.
;;
;; See the current version of the racket style guide here:
;; http://docs.racket-lang.org/style/index.html

;; Code here



(module+ test
  ;; Any code in this `test` submodule runs when this file is run using DrRacket
  ;; or with `raco test`. The code here does not run when this file is
  ;; required by another module.

  (check-equal? (+ 2 2) 4))

(module+ main
  ;; (Optional) main submodule. Put code here if you need it to be executed when
  ;; this file is run using DrRacket or the `racket` executable.  The code here
  ;; does not run when this file is required by another module. Documentation:
  ;; http://docs.racket-lang.org/guide/Module_Syntax.html#%28part._main-and-test%29

  (require racket/cmdline)
  (define who (box "world"))
  (command-line
    #:program "my-program"
    #:once-each
    [("-n" "--name") name "Who to say hello to" (set-box! who name)]
    #:args ()
    (printf "hello ~a~n" (unbox who))))

EOS
)))
      (make-directory "scribblings")
      (parameterize ([current-directory "scribblings"])

        ;; scribblings/name.scrbl
        (with-output-to-file (format "~a.scrbl" name)
          (lambda () (expand/display #<<EOS
#lang scribble/manual
@require[@for-label[<<sanitized-name>>
                    racket/base]]

@title{<<name>>}
@author{<<user>>}

@defmodule[<<sanitized-name>>]

Package Description Here

EOS
)))))]))
