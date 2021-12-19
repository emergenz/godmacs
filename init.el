(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; Comment/uncomment this line to enable MELPA Stable if desired.  See `package-archive-priorities`
;; and `package-pinned-packages`. Most users will not need or want to do this.
;;(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
(package-initialize)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-agenda-files '("~/Dropbox/org"))
 '(package-selected-packages
   '(irony-eldoc irony org-alert org-altert hide-mode-line company company-mode lsp-ui lsp-mode org-pomodoro focus olivetti olivetti-mode fountain-mode ag solaire-mode evil-org org-bullets evil-collection selectrum-prescient selectrum evil use-package)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(fountain ((t (:height 1.2 :family "Courier Prime")))))


(use-package evil
  :ensure t
  :init
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-scroll t)
  :config
  (evil-mode)
  (setq evil-undo-system 'undo-tree)
  )

(use-package evil-collection
  :ensure t
  :config
  (evil-collection-init))

(use-package evil-org
  :ensure t
  :after org
  :hook (org-mode . (lambda () evil-org-mode))
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

(use-package recentf
  :config
  (recentf-mode)
  (setq recentf-max-saved-items 150)
  (defun recentd-track-opened-file ()

    "Insert the name of the directory just opened into the recent list."
    (and (derived-mode-p 'dired-mode) default-directory
	(recentf-add-file default-directory))
    ;; Must return nil because it is run from `write-file-functions'.
    nil)

  (defun recentd-track-closed-file ()
  "Update the recent list when a dired buffer is killed.
  That is, remove a non kept dired from the recent list."
  (and (derived-mode-p 'dired-mode) default-directory
       (recentf-remove-if-non-kept default-directory)))

  (add-hook 'dired-after-readin-hook 'recentd-track-opened-file)
  (add-hook 'kill-buffer-hook 'recentd-track-closed-file))

(defun recentf-open-files+ ()
"Use `completing-read' to open a recent file."
(interactive)
(let ((files (mapcar 'abbreviate-file-name recentf-list)))
  (find-file (completing-read "Find recent file: " files nil t))))
(use-package selectrum
  :ensure t
  :config
  (selectrum-mode)
  (global-set-key (kbd "C-x C-r") 'recentf-open-files+)
  )

(use-package selectrum-prescient
  :ensure
  :config
  (selectrum-prescient-mode))
(setq completion-ignore-case  t)

;;openwith
(use-package openwith
  :ensure t
  :config
  (openwith-mode t)
  (setq openwith-associations '(("\\.pdf\\'" "zathura" (file)))))

;; follow mouse
(setq focus-follows-mouse t)

;; org mode
(use-package org
  :ensure t
  :config
  ;; org-mode global keybindings
  (define-key global-map "\C-cl" 'org-store-link)
  (define-key global-map "\C-ca" 'org-agenda)
  (define-key global-map "\C-cc" 'org-capture)
  (define-key global-map "\C-cL" 'org-occur-link-in-agenda-files)

  ;; Hook to display the agenda in a single window
  ;; (add-hook 'org-agenda-finalize-hook 'delete-other-windows)

  ;; custom
  (setq org-directory "~/Dropbox/org/")
  (setq org-agenda-files '("~/Dropbox/org"))
  (setq org-startup-with-latex-preview t)

  ;; set Iosevka font only if it available
  (defun rag-set-face (frame)
  "Configure faces on frame creation"
  (select-frame frame)
  (if (display-graphic-p)
	(progn
	    (when (member "Iosevka" (font-family-list))
	    (progn
		(set-frame-font "Iosevka-12" nil t))))))
  (add-hook 'after-make-frame-functions #'rag-set-face)
  ;; set frame font when running emacs normally
  (when (member "Iosevka" (font-family-list))
  (progn
	(set-frame-font "Iosevka-12" nil t)))

  ;; capture-template
  (setq org-capture-templates
	'(("t" "Personal todo" entry
	    (file "~/Dropbox/org/todo.org")
	    "* TODO %?
	    %i
	    %a" :prepend t)
	  ("n" "Personal notes" entry
	    (file+headline "~/Dropbox/org/notes.org" "Inbox")
	    "* %u %?
	    %i
	    %a" :prepend t)
	  ("j" "Journal" entry
	    (file+olp+datetree "~/Dropbox/org/journal.org")
	    "* %U %?
	    %i
	    %a" :prepend t))))

(use-package org-bullets
  :ensure t
  :config
  (setq org-bullets-bullet-list '("►" "▸" "•" "★" "◇" "◇" "◇" "◇"))
  (add-hook 'org-mode-hook (lambda () (org-bullets-mode 1))))

(use-package org-pomodoro
  :ensure t)

;; programming
(use-package projectile
  :ensure t
  :config
  (projectile-mode)
  (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map))

(use-package ag
  :ensure t)

(use-package yasnippet
  :ensure t
  :config
  (yas-global-mode))

(use-package smartparens
  :ensure t
  :config
  (require 'smartparens-config)
  (smartparens-global-mode))

(use-package magit
  :ensure t)

(use-package god-mode
  :ensure t)

(use-package evil-god-state
  :ensure t
  :config
  (evil-define-key 'normal global-map "," 'evil-execute-in-god-state)
  (evil-define-key 'god global-map [escape] 'evil-god-state-bail))

(use-package undo-tree
  :ensure t
  :config
  (global-undo-tree-mode))
(define-key evil-normal-state-map (kbd "C-r") 'undo-tree-redo)
(define-key evil-normal-state-map (kbd "u") 'undo-tree-undo)

(use-package lsp-mode
  :ensure t
  :init
  (setq lsp-keymap-prefix "C-c C-l")
  :hook (
         (java-mode . lsp-deferred)
         ;; if you want which-key integration
         (lsp-mode . lsp-enable-which-key-integration))
  :commands lsp-deferred)

(use-package lsp-ui
  :ensure t)

(use-package company
  :ensure t
  :config
  (add-hook 'after-init-hook 'global-company-mode)
  (setq company-minimum-prefix-length 1
      company-idle-delay 0.0))

(use-package merlin
  :ensure t
  :config
  (add-hook 'tuareg-mode-hook #'merlin-mode)
  (add-hook 'caml-mode-hook #'merlin-mode)
  (add-hook 'tuareg-mode-hook
            (lambda()
              (when (functionp 'prettify-symbols-mode)
                (prettify-symbols-mode))))
  (setq tuareg-prettify-symbols-full t) 
)
(use-package merlin-company
  :ensure t)

(use-package tuareg
  :ensure t)

(use-package irony
  :ensure t
  :config
  (add-hook 'c++-mode-hook 'irony-mode)
  (add-hook 'c-mode-hook 'irony-mode)
  (add-hook 'objc-mode-hook 'irony-mode)
  (add-hook 'irony-mode-hook 'irony-cdb-autosetup-compile-options)
  )

(use-package irony-eldoc
  :ensure t
  :config
  (add-hook 'irony-mode-hook #'irony-eldoc))

;; screenwriting
(use-package fountain-mode
  :ensure t)

(use-package olivetti
  :ensure t
  :config
  (add-hook 'fountain-mode-hook (lambda () (olivetti-mode))))

;; ui
(menu-bar-mode -1)
(tool-bar-mode -1)
(toggle-scroll-bar -1) 

(use-package alert
  :ensure t
  :config
  (setq alert-default-style 'libnotify))

(use-package hide-mode-line
  :ensure t
  :config
  (global-hide-mode-line-mode))

(use-package modus-themes
  :ensure
  :init
  ;; Add all your customizations prior to loading the themes
  (setq modus-themes-italic-constructs t
        modus-themes-bold-constructs t
        modus-themes-region '(bg-only no-extend)
	modus-themes-org-agenda ; this is an alist: read the manual or its doc string
	'((header-block . (variable-pitch scale-title))
          (header-date . (grayscale workaholic bold-today))
	  (event . (accented scale-small))
	  (scheduled . uniform)
	  (habit . traffic-light-deuteranopia))
	modus-themes-headings ; this is an alist: read the manual or its doc string
	'((1 . (overline background))
	  (2 . (rainbow overline))
	  (t . (semibold)))
	)

  ;; Load the theme files before enabling a theme
  (modus-themes-load-themes)
  :config
  ;; Load the theme of your choice:
  (modus-themes-load-operandi) ;; OR (modus-themes-load-vivendi)
  :bind ("<f5>" . modus-themes-toggle))

(use-package solaire-mode
  :ensure t
  :config
  (solaire-global-mode))

(setq window-divider-default-places t)
(setq window-divider-default-right-width 1)
(setq window-divider-default-bottom-width 1)
(window-divider-mode)

(use-package focus
  :ensure t
  )

;; zen-mode
(define-key global-map "\C-cf" 'focus-mode)
