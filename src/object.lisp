;;; -*- Mode: Lisp; Syntax: COMMON-LISP; Base: 10 -*-

;; cl-git an Common Lisp interface to git repositories.
;; Copyright (C) 2011-2012 Russell Sim <russell.sim@gmail.com>
;;
;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU Lesser General Public License
;; as published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Lesser General Public License for more details.
;;
;; You should have received a copy of the GNU Lesser General Public
;; License along with this program.  If not, see
;; <http://www.gnu.org/licenses/>.

(in-package #:cl-git)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Low-level interface
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defcenum git-object-type
  (:any -2)       ; Object can be any of the following
  (:bad -1)       ; Object is invalid.
  (:commit 1)     ; A commit object.
  (:tree 2)       ; A tree (directory listing) object.
  (:blob 3)       ; A file revision object.
  (:tag 4)        ; An annotated tag object.
  (:ofs-delta 6)  ; A delta, base is given by an offset.
  (:ref-delta 7)) ; A delta, base is given by object id.

(defcfun ("git_object_id" git-object-id)
    %oid
  "Returns the oid identifying OBJECT"
  (object %object))

(defcfun ("git_object_type" git-object-type)
    git-object-type
  "Returns the type of the git object."
  (object %object))

(defcfun ("git_object_lookup" %git-object-lookup)
    %return-value
  (object %object)
  (repo %repository)
  (oid %oid)
  (type git-object-type))

(defcfun ("git_object_free" git-object-free)
    :void
  "Free the git object."
  (object :pointer))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Foreign Type Translation
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmethod translate-to-foreign (value (type git-object))
  (if (pointerp value)
      value
      (pointer value)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Highlevel Interface
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defclass object (git-pointer)
  ((type :accessor object-type :initarg :object-type :initform 'object
	 :documentation "A symbol indicating which libgit2 type this is.
This slot is probably uselss in the sense that we do not necessarily know
on creation time and if we do not know exactly what is the point?
So this is mainly used for printing") ;;; do we need this??
   (libgit2-repository :accessor %repository :initarg :repository-pointer))
  (:documentation "Object encapsulating git objects from libgit2"))


;;; 
(defun make-instance-object (&key object-ptr repository-ptr type)
  "Creates an object wrapping OBJECT-PTR.  
OBJECT-PTR needs to point to one of the git storage types, such as:
:commit :tag :tree or :blob.  This function is not suitable to 
wrap git pointers to repositories, config, index etc."
  (let ((obj-type (case (or (unless (eq type :any) type)
			    (git-object-type object-ptr))
		    (:commit 'commit)
		    (:tag 'tag)
		    (:tree 'tree)
		    (:blob 'blob)
		    (t 'object))))

    (make-instance obj-type
		   :pointer object-ptr
		   :repository-pointer (or repository-ptr *git-repository*)
		   :object-type obj-type
		   :free-function #'git-object-free)))

(defun git-object-lookup (oid type)
  "Returns a reference to the git odb (object) which is identified by the OID.
The type argument specifies which type is expected.  If the found
object is not of the right type, an error will be signaled.  The type
is one of :ANY, :BAD, :COMMIT :TREE :BLOB :TAG :OFS-DELTA :REFS-DELTA.
:ANY and :BAD are special cases.  :ANY means return the object found,
do not do a typecheck and is a valid type, but should typically not
occur.

Note that the returned git object should be freed with GIT-OBJECT-FREE."

  (assert (not (null-or-nullpointer *git-repository*)))

  (with-foreign-object (obj-ptr :pointer)
    (%git-object-lookup obj-ptr *git-repository* oid type)
    (make-instance-object :object-ptr (mem-ref obj-ptr :pointer))))



;; Copy the documentation to the generic function so
;; we do not have to write it twice.
(setf (documentation #'git-lookup 'function) 
      (documentation #'git-object-lookup 'function))

(setf (documentation #'git-type 'function)
      (documentation #'git-object-type 'function))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Some generic functions
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod git-parent-oids (object)
  "Returns a list of oids identifying the parents of OBJECT."
  (loop
    :for index :from 0 :below (git-parentcount object)
    :collect (git-parent-oid object index)))


(defmethod git-lookup (oid &key (type :any))
  (git-object-lookup oid type))

(defmethod git-type ((object object))
  (git-object-type object))

(defmethod git-entries (object)
  "Return all entries of OBJECT as a list.

Note that this is basically a wrapper around GIT-ENTRY-BY-INDEX, 
so the objects returned are the same as the ones returned by GIT-ENTRY-BY-INDEX."
  (loop :repeat (git-entry-count object)
        :for index :from 0
        :collect (git-entry-by-index object index)))

