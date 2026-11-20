(require 'cl-lib)
(require 'osc nil t)

(defgroup doom-deag nil
  "Doom Deag: OSC 7501 agent orchestration and self-building runtime for Doom Emacs."
  :group 'tools)

(defcustom doom-deag-auto-escalate-blocked t
  "When non-nil, notify the active ECA chat session when an agent reports state=blocked."
  :type 'boolean
  :group 'doom-deag)

;; 1. Ensure Emacs server is running so ECA skills can control the editor via emacsclient
(unless (daemonp)
  (require 'server)
  (unless (server-running-p)
    (server-start)))

;; 2. Dock all *Agent:* terminal windows at the bottom 30% of the frame
(add-to-list 'display-buffer-alist
             '("^\\*Agent:.*\\*"
               (display-buffer-reuse-window display-buffer-at-bottom)
               (window-height . 0.3)
               (dedicated . t)))

;; Map: app-name (string) -> plist (:state string :msg string :buffer string :updated float)
(defvar doom-deag-agent-states (make-hash-table :test 'equal)
  "Real-time registry of terminal agent states reported via OSC 7501.")

(defvar doom-deag--last-escalated (make-hash-table :test 'equal)
  "Tracks last escalated message per agent to prevent duplicate ECA notifications.")

(defun doom-deag--decode-msg (raw-msg)
  "Decode base64 RAW-MSG per OSC 7501 spec, falling back to RAW-MSG if plain text."
  (if (or (null raw-msg) (string-empty-p raw-msg))
      ""
    (condition-case nil
        (decode-coding-string (base64-decode-string raw-msg) 'utf-8)
      (error raw-msg))))

(defun doom-deag-update-status (app state &optional msg)
  "Update OSC 7501 status for APP to STATE with optional human-readable MSG."
  (let* ((buf-name (format "*Agent: %s*" app))
         (clean-msg (or msg ""))
         (entry (list :state state
                      :msg clean-msg
                      :buffer buf-name
                      :updated (float-time))))
    (puthash app entry doom-deag-agent-states)
    (force-mode-line-update t)

    (pcase state
      ("blocked"
       (message "🛑 Doom Deag [%s] BLOCKED: %s" app clean-msg)
       (when (and doom-deag-auto-escalate-blocked
                  (fboundp 'eca-chat-send-prompt)
                  (not (equal (gethash app doom-deag--last-escalated) clean-msg)))
         (puthash app clean-msg doom-deag--last-escalated)
         (ignore-errors
           (eca-chat-send-prompt
            (format "OSC 7501 Alert: Terminal agent '%s' (buffer %s) reported state=blocked (%s). Please inspect its buffer tail and help unblock it."
                    app buf-name clean-msg)))))
      ("failed"
       (message "❌ Doom Deag [%s] FAILED: %s" app clean-msg))
      ("done"
       (remhash app doom-deag--last-escalated)
       (message "✅ Doom Deag [%s] DONE: %s" app clean-msg)))
    state))

(defun doom-deag-osc-7501-handler (_cmd text)
  "Parse raw OSC 7501 payload TEXT (e.g. state=working:app=coder:msg=aGVsbG8=)."
  (let ((pairs (split-string text ":"))
        (state "idle")
        (app "default")
        (msg ""))
    (dolist (pair pairs)
      (when (string-match "\\`\\([^=]+\\)=\\(.*\\)\\'" pair)
        (let ((k (match-string 1 pair))
              (v (match-string 2 pair)))
          (pcase k
            ("state" (setq state v))
            ("app"   (setq app v))
            ("msg"   (setq msg (doom-deag--decode-msg v)))))))
    (doom-deag-update-status app state msg)))

;; Register OSC 7501 handler in Emacs' built-in osc.el (comint / shell / eshell)
(when (boundp 'osc-handlers)
  (add-to-list 'osc-handlers '("7501" . doom-deag-osc-7501-handler)))
(with-eval-after-load 'osc
  (add-to-list 'osc-handlers '("7501" . doom-deag-osc-7501-handler)))

;;;###autoload
(defun doom-deag-spawn-agent (agent-name &optional command)
  "Spawn a docked vterm buffer for AGENT-NAME and optionally execute COMMAND."
  (interactive "sAgent name (e.g., coder): \nsCommand (optional): ")
  (let ((buffer-name (format "*Agent: %s*" agent-name)))
    (with-current-buffer (get-buffer-create buffer-name)
      (unless (eq major-mode 'vterm-mode)
        (vterm-mode))
      (display-buffer (current-buffer))
      (doom-deag-update-status agent-name "idle" "Terminal ready")
      (when (and command (not (string-empty-p command)))
        (run-at-time "0.15 sec" nil
                     (lambda (buf cmd)
                       (when (buffer-live-p buf)
                         (with-current-buffer buf
                           (vterm-send-string cmd)
                           (vterm-send-return))))
                     (current-buffer) command)))
    buffer-name))

;;;###autoload
(defun doom-deag-list-agents ()
  "Select and jump to an active *Agent:* buffer based on live OSC 7501 state."
  (interactive)
  (let (choices)
    (maphash (lambda (app data)
               (push (cons (format "[%-7s] %-16s — %s"
                                   (upcase (plist-get data :state))
                                   app
                                   (plist-get data :msg))
                           (plist-get data :buffer))
                     choices))
             doom-deag-agent-states)
    (if (null choices)
        (message "No active Doom Deag agents tracked.")
      (let* ((selection (completing-read "Switch to Agent: " choices nil t))
             (buf-name (cdr (assoc selection choices))))
        (if (get-buffer buf-name)
            (pop-to-buffer buf-name)
          (message "Buffer %s is no longer open." buf-name))))))

;;;###autoload
(defun doom-deag-jump-blocked ()
  "Immediately focus the first terminal agent in `blocked' or `failed' state."
  (interactive)
  (let (target-buf)
    (maphash (lambda (_app data)
               (when (and (not target-buf)
                          (member (plist-get data :state) '("blocked" "failed")))
                 (setq target-buf (plist-get data :buffer))))
             doom-deag-agent-states)
    (if (and target-buf (get-buffer target-buf))
        (pop-to-buffer target-buf)
      (message "No blocked Doom Deag agents right now."))))

;;;###autoload
(defun doom-deag-clear-finished ()
  "Remove `done' and `idle' agents from the modeline tracker."
  (interactive)
  (let (to-remove)
    (maphash (lambda (app data)
               (when (member (plist-get data :state) '("done" "idle"))
                 (push app to-remove)))
             doom-deag-agent-states)
    (dolist (app to-remove)
      (remhash app doom-deag-agent-states))
    (force-mode-line-update t)
    (message "Cleared %d finished agent(s)." (length to-remove))))

(defun doom-deag-status-report ()
  "Return a formatted string of all agent states (callable by ECA via emacsclient)."
  (let (lines)
    (maphash (lambda (app data)
               (push (format "%s | state=%s | buffer=%s | msg=%s"
                             app
                             (plist-get data :state)
                             (plist-get data :buffer)
                             (plist-get data :msg))
                     lines))
             doom-deag-agent-states)
    (if lines
        (string-join (nreverse lines) "\n")
      "No active OSC 7501 agents registered.")))

(defun doom-deag-read-agent-tail (agent-name &optional lines)
  "Return the last LINES (default 40) from *Agent: AGENT-NAME* for ECA inspection."
  (let* ((buf-name (format "*Agent: %s*" agent-name))
         (buf (get-buffer buf-name))
         (n (or lines 40)))
    (if (not (buffer-live-p buf))
        (format "Buffer %s is not active." buf-name)
      (with-current-buffer buf
        (save-excursion
          (goto-char (point-max))
          (forward-line (- n))
          (buffer-substring-no-properties (point) (point-max)))))))

;; 3. Doom Modeline Integration
(after! doom-modeline
  (doom-modeline-def-segment doom-deag-agents
    "Displays live OSC 7501 agent statuses in the Doom modeline."
    (let (badges)
      (maphash (lambda (app data)
                 (pcase (plist-get data :state)
                   ("working" (push (propertize (format "%s:⏳" app) 'face 'warning) badges))
                   ("blocked" (push (propertize (format "%s:🛑" app) 'face 'error) badges))
                   ("failed"  (push (propertize (format "%s:❌" app) 'face 'error) badges))
                   ("done"    (push (propertize (format "%s:✅" app) 'face 'success) badges))))
               doom-deag-agent-states)
      (when badges
        (concat " [" (string-join (nreverse badges) " ") "] "))))

  (doom-modeline-def-modeline 'main
    '(bar workspace-name window-number modals matches follow buffer-info remote-host buffer-position word-count parrot selection-info doom-deag-agents)
    '(compilation objed-state misc-info persp-name battery grip irc mu4e gnus github debug repl lsp minor-modes input-method indent-info buffer-encoding major-mode process vcs check time)))

;; 4. Ensure ECA autoloads, binary path, & safe launcher
(defun doom-deag--find-eca-binary ()
  "Locate the external `eca' server binary on PATH or common local bin directories."
  (or (executable-find "eca")
      (cl-find-if #'file-executable-p
                  (mapcar #'expand-file-name
                          '("~/.local/bin/eca"
                            "/opt/homebrew/bin/eca"
                            "/usr/local/bin/eca")))))

(use-package! eca
  :defer t
  :commands (eca eca-chat-toggle-window eca-chat-inline-prompt)
  :init
  (when-let ((eca-bin (doom-deag--find-eca-binary)))
    (setq eca-custom-command (list eca-bin "server"))))

;;;###autoload
(defun doom-deag-open ()
  "Load and launch the ECA orchestrator safely."
  (interactive)
  (when-let ((eca-bin (doom-deag--find-eca-binary)))
    (setq eca-custom-command (list eca-bin "server")))
  (require 'eca nil t)
  (cond
   ((not (or (bound-and-true-p eca-custom-command) (doom-deag--find-eca-binary)))
    (user-error "ECA server binary not found. Install it via Homebrew or into ~/.local/bin/eca"))
   ((commandp 'eca)
    (call-interactively #'eca))
   ((commandp 'eca-chat)
    (call-interactively #'eca-chat))
   (t
    (user-error "eca-emacs is not loaded yet. Run 'doom sync' and restart Emacs (SPC q r)"))))

;; 5. Doom Leader Keybindings (SPC a = Doom Deag Agents)
(map! :leader
      (:prefix ("a" . "agents (doom-deag)")
       :desc "Open Doom Deag Orchestrator" "a" #'doom-deag-open
       :desc "Toggle ECA Chat Window"       "t" #'eca-chat-toggle-window
       :desc "Spawn Terminal Agent"         "s" #'doom-deag-spawn-agent
       :desc "List Active Agents"           "l" #'doom-deag-list-agents
       :desc "Jump to Blocked Agent"        "b" #'doom-deag-jump-blocked
       :desc "Inline ECA Prompt"            "i" #'eca-chat-inline-prompt
       :desc "Clear Finished Agents"        "c" #'doom-deag-clear-finished))

(provide 'doom-deag)
