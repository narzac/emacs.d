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

(defun work-start ()
  "Start the work day."
  (interactive)
  (let ((messages '("Hi guys!"
                    "Good morning everyone!"
                    "Hello there!"
                    "Hej Företagsplatsers!")))
    (slack-say (seq-random-elt messages))
    (slack-set-active)
    (org-revert-all-org-buffers)
    (work-clock-in)
    (work-send-weekly-email)))

(defun work-stop ()
  "End of the day!"
  (interactive)
  (let ((messages '("Time to go, see you guys!"
                    "I'm off for the day, see you!"
                    ":house: :walking: Cya!"
                    "Leaving, have a nice evening everyone :-)")))
    (slack-say (seq-random-elt messages))
    (slack-set-away)
    (work-clock-out)
    (save-some-buffers)))

(defun work-lunch ()
  "Stop the clock for lunch."
  (interactive)
  (let ((messages '("Lunch time!"
                    "Food guys, see you!"
                    "Time to get some food")))
    (slack-set-away)
    (slack-say (seq-random-elt messages)))
  (work-clock-out))

(defun work-back-from-lunch ()
  "Start the clock again when coming back from lunch."
  (interactive)
  (let ((messages '("I'm back!"
                    "Back from lunch"
                    "Back!"
                    "Back to business")))
    (slack-set-active)
    (slack-say (seq-random-elt messages)))
  (work-clock-in))

(defun work-coffee ()
  "Send a \"Coffee break\"-like message on #general."
  (interactive)
  (slack-say (seq-random-elt '("Getting a :coffee:"
			       ":coffee: break"
			       ":coffee:"))))

(defun slack-token ()
  "Return the slack token from pass."
  (password-store-get "slack-token"))

(defun slack-say (message)
  "Send MESSAGE on the general channel."
  (let ((token (slack-token))
        (team "foretagsplatsen")
        (channel "C02N47RE1"))
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

(defun work-clock-in ()
  (interactive)
  (with-current-buffer (find-file-noselect "~/org/gtd.org")
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (org-find-entry-with-id "work-clock"))
        (org-clock-in)))))

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

;;; Send emails as recurring tasks

(defun work-send-email (from to subject body)
  "Send an email from FROM to TO with SUBJECT and BODY."
  (with-temp-buffer
    (insert (format "From: %s\n" from))
    (insert (format "to: %s\n" to))
    (insert (format "subject: %s\n--text follows this line--\n" subject))
    (insert body)
    (message-send-mail)))

(defun work-day-of-week ()
  "Return the current day of week number."
  (calendar-day-of-week (calendar-current-date)))

(defun work-current-week-number ()
  "Return the current week number of the year."
  (org-days-to-iso-week (time-to-day-in-year (current-time))))

(defun work-send-weekly-email ()
  "Send a mail every monday about the coming week."
  (interactive)
  (when (= (work-day-of-week) 1) ;; send this email every Monday
    (work-send-email "nicolas@petton.fr"
                     "ftgp@googlegroups.com"
                     (format "[Week %s] What does your week look like?" (work-current-week-number))
                     "Dear FTGP-ers,\n\nNew week, new opportunities!\nWhat does your week look like?")))

(provide 'workflow)
;;; workflow.el ends here
