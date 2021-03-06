;;; workflow.el --- basic daily workflow             -*- lexical-binding: t; -*-

;; Copyright (C) 2016  Nicolas Petton

;; Author: Nicolas Petton <nicolas@petton.fr>
;; Keywords: convenience

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

;;

;;; Code:

(require 'url)
(require 'seq)
(require 'password-store)
(require 'org-pomodoro)
(require 'htmlize)

;;;###autoload
(defun work-start ()
  "Start the work day."
  (interactive)
  (let ((messages '("Hi guys!"
                    "Good morning everyone!"
                    "Hello there!"
                    "Hej Företagsplatsers!")))
    (slack-say (seq-random-elt messages))
    (slack-set-active)
    (start-process-shell-command "slack" nil "slack")
    (start-process-shell-command "nightly" nil "nightly")
    (mount-backup-disk)))

;;;###autoload
(defun work-stop ()
  "End of the day!"
  (interactive)
  (let ((messages '("Time to go, see you guys!"
                    "I'm off for the day, see you!"
                    ":house: :walking: Cya!"
                    "Leaving, have a nice evening everyone :-)")))
    (slack-say (seq-random-elt messages))
    (slack-set-away)
    (shell-command "pkill slack")
    (save-some-buffers)
    (umount-backup-disk)))

;;;###autoload
(defun work-lunch ()
  "Stop the clock for lunch."
  (interactive)
  (let ((messages '("Lunch time!"
                    "Food guys, see you!"
                    "Time to get some food")))
    (slack-set-away)
    (slack-say (seq-random-elt messages))))

;;;###autoload
(defun work-back-from-lunch ()
  "Start the clock again when coming back from lunch."
  (interactive)
  (let ((messages '("I'm back!"
                    "Back from lunch"
                    "Back!"
                    "Back to business")))
    (slack-set-active)
    (slack-say (seq-random-elt messages))))

;;;###autoload
(defun work-coffee ()
  "Send a \"Coffee break\"-like message on #general."
  (interactive)
  (slack-say (seq-random-elt '("Getting a :coffee:"
			       ":coffee: break"
			       ":coffee:"))))

(defun slack-token ()
  "Return the slack token from pass."
  (password-store-get "slack-token"))

(defun slack-say (message &optional channel)
  "Send a MESSAGE on Slack.
Use CHANNEL if non-nil of the general channel if nil."
  (let ((token (slack-token))
        (team "foretagsplatsen")
        (channel (or channel "C02N47RE1")))
    (url-retrieve (format "https://%s.slack.com/api/chat.postMessage?token=%s&channel=%s&text=%s&as_user=true"
                   team
                   token
                   channel
                   message)
                  (lambda (&rest _)))))

(defun slack-set-presence (presence)
  "The the presence to PRESENCE on Slack."
  (let ((token (slack-token))
        (team "foretagsplatsen"))
    (url-retrieve (format "https://%s.slack.com/api/presence.set?presence=%s&token=%s&as_user=true"
                   team
                   presence
                   token)
                  (lambda (&rest _)))))

(defun slack-set-away ()
  "Set the Slack presence to away."
  (slack-set-presence "away"))

(defun slack-set-active ()
  "Set the slack presence to active."
  (slack-set-presence "active"))

;;;###autoload
(defun work-clock-in ()
  (interactive)
  (with-current-buffer (find-file-noselect "~/org/gtd.org")
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (org-find-entry-with-id "work-clock"))
        (org-clock-in)))))

;;;###autoload
(defun work-clock-out ()
  (interactive)
  (with-current-buffer (find-file-noselect "~/org/gtd.org")
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (org-find-entry-with-id "work-clock"))
        (org-clock-out)))))

(defun work-slack-say-pomodoro-started ()
  (slack-say "I started a pomodoro, talk to me in 25'!")
  (slack-set-away))

(defun work-slack-say-pomodoro-finished ()
  (message "Pomodoro finished!")
  (slack-say "I finished a pomodoro, you can now talk to me!")
  (slack-set-active))

(dolist (hook '(org-pomodoro-started-hook))
  (add-hook hook #'work-slack-say-pomodoro-started))

(dolist (hook '(org-pomodoro-killed-hook
                org-pomodoro-finished-hook))
  (add-hook hook #'work-slack-say-pomodoro-finished))

;;;###autoload
(defun mount-backup-disk ()
  (interactive)
  (start-process-shell-command "mount-backup.sh"
			       "*mount-backup*"
			       (executable-find "mount-backup.sh")))

;;;###autoload
(defun umount-backup-disk ()
  (interactive)
  (start-process-shell-command "umount-backup.sh"
			       "*umount-backup*"
			       (executable-find "umount-backup.sh")))

;;; Send emails as recurring tasks

(defun work-send-email (from to subject body)
  "Send an email from FROM to TO with SUBJECT and BODY."
  (with-temp-buffer
    (insert (format "From: %s\n" from))
    (insert (format "to: %s\n" to))
    (insert (format "subject: %s\n--text follows this line--\n" subject))
    (insert body)
    (message-send-mail)))

;;;###autoload
(defun send-budget-email ()
  (interactive)
  (let ((ledger-file "~/org/reference/ledger/journal.ledger")
	(budget-filename (format "/tmp/%s" (make-temp-name "ledger-budget")))
	(html-filename (format "/tmp/%s.html" (make-temp-name "budget-html"))))
    (with-current-buffer (find-file-noselect ledger-file)
      (ledger-report "Budget" nil))
    (with-current-buffer "*Ledger Report*"
      (write-file budget-filename))
    (htmlize-file budget-filename html-filename)
    (let ((from "nicolas@petton.fr")
	  (to "aurelia@saout.fr")
	  (subject (format "Budget %s" (format-time-string "%d/%m/%Y"))))
      (switch-to-buffer "Budget email")
      (message-mode)
      (insert (format "From: %s\n" from))
      (insert (format "to: %s\n" to))
      (insert (format "subject: %s\n--text follows this line--\n" subject))
      (insert (format "<#part type=\"text/html\" filename=\"%s\" disposition=attachment><#/part>"
		      html-filename))
      ;; (message-send-mail)
      )))

(provide 'workflow)
;;; workflow.el ends here
