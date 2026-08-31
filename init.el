;; -*- lexical-binding: t; -*-
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(eval-when-compile (require 'use-package))

(setq org-directory "~/org/")
(setq org-agenda-files '("~/org"))
(setq completion-ignore-case t)
(fido-vertical-mode 1)

(require 'server)
(unless (server-running-p)
  (server-start))

(use-package evil
  :ensure t
  :init
  (setq evil-want-keybinding nil
        evil-want-C-u-scroll t)
  :custom
  ;; Configure Evil's undo backend through its setter so normal-state C-r
  ;; invokes `undo-tree-redo', as it does in Vim.
  (evil-undo-system 'undo-tree)
  :config
  (evil-mode)
  ;; Keep pane navigation on the home row in every Evil state.  These replace
  ;; Emacs' default Meta paragraph/sentence/case-editing commands.
  (evil-define-key '(normal insert visual motion emacs) 'global
    (kbd "M-h") #'windmove-left
    (kbd "M-j") #'windmove-down
    (kbd "M-k") #'windmove-up
    (kbd "M-l") #'windmove-right
    ;; Shift-Meta moves the focused pane by swapping it with its neighbor.
    (kbd "M-H") #'windmove-swap-states-left
    (kbd "M-J") #'windmove-swap-states-down
    (kbd "M-K") #'windmove-swap-states-up
    (kbd "M-L") #'windmove-swap-states-right
    ;; Meta-left/right follow the tab bar's linear order.
    (kbd "M-<left>") #'tab-bar-switch-to-prev-tab
    (kbd "M-<right>") #'tab-bar-switch-to-next-tab))

(use-package evil-collection
  :ensure t
  :config (evil-collection-init))

(use-package evil-org
  :ensure t
  :after org
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

(recentf-mode)
(setq recentf-max-saved-items 150)
(global-set-key (kbd "C-c r") #'recentf-open)

;; Keep unmodified buffers current when files change outside Emacs.  This
;; never writes files and leaves buffers with unsaved edits untouched.
(global-auto-revert-mode 1)
(setq auto-revert-verbose nil)

(use-package org
  :ensure nil
  :config
  (define-key global-map (kbd "C-c l") #'org-store-link)
  (define-key global-map (kbd "C-c a") #'org-agenda)
  (define-key global-map (kbd "C-c c") #'org-capture)
  (setq org-capture-templates
        '(("t" "Personal todo" entry
           (file "~/org/todo.org") "* TODO %?\n  %i\n  %a" :prepend t)
          ("n" "Personal notes" entry
           (file+headline "~/org/notes.org" "Inbox") "* %u %?\n  %i\n  %a" :prepend t)
          ("j" "Journal" entry
           (file+olp+datetree "~/org/journal.org") "* %U %?\n  %i\n  %a" :prepend t))))

(use-package org-bullets
  :ensure t
  :config
  (setq org-bullets-bullet-list '("►" "▸" "•" "★" "◇"))
  (add-hook 'org-mode-hook #'org-bullets-mode))
(use-package org-pomodoro :ensure t)
(use-package yasnippet :ensure t :config (yas-global-mode))
(use-package smartparens
  :ensure t
  :config (require 'smartparens-config) (smartparens-global-mode))
(use-package magit :ensure t)
(use-package god-mode :ensure t)
(use-package evil-god-state
  :ensure t
  :config
  (evil-define-key 'normal global-map (kbd ",") #'evil-execute-in-god-state)
  (evil-define-key 'god global-map [escape] #'evil-god-state-bail))
(use-package undo-tree
  :ensure t
  :config (global-undo-tree-mode))

(use-package fountain-mode :ensure t)
(use-package olivetti :ensure t
  :config (add-hook 'fountain-mode-hook #'olivetti-mode))

(menu-bar-mode -1)
(tool-bar-mode -1)
(use-package alert :ensure t :config (setq alert-default-style 'message))
(use-package modus-themes
  :ensure t
  :config
  (setq modus-themes-italic-constructs t
        modus-themes-bold-constructs t)
  (load-theme 'modus-operandi t)
  (define-key global-map (kbd "<f5>") #'modus-themes-toggle))
(setq window-divider-default-places t
      window-divider-default-right-width 1
      window-divider-default-bottom-width 1)
(window-divider-mode)
(use-package focus :ensure t)
(define-key global-map (kbd "C-c f") #'focus-mode)

(use-package vterm
    :ensure t
    :config
    ;; Terminal TUIs need raw keyboard input; Evil's Emacs state lets keys
    ;; such as ESC reach Codex, Claude Code, and other terminal programs.
    (evil-set-initial-state 'vterm-mode 'emacs)
    ;; Make `M-x vterm' create a fresh session every time.  Keep
    ;; noninteractive calls' original argument handling intact.
    (defun my/vterm-always-new (original &optional arg)
      "Make interactive calls to `vterm' open a new session."
      (if (called-interactively-p 'interactive)
          (funcall original t)
        (funcall original arg)))
    (advice-add #'vterm :around #'my/vterm-always-new))

;; Persistent remote terminals.  Emacs owns the window layout; each vterm is
;; backed by one single-pane tmux session on a private remote tmux socket.
(require 'desktop)
(require 'seq)
(require 'subr-x)
(require 'tramp)
(savehist-mode 1)

(defgroup my/remote-terminal nil
  "Persistent remote terminals displayed in vterm."
  :group 'terminals)

(defcustom my/remote-terminal-ssh-config-files
  (list (expand-file-name "~/.ssh/config"))
  "SSH configuration files whose literal Host aliases are terminal targets."
  :type '(repeat file))

(defcustom my/remote-terminal-default-cluster "login.haicore.berlin"
  "SSH Host alias initially selected by the cluster prompt."
  :type 'string)

(defcustom my/remote-terminal-cluster-overrides
  '(("login.haicore.berlin"
     :gateway "login.haicore.berlin"
     :host "hai-login1"
     :user "franz.srambical"
     :default-directory "/fast/home/franz.srambical"))
  "Per-alias connection overrides.

Aliases without an entry are passed directly to SSH, which resolves their
HostName, User, ProxyJump, identity, and other settings from the SSH config.
The Berlin alias is special: it is a jump host for the fixed login node 1."
  :type '(alist :key-type string :value-type sexp))

(defcustom my/remote-terminal-socket "emacs-terminals"
  "Name of the private tmux server socket used by remote terminals."
  :type 'string)

(defcustom my/remote-terminal-history-limit 100000
  "Number of scrollback lines retained by each remote tmux window."
  :type 'integer)

(defcustom my/remote-terminal-tmux-mouse t
  "Whether the private remote tmux server handles mouse scrolling."
  :type 'boolean)

(defcustom my/remote-workspace-directory
  (expand-file-name "remote-workspace/" user-emacs-directory)
  "Directory containing the explicitly saved Emacs workspace."
  :type 'directory)

(defvar-local my/remote-terminal-spec nil
  "Connection information for the remote terminal in this buffer.")

(defvar my/remote-terminal--last-query-error nil)

(defun my/remote-terminal--valid-session-p (session)
  "Return non-nil when SESSION is safe to use as a tmux target."
  (and (stringp session)
       (string-match-p
        "\\`[[:alnum:]_][[:alnum:]_.-]*\\'"
        session)))

(defun my/remote-terminal--ssh-hosts ()
  "Return literal Host aliases from `my/remote-terminal-ssh-config-files'."
  (let (hosts)
    (dolist (file my/remote-terminal-ssh-config-files)
      (dolist (entry (tramp-parse-sconfig (expand-file-name file)))
        (let ((host (cadr entry)))
          ;; Wildcard SSH stanzas configure other hosts; they are not concrete
          ;; completion candidates.  `tramp-parse-sconfig' may also return a
          ;; nil placeholder for the start of the file.
          (when (and host
                     (not (string-match-p "[*?!]" host)))
            (push host hosts)))))
    (sort (delete-dups hosts) #'string-lessp)))

(defun my/remote-terminal--read-cluster ()
  "Read one configured SSH Host alias."
  (let ((hosts (my/remote-terminal--ssh-hosts)))
    (unless hosts
      (user-error "No literal Host aliases found in %s"
                  (mapconcat #'abbreviate-file-name
                             my/remote-terminal-ssh-config-files ", ")))
    (completing-read
     "SSH cluster: " hosts nil t nil nil
     (and (member my/remote-terminal-default-cluster hosts)
          my/remote-terminal-default-cluster))))

(defun my/remote-terminal--current-spec (cluster session &optional directory)
  "Build a terminal specification for CLUSTER, SESSION, and DIRECTORY."
  (let ((override (cdr (assoc cluster
                              my/remote-terminal-cluster-overrides))))
    (list :remote-terminal t
          :cluster cluster
          :gateway (plist-get override :gateway)
          :host (or (plist-get override :host) cluster)
          :user (plist-get override :user)
          :socket my/remote-terminal-socket
          :default-directory (plist-get override :default-directory)
          :session session
          :directory directory
          :buffer-name (format "*remote:%s:%s*" cluster session))))

(defun my/remote-terminal--target (spec)
  "Return the SSH target described by SPEC."
  (let ((host (plist-get spec :host))
        (user (plist-get spec :user)))
    (if (and user (not (string-empty-p user)))
        (format "%s@%s" user host)
      host)))

(defun my/remote-terminal--ssh-arguments (spec command &optional interactive)
  "Build SSH arguments for SPEC and remote COMMAND.

When INTERACTIVE is non-nil, allocate a tty and allow SSH to prompt."
  (append
   (when interactive '("-tt"))
   '("-o" "ConnectTimeout=10"
     "-o" "ServerAliveInterval=15"
     "-o" "ServerAliveCountMax=3")
   (unless interactive '("-o" "BatchMode=yes"))
   (when-let* ((gateway (plist-get spec :gateway)))
     (unless (string-empty-p gateway)
       (list "-J" gateway)))
   (list (my/remote-terminal--target spec) command)))

(defun my/remote-terminal--ssh-command (spec remote-command)
  "Return an interactive SSH shell command for SPEC and REMOTE-COMMAND."
  (mapconcat #'shell-quote-argument
             (cons "ssh"
                   (my/remote-terminal--ssh-arguments
                    spec remote-command t))
             " "))

(defun my/remote-terminal--run (spec remote-command)
  "Run REMOTE-COMMAND synchronously according to SPEC.

Return a cons of the exit status and combined output.  This is used only by
explicit interactive management commands, never during startup."
  (with-temp-buffer
    (let ((status
           (apply #'call-process "ssh" nil '(t t) nil
                  (my/remote-terminal--ssh-arguments
                   spec remote-command))))
      (cons status (string-trim (buffer-string))))))

(defun my/remote-terminal--list-sessions (cluster &optional quiet)
  "Return remote session specifications for CLUSTER.

If QUIET is non-nil, turn SSH failures into an empty result."
  (let* ((base (my/remote-terminal--current-spec cluster "query"))
         (socket (shell-quote-argument my/remote-terminal-socket))
         (format-string
          (shell-quote-argument
           (concat "#{session_name}" "\t" "#{pane_current_path}")))
         (command (format "tmux -L %s list-panes -a -F %s 2>/dev/null || :"
                          socket format-string))
         (result (my/remote-terminal--run base command))
         (status (car result))
         (output (cdr result)))
    (setq my/remote-terminal--last-query-error nil)
    (if (equal status 0)
        (let ((seen (make-hash-table :test #'equal))
              sessions)
          (dolist (line (split-string output "\n" t))
            (when (string-match "\\`\\([^\t]+\\)\t\\(.*\\)\\'" line)
              (let ((session (match-string 1 line))
                    (directory (match-string 2 line)))
                (when (and (my/remote-terminal--valid-session-p session)
                           (not (gethash session seen)))
                  (puthash session t seen)
                  (push (my/remote-terminal--current-spec
                         cluster session directory)
                        sessions)))))
          (sort sessions
                (lambda (a b)
                  (string-lessp (plist-get a :session)
                                (plist-get b :session)))))
      (setq my/remote-terminal--last-query-error
            (if (string-empty-p output)
                (format "ssh exited with status %s" status)
              output))
      (unless quiet
        (user-error "Could not list remote terminals on %s: %s"
                    cluster my/remote-terminal--last-query-error))
      nil)))

(defun my/remote-terminal--attach-command (spec)
  "Build the remote tmux attach-or-create command for SPEC."
  (let* ((socket (shell-quote-argument (plist-get spec :socket)))
         (session (shell-quote-argument (plist-get spec :session)))
         (directory (plist-get spec :directory))
         ;; tmux fixes a window's history allocation when that window is
         ;; created, so configure the server before `new-session'.  Keeping
         ;; the setup and creation in one tmux command queue also works when
         ;; this is the first session and no server exists yet.
         (create (concat "tmux -L " socket
                         " start-server \\; set-window-option -g history-limit "
                         (number-to-string my/remote-terminal-history-limit)
                         " \\; set-window-option -g mode-keys vi"
                         " \\; set-option -g mouse "
                         (if my/remote-terminal-tmux-mouse "on" "off")
                         " \\; new-session -d -s " session
                         (when (and directory
                                    (not (string-empty-p directory)))
                           (concat " -c "
                                   (shell-quote-argument directory))))))
    (format (concat "if ! tmux -L %s has-session -t %s 2>/dev/null; "
                    "then %s || exit $?; fi; "
                    "tmux -L %s set-window-option -g history-limit %s; "
                    "tmux -L %s set-window-option -t %s mode-keys vi; "
                    "tmux -L %s set-option -g mouse %s; "
                    "tmux -L %s set-option -t %s status off || exit $?; "
                    "exec tmux -L %s attach-session -t %s")
            socket session create
            socket (number-to-string my/remote-terminal-history-limit)
            socket session
            socket (if my/remote-terminal-tmux-mouse "on" "off")
            socket session socket session)))

(defun my/remote-terminal--buffer (cluster session)
  "Return the remote terminal buffer for CLUSTER and SESSION, if any."
  (seq-find
   (lambda (buffer)
     (with-current-buffer buffer
       (and (plist-get my/remote-terminal-spec :remote-terminal)
            (equal (plist-get my/remote-terminal-spec :cluster)
                   cluster)
            (equal (plist-get my/remote-terminal-spec :session)
                   session))))
   (buffer-list)))

(defun my/remote-terminal--discard-buffer (buffer)
  "Disconnect and kill remote terminal BUFFER without touching tmux."
  (when (buffer-live-p buffer)
    (when-let* ((process (get-buffer-process buffer)))
      (set-process-query-on-exit-flag process nil)
      (when (process-live-p process)
        (delete-process process)))
    (let ((kill-buffer-query-functions nil))
      (kill-buffer buffer))))

(defun my/remote-terminal--desktop-save (_desktop-directory)
  "Return the current terminal specification for Desktop Save."
  my/remote-terminal-spec)

(defun my/remote-terminal--open-spec (spec &optional no-display)
  "Open the remote terminal described by SPEC.

When NO-DISPLAY is non-nil, create the buffer without changing the window
layout."
  (let* ((cluster (plist-get spec :cluster))
         (session (plist-get spec :session))
         (buffer-name (or (plist-get spec :buffer-name)
                          (format "*remote:%s:%s*" cluster session)))
         (existing (my/remote-terminal--buffer cluster session)))
    (unless (and (stringp cluster) (not (string-empty-p cluster)))
      (user-error "Terminal specification has no SSH cluster"))
    (unless (my/remote-terminal--valid-session-p session)
      (user-error "Invalid session name: %S" session))
    (if (and existing
             (process-live-p (get-buffer-process existing)))
        (progn
          (unless no-display (pop-to-buffer existing))
          existing)
      (when existing
        (my/remote-terminal--discard-buffer existing))
      (when-let* ((collision (get-buffer buffer-name)))
        (user-error "Buffer %s already exists and is not this remote terminal"
                    (buffer-name collision)))
      (let* ((vterm-shell
              (my/remote-terminal--ssh-command
               spec (my/remote-terminal--attach-command spec)))
             (buffer
              (save-window-excursion
                (vterm buffer-name))))
        (with-current-buffer buffer
          ;; Keep a disconnected managed terminal around so its session
          ;; specification remains available to `my/remote-terminal-reconnect'.
          ;; The vterm default is to kill the buffer when SSH exits.
          (setq-local vterm-kill-buffer-on-exit nil)
          (setq-local my/remote-terminal-spec spec)
          (setq-local desktop-save-buffer
                      #'my/remote-terminal--desktop-save))
        (unless no-display (pop-to-buffer buffer))
        buffer))))

(defun my/remote-terminal--suggested-directory (spec)
  "Return a useful initial directory for a new terminal described by SPEC."
  (let ((remote-host (file-remote-p default-directory 'host)))
    (if (and remote-host
             (member remote-host
                     (list (plist-get spec :cluster)
                           (plist-get spec :host))))
        (file-local-name default-directory)
      (or (plist-get spec :default-directory) ""))))

(defun my/remote-terminal-open (cluster session &optional directory)
  "On CLUSTER, attach to or create terminal SESSION in DIRECTORY."
  (interactive
   (let* ((cluster (my/remote-terminal--read-cluster))
          (base (my/remote-terminal--current-spec cluster "new"))
          (sessions (my/remote-terminal--list-sessions cluster t))
          (names (mapcar (lambda (spec) (plist-get spec :session))
                         sessions))
          (session (completing-read "Remote terminal: " names nil nil))
          (existing (seq-find
                     (lambda (spec)
                       (equal (plist-get spec :session) session))
                     sessions)))
     (when (string-empty-p session)
       (user-error "Session name cannot be empty"))
     (unless (my/remote-terminal--valid-session-p session)
       (user-error
        "Use only letters, numbers, underscore, dot, and hyphen in session names"))
     (list cluster session
           (or (plist-get existing :directory)
               (read-string "Remote directory (empty for home): "
                            (my/remote-terminal--suggested-directory
                             base))))))
  (my/remote-terminal--open-spec
   (my/remote-terminal--current-spec cluster session directory)))

(defun my/remote-terminal-list ()
  "Select and display an existing persistent remote terminal."
  (interactive)
  (let* ((cluster (my/remote-terminal--read-cluster))
         (sessions (my/remote-terminal--list-sessions cluster))
         (names (mapcar (lambda (spec) (plist-get spec :session)) sessions)))
    (unless sessions
      (user-error "No persistent remote terminals exist on %s" cluster))
    (let* ((name (completing-read "Existing remote terminal: "
                                  names nil t))
           (spec (seq-find
                  (lambda (candidate)
                    (equal (plist-get candidate :session) name))
                  sessions)))
      (my/remote-terminal--open-spec spec))))

(defun my/remote-terminal-restore-all ()
  "Reconnect every terminal on a chosen cluster's private tmux socket."
  (interactive)
  (let* ((cluster (my/remote-terminal--read-cluster))
         (sessions (my/remote-terminal--list-sessions cluster))
         (count 0))
    (unless sessions
      (user-error "No persistent remote terminals exist on %s" cluster))
    (dolist (spec sessions)
      (my/remote-terminal--open-spec spec t)
      (setq count (1+ count)))
    (pop-to-buffer (my/remote-terminal--buffer
                    cluster
                    (plist-get (car sessions) :session)))
    (message "Restored %d persistent remote terminal(s) on %s"
             count cluster)))

(defun my/remote-terminal-reconnect ()
  "Reconnect the current vterm to its persistent tmux session."
  (interactive)
  (unless (plist-get my/remote-terminal-spec :remote-terminal)
    (user-error "The current buffer is not a persistent remote terminal"))
  (let ((spec my/remote-terminal-spec)
        (buffer (current-buffer)))
    (my/remote-terminal--discard-buffer buffer)
    (my/remote-terminal--open-spec spec)))

(defun my/remote-terminal-kill (cluster session)
  "Kill terminal SESSION on CLUSTER and its local vterm buffer."
  (interactive
   (let* ((current-cluster (plist-get my/remote-terminal-spec :cluster))
          (current-session (plist-get my/remote-terminal-spec :session))
          (cluster (or current-cluster
                       (my/remote-terminal--read-cluster)))
          (sessions (unless current-session
                      (my/remote-terminal--list-sessions cluster)))
          (names (mapcar (lambda (spec) (plist-get spec :session)) sessions)))
     (list cluster
           (or current-session
               (progn
                 (unless names
                   (user-error "No persistent remote terminals exist on %s"
                               cluster))
                 (completing-read "Kill remote terminal: " names nil t))))))
  (unless (yes-or-no-p
           (format "Kill remote terminal %s on %s and everything in it? "
                   session cluster))
    (user-error "Cancelled"))
  (let* ((spec (or (and (equal (plist-get my/remote-terminal-spec :cluster)
                               cluster)
                        (equal (plist-get my/remote-terminal-spec :session)
                               session)
                        my/remote-terminal-spec)
                   (my/remote-terminal--current-spec cluster session)))
         (socket (shell-quote-argument (plist-get spec :socket)))
         (target (shell-quote-argument session))
         (result (my/remote-terminal--run
                  spec (format "tmux -L %s kill-session -t %s"
                               socket target))))
    (unless (equal (car result) 0)
      (user-error "Could not kill remote terminal: %s" (cdr result)))
    (when-let* ((buffer (my/remote-terminal--buffer cluster session)))
      (my/remote-terminal--discard-buffer buffer))
    (message "Killed persistent remote terminal %s on %s" session cluster)))

(defun my/remote-terminal--desktop-restore (_file buffer-name spec)
  "Restore BUFFER-NAME from remote terminal SPEC."
  (when (plist-get spec :remote-terminal)
    (setq spec (plist-put spec :buffer-name buffer-name))
    (my/remote-terminal--open-spec spec t)))

(add-to-list 'desktop-buffer-mode-handlers
             '(vterm-mode . my/remote-terminal--desktop-restore))

;; Include TRAMP buffers in an explicitly requested snapshot, but avoid a
;; long wait for any remote host that happens to be unavailable.  Crucially,
;; `desktop-save-mode' is not enabled and `desktop-read' is never called here.
(setq desktop-files-not-to-save nil
      ;; Once explicitly requested, restore the whole layout in one pass.
      desktop-restore-eager t
      remote-file-name-access-timeout 5)

(defun my/remote-workspace-save ()
  "Explicitly save buffers, frames, windows, and persistent terminals."
  (interactive)
  (make-directory my/remote-workspace-directory t)
  ;; RELEASE makes this a reusable snapshot instead of leaving a lock that
  ;; suggests another Emacs instance owns it.
  (desktop-save my/remote-workspace-directory t nil 208)
  (message "Saved workspace to %s" my/remote-workspace-directory))

(defun my/remote-workspace-restore ()
  "Explicitly restore the saved workspace, including TRAMP and terminals."
  (interactive)
  (unless (file-exists-p
           (expand-file-name desktop-base-file-name
                             my/remote-workspace-directory))
    (user-error "No saved workspace in %s" my/remote-workspace-directory))
  (desktop-read my/remote-workspace-directory))

(define-key global-map (kbd "C-c t t") #'my/remote-terminal-open)
(define-key global-map (kbd "C-c t l") #'my/remote-terminal-list)
(define-key global-map (kbd "C-c t a") #'my/remote-terminal-restore-all)
(define-key global-map (kbd "C-c t r") #'my/remote-terminal-reconnect)
(define-key global-map (kbd "C-c t k") #'my/remote-terminal-kill)
(define-key global-map (kbd "C-c t s") #'my/remote-workspace-save)
(define-key global-map (kbd "C-c t w") #'my/remote-workspace-restore)

(setq gc-cons-threshold 100000000)
(setq max-specpdl-size 5000)
(setq
 ;; No need to see GNU agitprop.
 inhibit-startup-screen t
 ;; No need to remind me what a scratch buffer is.
 initial-scratch-message nil
 ;; Double-spaces after periods is morally wrong.
 sentence-end-double-space nil
 ;; Never ding at me, ever.
 ring-bell-function 'ignore
 ;; Prompts should go in the minibuffer, not in a GUI.
 use-dialog-box nil
 ;; accept 'y' or 'n' instead of yes/no
 ;; the documentation advises against setting this variable
 ;; the documentation can get bent imo
 use-short-answers t
 ;; I want to close these fast, so switch to it so I can just hit 'q'
 help-window-select t
 ;; this certainly can't hurt anything
 delete-by-moving-to-trash t
 ;; keep the point in the same place while scrolling
 scroll-preserve-screen-position t
 ;; more info in completions
 completions-detailed t
 ;; highlight error messages more aggressively
 next-error-message-highlight t
 ;; don't let the minibuffer muck up my window tiling
 read-minibuffer-restore-windows t
 )

;; Never mix tabs and spaces. Never use tabs, period.
;; We need the setq-default here because this becomes
;; a buffer-local variable when set.
(setq-default indent-tabs-mode nil)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("0ef0c3e24c8f704430e2b2f473101c08fb8bab93d09a80dbc2ea2dbb799aa861"
     "28f3ac0f5fade64dc7e27abe9d32e7d85576c40940977e8e319f25055d3a28b7"
     "138ed99a323c1b93c52f4b3726caf2bc634b79a76fa63a3d3aff76394db5f28f"
     "10e330880269244ae45ae9e02fe6f55766da9e15036e7c7f07d7ce228195deb5"
     "967c23e9ba179b80560774419f081df22e7674aac23c5c550b817e4a1ce7d058"
     default))
 '(package-selected-packages
   '(evil evil-collection evil-god-state evil-org focus fountain-mode
          god-mode hide-mode-line magit modus-themes olivetti
          org-bullets org-pomodoro smartparens undo-tree
          vterm yasnippet))
 '(package-vc-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
