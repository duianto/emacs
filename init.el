;; -*- mode: emacs-lisp; coding: utf-8-unix; indent-tabs-mode: nil -*-
;;; init.el
;;
;; Copyright(C) Youhei SASAKI All rights reserved.
;; $Lastupdate: 2011/11/26 08:48:47$
;;
;; Author: Youhei SASAKI <uwabami@gfd-dennou.org>
;; License: GPL-3+
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;;; Code:
;; -----------------------------------------------------------
(eval-when-compile (require 'cl))
;; -----------------------------------------------------------
;; 名前とメールアドレス
(setq user-full-name "Youhei SASAKI")
(setq user-mail-address "uwabami@gfd-dennou.org")
;; -----------------------------------------------------------
;;; Emacs の種類/バージョンを判別するための変数を定義
;;
;; @see http://github.com/elim/dotemacs/blob/master/init.el
;;
(defun x->bool (elt) (not (not elt)))
;; Emacs のバージョン
(defvar oldemacs-p (< emacs-major-version 22))
(defvar emacs22-p (equal emacs-major-version 22))
(defvar emacs23-p (equal emacs-major-version 23))
;; Mac の Emacs flavor の判定
(defvar darwin-p (eq system-type 'darwin))
(defvar ns-p (featurep 'ns))
(defvar carbon-p (and (eq window-system 'mac) emacs22-p))
(defvar mac-p (and (eq window-system 'mac) emacs23-p))
;; Linux の判定 <-- BSD とかどうするかな
(defvar linux-p (eq system-type 'gnu/linux))
;; Windows の Emacs flavor の判定
(defvar colinux-p (when linux-p
                    (let ((file "/proc/modules"))
                      (and
                       (file-readable-p file)
                       (x->bool
                        (with-temp-buffer
                          (insert-file-contents file)
                          (goto-char (point-min))
                          (re-search-forward "^cofuse\.+" nil t)))))))
(defvar cygwin-p (eq system-type 'cygwin))
(defvar nt-p (eq system-type 'windows-nt))
(defvar meadow-p (featurep 'meadow))
(defvar windows-p (or cygwin-p nt-p meadow-p))
;; -----------------------------------------------------------
;;; load-path 追加用の変数/関数
;; @see http://sakito.jp/emacs/emacs23.html
;;
;; Emacs 22 以下用に user-emacs-directory を定義する.
(unless (boundp 'user-emacs-directory)
  (defvar user-emacs-directory (expand-file-name "~/.emacs.d/")))
;;; load-path 追加用の関数
;; 読み込みたくないファイルは, 先頭に "." や "_" をつけると良い
;;
(defun add-to-load-path (&rest paths)
  (let (path)
    (dolist (path paths paths)
      (let ((default-directory
              (expand-file-name (concat user-emacs-directory path))))
        (add-to-list 'load-path default-directory)
        (if (fboundp 'normal-top-level-add-subdirs-to-loadpath)
            (normal-top-level-add-subdirs-to-load-path))))))
;; -----------------------------------------------------------
;;; load-path の設定
;;
;; load-path の優先順位が気になる場合には
;;  M-x list-load-path-shadows
;; で確認する.
(add-to-load-path
 ;; 分割した設定群の置き場所.
 "site-start.d"
 ;; 自作の小物など
 "local-lisp"
 ;; auto-install で install したファイル.
 "auto-install"
 ;; org-mode は常に最新版(Git HEAD)を load する.
 "site-lisp/org-mode/lisp"
 ;; apel は無いと色々絶望的? <- ddskk の apel 依存ってどうなったのかしら
 "site-lisp/apel"
 )
;; -----------------------------------------------------------
;;; org-babel
;;
;; Emacs の設定は org-mode で記述.
;;
(require 'org-install)
;;
;; ob-tangl より自分用に幾つか関数を設定
;;
;; - my:org-babel-tangle-and-compile-file
;;   指定された org ファイルから emacs-lisp を export して
;;   byte-compile する.
;;   - Make から呼ぶ事も想定しているので load はしない.
;;
;; - my:org-babel-load-file
;;   my:org-babel-tangle-and-comile-file してから load する
;;
;; - my:org-load-file
;;   my:org-babel-load-file の際にディレクトリ名を省略(決め打ち)
;;
(defun my:org-babel-tangle-and-compile-file (file)
  "export emacs-lisp and byte-compile from org files (not load).
   originally ob-tangle.el"
  (interactive "fFile to load: ")
  (flet ((age (file)
              (float-time
               (time-subtract (current-time)
                              (nth 5 (or (file-attributes (file-truename file))
                                         (file-attributes file)))))))
    (let* ((base-name (file-name-sans-extension file))
           (exported-file (concat base-name ".el"))
           (compiled-file (concat base-name ".elc")))
      ;; tangle if the org-mode file is newer than the elisp file
      (unless (and (file-exists-p compiled-file)
                   (> (age file) (age compiled-file)))
        (org-babel-tangle-file file exported-file "emacs-lisp")
        (byte-compile-file exported-file)))))

(defun my:org-babel-load-file (file)
  "load after byte-compile"
  (interactive "fFile to load: ")
  (my:org-babel-tangle-and-compile-file file)
  (load (file-name-sans-extension file)))

(defvar org-settings-dir (concat user-emacs-directory "site-start.d/"))
(defun my:load-org-file (file)
  "org-settings-dir 以下から my-org-babel-load-file"
  (my:org-babel-load-file (expand-file-name file org-settings-dir)))
;; 読み込み
(my:load-org-file "00startup.org")
;; ------------------------------------
;;; calculate bootup time/ スピード狂に捧ぐ.
;;
;; 目標: 3000ms 圏内
;;
(when emacs23-p
  (defun message-startup-time ()
    (message
     "Emacs loaded in %dms"
     (/ (- (+ (third after-init-time) (* 1000000 (second after-init-time)))
           (+ (third before-init-time) (* 1000000 (second before-init-time))))
        1000)))
  (add-hook 'after-init-hook 'message-startup-time))
;;; init.el ends here