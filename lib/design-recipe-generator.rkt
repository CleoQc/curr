#lang racket

(require scribble/base
         scribble/core
         scribble/decode
         scribble/basic
         (prefix-in manual: scribble/manual)
         scribble/html-properties
         scribble/latex-properties
         scriblib/render-cond
         "scribble-helpers.rkt"
         "styles.rkt"
         "sxml.rkt"
         "racket2pyret.rkt"
         "escape-values.rkt"
         "process-code.rkt"
         )

(provide design-recipe-exercise
         )

;; temporary cheat around having a solutions mode that displays all code
(define (always-show?) #t)

;;;;;;;;; API for Design Receipe Exercises ;;;;;;;;;;;;;;;;;;;;;

(define htmlRarr (cond-element [html (sxml->element 'rarr)] [else "->"]))
(define contract-label "contract:")
(define purpose-label "#")

(define (atom? v) (not (list? v)))

;;;;;;;;; formatting helpers ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (make-wrapper . contents)
  (nested #:style (bootstrap-div-style "wrapper")
          (interleave-parbreaks/all contents))) 

(define (make-spacer contents)
  (para #:style (bootstrap-span-style "spacer") contents))

(define (make-clear)
  (para #:style (bootstrap-span-style "clear") ""))

;; format values for display in exercises.  Handles escapes for things like dollar amounts
(define (format-exercise-text e #:fmt-quotes? (fmt-quotes? #t))
  (cond [(number? e) (format "~a " e)]
        [(string? e) (cond [(money-escaped? e) (format "~a " (~r (rem-money-escape e) #:precision '(= 2)))]
                           [fmt-quotes? (format "~s " e)]
                           [else (format "~a " e)])]
        [(list? e) (string-append "(" 
                                  (apply string-append (map (lambda (c) (format-exercise-text c #:fmt-quotes? fmt-quotes?)) e))
                                  ")")]
        [else (format "~a " e)]))

;;;;;;;;;; DR segments ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (design-recipe-section id title instructions . body)
  (nested #:style (bootstrap-div-style/id/nested id)
          (interleave-parbreaks/all
           (append (list (para #:style (bootstrap-div-style "sectionTitle") title)
                         (para #:style (bootstrap-div-style "sectionInstructions") instructions))
                   (interleave-parbreaks/all body)))))     
  
;; return sublist of L containing all but the last argument
(define (all-but-last L) (reverse (rest (reverse L))))

;; format a list as a string with spaces between each element
(define (list->spaced-string L)
  (apply string-append (map (lambda (e) (format-exercise-text e)) L)))

;; Create a design-recipe exercise
;;   funname: string naming the function
;;   directions: instructions for the problem 
;; num-examples says how many examples to generate.  Some of the examples may be specified
;;   by populating the example-list and configuring show-examples (keep reading)
;; example-list is a list of lists giving the input and output: e.g., (list (list 5 '(* 5 2)))
;;   the list contents can be num/string/sexp -- anything that format can convert to a string
;; show-examples is a list of configurations of which parts of each elt in example-list to show
;;    - each configuration is either a boolean or a list of three booleans
;;    - e.g., show-examples of (list #f (list #t #f #t) #t) says
;;      * don't show any components of the first example in example-list
;;      * show the function name and output of the second example in example-list
;;      * show all components of the third example in example-list
;;    - show-examples cannot be longer than example-list  
;;    - if show-examples is shorter than example-list, remaining elts in example-list get configuration #f
;; if num-examples is larger than length of example-list, additional blank exercises are added after the
;;   contents of example-list
(define (design-recipe-exercise funname directions
                                #:show-funname-contract? (show-funname-contract? #f)
                                #:domain-list (domain-list '()) ; list of string
                                #:show-domains? (show-domains? #f) 
                                #:range (range #f)
                                #:show-range? (show-range? #f)
                                #:purpose (purpose #f)
                                #:show-purpose? (show-purpose? #f)
                                #:num-examples (num-examples 1) ; number of total example spaces to generate
                                #:example-list (example-list '()) ;concrete examples -- see doc above func for details
                                #:show-examples (show-examples '()) ; see doc above func for details
                                #:show-funname-defn? (show-funname-defn? #f)
                                #:param-list (param-list '()) ; list of string
                                #:show-params? (show-params? #f) 
                                #:body (body #f) ; a string
                                #:show-body? (show-body? #f)
                                #:grid-lines? (grid-lines? #f)
                                )
  ; INSERT check that show-examples is no longer than example-list
  ; ALSO handle num-examples less than length of example-list
  (nested #:style (bootstrap-div-style/extra-id "segment" "exercises")
          (interleave-parbreaks/all
           (list
            (para #:style (bootstrap-div-style "exercise-header")
                  (bold "Word Problem:") (string-append " " funname))
            (if (string? directions)
                (para #:style (bootstrap-div-style "exercise-instr")
                      (bold "Directions: ") directions)
                (nested #:style (bootstrap-div-style "exercise-instr")
                        (interleave-parbreaks/all
                         (list
                          (elem (bold "Directions: ") (first directions))
                          (rest directions)))))
            (nested #:style (bootstrap-div-style "designRecipeLayout")
                    (interleave-parbreaks/all
                     (list
                      (design-recipe-section
                       "recipe_contract" 
                       "Contract and Purpose Statement"
                       "Every contract has three parts ..."
                       (make-spacer contract-label)
                       (make-wrapper
                        (dr-student-answer #:id? #f "recipe_name" #:show? show-funname-contract? funname)
                        (para #:style (bootstrap-span-style "") ":")
                        (dr-student-answer "recipe_domain" #:show? show-domains? (string-join domain-list " "))
                        (para #:style (bootstrap-span-style "") htmlRarr)
                        (dr-student-answer "recipe_range" #:show? show-range? range))
                       (make-clear)
                       (make-spacer purpose-label)
                       (make-wrapper
                        (dr-student-answer "recipe_purpose" #:show? show-purpose? purpose)))
                      ;; need one of these for each example provided/expected
                      (design-recipe-section 
                        "recipe_examples"
                        "Examples"
                        "Write some examples of your function in action..."
                        (let ([example-elts 
                               (let ([num-blank-examples (- num-examples (length example-list))])
                                 (append 
                                  ; generate contents of example-list according to show-examples
                                  (map (lambda (e s) 
                                         ; e is either empty or a two-element list of input and output
                                         ; s is either a boolean or a three-element list of booleans
                                         ;   indicating whether to show the funname/input/output
                                         (dr-example funname e
                                                     #:show-funname? (show-example-component? s 'funname)
                                                     #:show-input? (show-example-component? s 'input)
                                                     #:show-output? (show-example-component? s 'output))) 
                                       example-list
                                       ; pad show-examples to match length of example-list
                                       ; padding value of #f means default is to not show example
                                       (append show-examples
                                               (build-list (- (length example-list) (length show-examples))
                                                           (lambda (i) #f))))
                                  ; pad example list with empty examples to get to specified num-examples
                                  (build-list num-blank-examples (lambda (i) (dr-example funname '())))
                                 ))])
                          ; insert clear-breaks between examples and merge the example content lists
                          ;; NEED TO GET SINTRAPARAS OUT OF HERE
                          (append (list "checks:")
                                  (foldr (lambda (e res-rest) (append (cons (make-clear) e) res-rest))
                                         '() example-elts)
                                  (list "end")))
                        )
                      (design-recipe-section 
                       "recipe_definition"
                       "Definition"
                       "Write the definition, giving variable names to all your input values..."
                       (make-spacer "fun ")
                       (make-wrapper
                        (dr-student-answer #:id? #f "recipe_name" #:show? show-funname-defn? funname)
                        (make-spacer "(")
                        (dr-student-answer "recipe_variables" #:show? show-params? (string-join param-list ", "))
                        (make-spacer "):")
                        ;(make-clear)  ; only force this for long-form DR (maybe via a flag?)
                        (dr-body body #:show show-body?)
                        ;(dr-student-answer "recipe_definition_body" #:show? show-body? #:parse-as-pyret? #t body)
                        (make-clear))
                       (make-spacer "end"))
                      )))))))

;;;;;;;;; Examples ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; retrieves info on whether to show named component from given spec
;; currently, spec is either a boolean or a list of three booleans
;;   corresponding to the funname, input, or output, respectively
(define (show-example-component? spec comp)
  (let [(pos (case comp 
               [(funname) first]
               [(input) second]
               [(output) third]))]
    (or (and (boolean? spec) spec) 
        (and (cons? spec) (pos spec)))))

;; generate an example within a design recipe activity
;; in-out-list is either empty or a list with the input and output expressions
;;   these expressions can be any type, but will be formatted to strings
;; the optional show arguments control which parts of the example are displayed
(define (dr-example funname in-out-list
                    #:show-funname? (show-funname? #f) 
                    #:show-input? (show-input? #f)
                    #:show-output? (show-output? #f)
                    )
  (let ([input (if (empty? in-out-list) "" (format-pyret-arglist (all-but-last in-out-list)))]
        [output (if (empty? in-out-list) "" (last in-out-list))])
    (interleave-parbreaks/all
     (list (make-wrapper
            (dr-student-answer #:id? #f "recipe_name" #:show? show-funname? funname)
            (make-spacer "(")
            (dr-student-answer #:id? #f "recipe_example_inputs" #:show? show-input? input)
            (make-spacer ")")
            (make-spacer "is")
            ;(make-clear) ; only force this for long-form DR (maybe via a flag?)
            (dr-student-answer #:id? #f "recipe_example_body" #:show? show-output? #:parse-as-pyret? #t output)
            )
           ))))

;;;;;;;;;; Function Bodies ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; format the body of a design recipe worksheet -- formatting may depend on body contents
(define (dr-body body #:show (show #f))
  (if body
      (let ([body-contents body]) ;(with-input-from-string body read)])
        (cond [(atom? body-contents) (dr-student-answer "recipe_definition_body" #:show? show body)]
              [(eq? (first body-contents) 'cond) 
               (let ([clauselines 
                      (map (lambda (c s) 
                             (make-wrapper
                              (dr-student-answer "recipe_definition_body clause question" (first c) #:show? (if (list? s) (first s) s) #:fmt-quotes? #t)
                              ; how to handle this syntax in terms of blanks?
                              (make-spacer "=>")
                              (dr-student-answer "recipe_definition_body clause answer" (second c) #:show? (if (list? s) (second s) s) #:fmt-quotes? #t)
                              ))
                           (rest body-contents) 
                           ; show is either a single boolean or a list of specs with same length as number of clauses
                           (if (not show) (build-list (length (rest body-contents)) (lambda (i) #f))
                               (rest show)))])
                 (apply make-wrapper
                        (append (list (dr-student-answer "recipe_definition_body ask" #:show? #f "ask:" #:fmt-quotes? #f))
                                clauselines
                                (list (dr-student-answer "recipe_definition_body end" #:show? #f "end" #:fmt-quotes? #f)))))]
              [else ;; assume single-line expression for now
               (dr-student-answer "recipe_definition_body" #:show? show body)]))
      ;; eventually, this should become a warning about the body missing
      (dr-student-answer "recipe_definition_body" #:show? show body)))

;;;;;;;;; Answers (that fill in blanks) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (dr-student-answer class-or-id answer 
                           #:id? (id? #t)
                           #:parse-as-pyret? (parse-as-pyret? #t)
                           #:show? (show? #f) 
                           #:fmt-quotes? (fmt-quotes? #f)
                           )
  (let* ([show-contents? (or show? (always-show?))]
         [base-style (if show-contents? "studentAnswer" "studentAnswer blank")]
         [style (if id? 
                    (bootstrap-span-style/extra-id base-style class-or-id) 
                    (bootstrap-span-style (string-append base-style " " class-or-id)))]
         [converted-ans (if parse-as-pyret? (format-oneline-bs1-as-pyret answer) answer)])
    (para #:style style
          (cond [show-contents? (format-exercise-text converted-ans #:fmt-quotes? #f)]
                [(string? answer) (make-string (string-length converted-ans) #\M)]
                [else  " "]))))
