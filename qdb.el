;;; qdb.el --- Python remote debugger functions

;; Copyright (C)  2013, 2014 Austin Bingham <austin.bingham@gmail.com>

;; Author: Austin Bingham <austin.bingham@gmail.com>
;; Version: 0.1
;; URL: https://github.com/abingham/qdb.el

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'gud)

;; History of argument lists passed to qdb.
(defvar gud-qdb-history nil)

; "> filename.py(1234)\n-> code-and-stuff\n (Cmd) "  OK
;  "> <frozen importlib._bootstrap>(870)\n->  (Cmd) " FAIL
(defvar gud-qdb-marker-regexp
  "^> \\([-a-zA-Z0-9_/.:\\<>]*\\)(\\([0-9]+\\))[\n\r]->.*[\n\r]")

(defvar gud-qdb-marker-regexp-file-group 1)
(defvar gud-qdb-marker-regexp-line-group 2)
; (defvar gud-qdb-marker-regexp-fnname-group 3)

(defvar gud-qdb-marker-regexp-start "^> ")

;; There's no guarantee that Emacs will hand the filter the entire
;; marker at once; it could be broken up across several strings.  We
;; might even receive a big chunk with several markers in it.  If we
;; receive a chunk of text which looks like it might contain the
;; beginning of a marker, we save it here between calls to the
;; filter.
(defun gud-qdb-marker-filter (string)
  (setq gud-marker-acc (concat gud-marker-acc string))
  (let ((output ""))

    ;; Process all the complete markers in this chunk.
    (while (string-match gud-qdb-marker-regexp gud-marker-acc)
      (setq

       ;; Extract the frame position from the marker.
       gud-last-frame
       (let ((file (match-string gud-qdb-marker-regexp-file-group
				 gud-marker-acc))
	     (line (string-to-number
		    (match-string gud-qdb-marker-regexp-line-group
				  gud-marker-acc))))
	 (if (string-equal file "<string>")
	     gud-last-frame
	   (cons file line)))

       ;; Output everything instead of the below
       output (concat output (substring gud-marker-acc 0 (match-end 0)))
;;	  ;; Append any text before the marker to the output we're going
;;	  ;; to return - we don't include the marker in this text.
;;	  output (concat output
;;		      (substring gud-marker-acc 0 (match-beginning 0)))

       ;; Set the accumulator to the remaining text.
       gud-marker-acc (substring gud-marker-acc (match-end 0))))

    ;; Does the remaining text look like it might end with the
    ;; beginning of another marker?  If it does, then keep it in
    ;; gud-marker-acc until we receive the rest of it.  Since we
    ;; know the full marker regexp above failed, it's pretty simple to
    ;; test for marker starts.
    (if (string-match gud-qdb-marker-regexp-start gud-marker-acc)
	(progn
	  ;; Everything before the potential marker start can be output.
	  (setq output (concat output (substring gud-marker-acc
						 0 (match-beginning 0))))

	  ;; Everything after, we save, to combine with later input.
	  (setq gud-marker-acc
		(substring gud-marker-acc (match-beginning 0))))

      (setq output (concat output gud-marker-acc)
	    gud-marker-acc ""))

    output))

(defcustom gud-qdb-command-name "qdb"
  "File name for executing the Python debugger.
This should be an executable on your path, or an absolute file name."
  :type 'string
  :group 'gud)

;;;###autoload
(defun qdb (command-line)
  "Run qdb on program FILE in buffer `*gud-FILE*'.
The directory containing FILE becomes the initial working directory
and source-file directory for your debugger."
  (interactive
   (list (gud-query-cmdline 'qdb)))

  (gud-common-init command-line nil 'gud-qdb-marker-filter)
  (set (make-local-variable 'gud-minor-mode) 'qdb)

  (gud-def gud-break  "break %d%f:%l"  "\C-b" "Set breakpoint at current line.")
  (gud-def gud-remove "clear %d%f:%l"  "\C-d" "Remove breakpoint at current line")
  (gud-def gud-step   "step"         "\C-s" "Step one source line with display.")
  (gud-def gud-next   "next"         "\C-n" "Step one line (skip functions).")
  (gud-def gud-cont   "continue"     "\C-r" "Continue with display.")
  (gud-def gud-finish "return"       "\C-f" "Finish executing current function.")
  (gud-def gud-up     "up"           "<" "Up one stack frame.")
  (gud-def gud-down   "down"         ">" "Down one stack frame.")
  (gud-def gud-print  "p %e"         "\C-p" "Evaluate Python expression at point.")
  ;; Is this right?
  (gud-def gud-statement "! %e"      "\C-e" "Execute Python statement at point.")

  ;; (setq comint-prompt-regexp "^(.*qdb[+]?) *")
  (setq comint-prompt-regexp "^ *(Cmd) *")
  (setq paragraph-start comint-prompt-regexp)
  (run-hooks 'qdb-mode-hook))

(provide 'qdb)

;;; qdb.el ends here
