#lang racket/base

(require racket/runtime-path
         (for-syntax racket/base)
         "system-parameters.rkt")


(provide (all-defined-out))


(define-runtime-path root-path (build-path 'up))

(define-runtime-path testing-dir
  (build-path 'up "testing"))

(define-runtime-path lessons-dir
  (build-path 'up "lessons"))

(define-runtime-path courses-base
  (build-path 'up "courses"))

(define-runtime-path static-pages-path
  (build-path 'up "static-pages"))

(define (get-units-dir)
  (build-path courses-base (current-course) "units"))

(define (get-course-main)
  (build-path courses-base (current-course) "main.scrbl"))

(define (get-resources)
  (build-path courses-base (current-course) "resources"))

(define (get-workbook-dir)
  (build-path (get-resources) "workbook"))
  
(define (get-teachers-guide)
  (build-path courses-base (current-course) "resources" "teachers" "teachers-guide" "teachers-guide.scrbl"))

(define (get-worksheet-pdf-path)
  (build-path courses-base (current-course) "resources" "workbook" "StudentWorkbook.pdf"))
