;;;;  -*- Mode: Lisp; Syntax: Common-Lisp; Package: C -*-
;;;;
;;;;  Copyright (c) 2006, Juan Jose Garcia-Ripoll
;;;;
;;;;    This program is free software; you can redistribute it and/or
;;;;    modify it under the terms of the GNU Library General Public
;;;;    License as published by the Free Software Foundation; either
;;;;    version 2 of the License, or (at your option) any later version.
;;;;
;;;;    See file '../Copyright' for full details.

;;;; CMPSTACK Manipulation of the lisp stack from C code
;;;;
;;;; Following special forms are provided:
;;;;
;;;;	(WITH-STACK {form}*)
;;;;		Executes given forms, restoring the lisp stack on output.
;;;;	(STACK-PUSH form)
;;;;	(STACK-PUSH-VALUES form)
;;;;	(STACK-POP nvalues)
;;;;

(in-package "COMPILER")

(defconstant +ecl-stack-frame-variable+ "_ecl_inner_frame")

(defconstant +ecl-local-stack-frame-variable+ "__frame")

(defconstant +ecl-local-stack-variable+ "__frame_sp")

(defun c1with-stack (forms)
  (let* ((var (pop forms))
	 (body (c1expr `(let ((,var (innermost-stack-frame))) ,@forms))))
      (make-c1form* 'WITH-STACK
		    :type (c1form-type body)
		    :args body)))

(defun c2with-stack (body)
  (let* ((new-destination (tmp-destination *destination*))
	 (*temp* *temp*))
    (wt-nl "{ struct ecl_stack_frame _ecl_inner_frame_aux;")
    (wt-nl *volatile* "cl_object _ecl_inner_frame = ecl_stack_frame_open(cl_env_copy,(cl_object)&_ecl_inner_frame_aux,0);")
    (let* ((*destination* new-destination)
	   (*unwind-exit* `((STACK ,+ecl-stack-frame-variable+) ,@*unwind-exit*)))
      (c2expr* body))
    (wt-nl "ecl_stack_frame_close(_ecl_inner_frame);}")
    (unwind-exit new-destination)))

(defun c1innermost-stack-frame (args)
  (c1expr `(c-inline () () :object ,+ecl-stack-frame-variable+
	    :one-liner t :side-effects nil)))

(defun c1stack-push (args)
  (c1expr `(progn
	     (c-inline ,args (t t) :void "ecl_stack_frame_push(#0,#1)"
		       :one-liner t :side-effects t)
	     1)))

(defun c1stack-push-values (args)
  (let ((frame-var (pop args))
	(form (pop args)))
    (make-c1form* 'STACK-PUSH-VALUES :type '(VALUES)
		  :args
		  (c1expr form)
		  (c1expr `(c-inline (,frame-var) (t) :void "ecl_stack_frame_push_values(#0)"
				     :one-liner t :side-effects t)))))

(defun c2stack-push-values (form push-statement)
  (let ((*destination* 'VALUES))
    (c2expr* form))
  (c2expr push-statement))

(defun c1stack-pop (args)
  (c1expr `(c-inline ,args (t) (values &rest t)
		     "cl_env_copy->values[0]=ecl_stack_frame_pop_values(#0);"
		     :one-liner nil :side-effects t)))

(defun c1apply-from-stack-frame (args)
  (c1expr `(c-inline ,args (t t) (values &rest t)
		     "cl_env_copy->values[0]=ecl_apply_from_stack_frame(cl_env_copy,#0,#1);"
		     :one-liner nil :side-effects t)))

(put-sysprop 'with-stack 'C1 #'c1with-stack)
(put-sysprop 'with-stack 'c2 #'c2with-stack)
(put-sysprop 'innermost-stack-frame 'C1 #'c1innermost-stack-frame)
(put-sysprop 'stack-push 'C1 #'c1stack-push)
(put-sysprop 'stack-push-values 'C1 #'c1stack-push-values)
(put-sysprop 'stack-push-values 'C2 #'c2stack-push-values)
(put-sysprop 'stack-pop 'C1 #'c1stack-pop)
(put-sysprop 'si::apply-from-stack-frame 'c1 #'c1apply-from-stack-frame)