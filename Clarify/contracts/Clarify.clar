;; ClarityNet Smart Contract for Message Clarification and Validation

;; Error constants
(define-constant err-not-admin (err u100))
(define-constant err-msg-processed (err u101))
(define-constant err-still-pending (err u102))
(define-constant err-msg-missing (err u103))
(define-constant err-msg-locked (err u104))
(define-constant err-invalid-timeout-period (err u105))
(define-constant err-invalid-subject-length (err u106))
(define-constant err-invalid-content-length (err u107))
(define-constant err-invalid-msg-type (err u108))
(define-constant err-msg-disabled (err u109))
(define-constant err-self-interaction (err u110))
(define-constant err-network-paused (err u111))
(define-constant err-invalid-tags (err u112))
(define-constant err-invalid-msg-hash (err u113))
(define-constant err-invalid-target (err u114))
(define-constant err-invalid-private-flag (err u115))

;; Constants
(define-constant network-admin tx-sender)
(define-constant max-subject-length u64)
(define-constant max-content-length u256)
(define-constant min-timeout-period u1)
(define-constant max-timeout-period u52560)
(define-constant text-type "text")
(define-constant image-type "image")
(define-constant voice-type "voice")

;; Data Variables
(define-data-var message-counter uint u0)
(define-data-var random-seed uint u1)
(define-data-var network-paused bool false)

;; Define message structure
(define-map messages uint {
    author: principal,
    msg-hash: (string-ascii 256),
    activation-block: uint,
    is-private: bool,
    is-processed: bool,
    is-disabled: bool,
    target-user: (optional principal),
    upvotes: uint,
    downvotes: uint,
    msg-type: (string-ascii 5)
})

;; Define message metadata
(define-map message-details uint {
    msg-subject: (string-ascii 64),
    msg-content: (string-ascii 256),
    creation-block: uint,
    last-update: uint,
    tags: (list 5 (string-ascii 32))
})

;; User activity tracking
(define-map user-activity principal {
    messages-posted: uint,
    messages-claimed: uint,
    upvotes-given: uint
})

;; Message upvote tracking
(define-map message-upvotes (tuple (msg-id uint) (user principal)) bool)

;; Private validation functions
(define-private (is-valid-msg-type (msg-type (string-ascii 5)))
    (and 
        (is-some (as-max-len? msg-type u5))
        (or 
            (is-eq msg-type text-type)
            (is-eq msg-type image-type)
            (is-eq msg-type voice-type)
        )))

(define-private (sanitize-msg-hash (msg-hash (string-ascii 256)))
    (match (as-max-len? msg-hash u256)
        success (ok msg-hash)
        (err err-invalid-msg-hash)))

(define-private (sanitize-timeout-period (timeout-period uint))
    (if (and (>= timeout-period min-timeout-period) (<= timeout-period max-timeout-period))
        (ok timeout-period)
        (err err-invalid-timeout-period)))

(define-private (sanitize-subject (subject (string-ascii 64)))
    (match (as-max-len? subject u64)
        success (if (<= (len subject) max-subject-length)
            (ok subject)
            (err err-invalid-subject-length))
        (err err-invalid-subject-length)))

(define-private (sanitize-content (content (string-ascii 256)))
    (match (as-max-len? content u256)
        success (if (<= (len content) max-content-length)
            (ok content)
            (err err-invalid-content-length))
        (err err-invalid-content-length)))

(define-private (sanitize-tags (tags (list 5 (string-ascii 32))))
    (match (as-max-len? tags u5)
        success (ok tags)
        (err err-invalid-tags)))

(define-private (sanitize-target (target (optional principal)))
    (ok target))

(define-private (sanitize-private-flag (is-private bool))
    (if (or (is-eq is-private true) (is-eq is-private false))
        (ok is-private)
        (err err-invalid-private-flag)))

(define-private (update-user-stats (user principal) (action (string-ascii 6)))
    (let ((current-stats (default-to 
            { messages-posted: u0, messages-claimed: u0, upvotes-given: u0 }
            (map-get? user-activity user))))
        (if (is-eq action "post")
            (map-set user-activity user (merge current-stats { messages-posted: (+ (get messages-posted current-stats) u1) }))
            (if (is-eq action "claim")
                (map-set user-activity user (merge current-stats { messages-claimed: (+ (get messages-claimed current-stats) u1) }))
                (if (is-eq action "upvote")
                    (map-set user-activity user (merge current-stats { upvotes-given: (+ (get upvotes-given current-stats) u1) }))
                    false)))))

;; Public functions

;; Contract management
(define-public (toggle-network-pause)
    (begin
        (asserts! (is-eq tx-sender network-admin) (err err-not-admin))
        (ok (var-set network-paused (not (var-get network-paused))))))

;; Create a new message
(define-public (create-message 
    (msg-hash (string-ascii 256)) 
    (msg-subject (string-ascii 64))
    (msg-content (string-ascii 256))
    (msg-type (string-ascii 5))
    (timeout-period uint)
    (is-private bool)
    (target-user (optional principal))
    (tags (list 5 (string-ascii 32))))
    
    (begin
        (asserts! (not (var-get network-paused)) (err err-network-paused))
        
        ;; Validate and sanitize all inputs upfront
        (asserts! (is-some (as-max-len? msg-subject u64)) (err err-invalid-subject-length))
        (asserts! (is-some (as-max-len? msg-content u256)) (err err-invalid-content-length))
        (asserts! (is-valid-msg-type msg-type) (err err-invalid-msg-type))
        (asserts! (and (>= timeout-period min-timeout-period) (<= timeout-period max-timeout-period)) (err err-invalid-timeout-period))
        (asserts! (is-some (as-max-len? msg-hash u256)) (err err-invalid-msg-hash))
        (asserts! (is-some (as-max-len? tags u5)) (err err-invalid-tags))
        (asserts! (<= (len msg-subject) max-subject-length) (err err-invalid-subject-length))
        (asserts! (<= (len msg-content) max-content-length) (err err-invalid-content-length))
        (asserts! (or (is-eq is-private true) (is-eq is-private false)) (err err-invalid-private-flag))
        
        (let ((msg-id (var-get message-counter))
              (activation-block (+ stacks-block-height timeout-period))
              (validated-target (if (is-some target-user) target-user none)))
            
            ;; Store message data with validated inputs
            (map-set messages msg-id {
                author: tx-sender,
                msg-hash: msg-hash,
                activation-block: activation-block,
                is-private: is-private,
                is-processed: false,
                is-disabled: false,
                target-user: validated-target,
                upvotes: u0,
                downvotes: u0,
                msg-type: msg-type
            })
            
            ;; Store metadata with validated inputs
            (map-set message-details msg-id {
                msg-subject: msg-subject,
                msg-content: msg-content,
                creation-block: stacks-block-height,
                last-update: stacks-block-height,
                tags: tags
            })
            
            ;; Update stats
            (update-user-stats tx-sender "post")
            
            ;; Increment total messages
            (var-set message-counter (+ msg-id u1))
            (ok msg-id))))

;; Process a message
(define-public (process-message (msg-id uint))
    (let ((message (unwrap! (map-get? messages msg-id) (err err-msg-missing))))
        (asserts! (not (var-get network-paused)) (err err-network-paused))
        (asserts! (not (get is-disabled message)) (err err-msg-disabled))
        (asserts! (>= stacks-block-height (get activation-block message)) (err err-still-pending))
        (asserts! (not (get is-processed message)) (err err-msg-processed))
        (asserts! (or
            (is-none (get target-user message))
            (is-eq (some tx-sender) (get target-user message)))
            (err err-not-admin))
        
        ;; Mark as processed and update stats
        (map-set messages msg-id (merge message { is-processed: true }))
        (update-user-stats tx-sender "claim")
        (ok true)))

;; Upvote a message
(define-public (upvote-message (msg-id uint))
    (let ((message (unwrap! (map-get? messages msg-id) (err err-msg-missing)))
          (upvote-key {msg-id: msg-id, user: tx-sender}))
        (asserts! (not (var-get network-paused)) (err err-network-paused))
        (asserts! (not (get is-disabled message)) (err err-msg-disabled))
        (asserts! (>= stacks-block-height (get activation-block message)) (err err-still-pending))
        (asserts! (is-none (map-get? message-upvotes upvote-key)) (err err-msg-processed))
        
        ;; Update upvotes count and record user interaction
        (map-set messages msg-id (merge message { upvotes: (+ (get upvotes message) u1) }))
        (map-set message-upvotes upvote-key true)
        (update-user-stats tx-sender "upvote")
        (ok true)))

;; Report problematic content
(define-public (report-content (msg-id uint))
    (let ((message (unwrap! (map-get? messages msg-id) (err err-msg-missing))))
        (asserts! (not (var-get network-paused)) (err err-network-paused))
        (asserts! (not (get is-disabled message)) (err err-msg-disabled))
        
        ;; Increment downvotes count
        (map-set messages msg-id (merge message { downvotes: (+ (get downvotes message) u1) }))
        (ok true)))

;; Disable message (only author or network admin)
(define-public (disable-message (msg-id uint))
    (let ((message (unwrap! (map-get? messages msg-id) (err err-msg-missing))))
        (asserts! (or 
            (is-eq tx-sender (get author message))
            (is-eq tx-sender network-admin))
            (err err-not-admin))
        
        (map-set messages msg-id (merge message { is-disabled: true }))
        (ok true)))

;; Find a random unprocessed message
(define-public (find-random-message)
    (let ((current-seed (var-get random-seed))
          (total (var-get message-counter)))
        
        (asserts! (not (var-get network-paused)) (err err-network-paused))
        
        ;; Update random seed
        (var-set random-seed (+ current-seed stacks-block-height))
        
        ;; Get random message ID
        (let ((random-id (mod current-seed total)))
            (ok (unwrap! (map-get? messages random-id) (err err-msg-missing))))))

;; Read functions

;; Get message details if activation time reached
(define-read-only (get-message-info (msg-id uint))
    (let ((message (unwrap! (map-get? messages msg-id) (err err-msg-missing))))
        (asserts! (not (get is-disabled message)) (err err-msg-disabled))
        (if (>= stacks-block-height (get activation-block message))
            (ok {
                message: message,
                details: (unwrap! (map-get? message-details msg-id) (err err-msg-missing))
            })
            (err err-still-pending))))

;; Get user statistics
(define-read-only (get-user-stats (user principal))
    (ok (default-to 
        { messages-posted: u0, messages-claimed: u0, upvotes-given: u0 }
        (map-get? user-activity user))))

;; Get total number of messages
(define-read-only (get-total-messages)
    (ok (var-get message-counter)))

;; Check if message is upvoted by user
(define-read-only (is-message-upvoted-by-user (msg-id uint) (user principal))
    (ok (is-some (map-get? message-upvotes {msg-id: msg-id, user: user}))))