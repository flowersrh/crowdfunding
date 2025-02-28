;; --------------------------------------------------------------------------
;; Crowdfunding Smart Contract
;; --------------------------------------------------------------------------
;; This contract enables users to create crowdfunding campaigns, contribute funds,
;; withdraw successfully raised funds, and request refunds if a campaign fails.
;; --------------------------------------------------------------------------

;; ----------------------------- Constants ----------------------------------
(define-constant SYSTEM_ADMIN tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_CAMPAIGN_MISSING (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_CAMPAIGN_ENDED (err u103))
(define-constant ERR_GOAL_NOT_ACHIEVED (err u104))
(define-constant ERR_TRANSFER_FAILURE (err u105))
(define-constant ERR_ALREADY_REFUNDED (err u106))
(define-constant CAMPAIGN_LIFETIME u2016) ;; Approx. 14 days assuming 10-minute blocks

;; --------------------------- Data Structures -----------------------------
(define-map FundraisingCampaigns
  { campaign-ref: uint }
  {
    initiator: principal,
    funding-target: uint,
    total-contributions: uint,
    expiry-block: uint,
    current-status: (string-ascii 10)
  }
)

(define-map ContributorRecords
  { campaign-ref: uint, supporter: principal }
  { pledged-amount: uint }
)

;; ---------------------------- State Variables ----------------------------
(define-data-var latest-campaign-ref uint u0)

;; --------------------------- Helper Functions ----------------------------
(define-private (campaign-exists? (campaign-ref uint))
  (<= campaign-ref (var-get latest-campaign-ref))
)

(define-private (is-contribution-valid? (campaign-state (string-ascii 10)))
  (is-eq campaign-state "active")
)

;; --------------------------- Public Functions ----------------------------
(define-public (initialize-campaign (target-funds uint))
  (let
    (
      (new-ref (+ (var-get latest-campaign-ref) u1))
      (expiry (+ stacks-block-height CAMPAIGN_LIFETIME))
    )
    (asserts! (> target-funds u0) ERR_INVALID_AMOUNT)
    (map-set FundraisingCampaigns
      { campaign-ref: new-ref }
      {
        initiator: tx-sender,
        funding-target: target-funds,
        total-contributions: u0,
        expiry-block: expiry,
        current-status: "active"
      }
    )
    (var-set latest-campaign-ref new-ref)
    (print {event: "campaign_created", ref: new-ref, initiator: tx-sender, target: target-funds})
    (ok new-ref)
  )
)

(define-public (support-campaign (campaign-ref uint) (amount uint))
  (let
    (
      (campaign (unwrap! (map-get? FundraisingCampaigns { campaign-ref: campaign-ref }) ERR_CAMPAIGN_MISSING))
      (state (get current-status campaign))
      (accumulated (get total-contributions campaign))
      (new-total (+ accumulated amount))
      (current-contribution (default-to { pledged-amount: u0 } 
        (map-get? ContributorRecords { campaign-ref: campaign-ref, supporter: tx-sender })))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (campaign-exists? campaign-ref) ERR_CAMPAIGN_MISSING)
    (asserts! (is-contribution-valid? state) ERR_CAMPAIGN_ENDED)
    (asserts! (<= stacks-block-height (get expiry-block campaign)) ERR_CAMPAIGN_ENDED)
    (match (stx-transfer? amount tx-sender (as-contract tx-sender))
      success
        (begin
          (map-set FundraisingCampaigns
            { campaign-ref: campaign-ref }
            (merge campaign { total-contributions: new-total })
          )
          (map-set ContributorRecords
            { campaign-ref: campaign-ref, supporter: tx-sender }
            { pledged-amount: (+ (get pledged-amount current-contribution) amount) }
          )
          (print {event: "funds_contributed", ref: campaign-ref, supporter: tx-sender, amount: amount})
          (ok true)
        )
      error ERR_TRANSFER_FAILURE
    )
  )
)

(define-public (retrieve-funds (campaign-ref uint))
  (let
    (
      (campaign (unwrap! (map-get? FundraisingCampaigns { campaign-ref: campaign-ref }) ERR_CAMPAIGN_MISSING))
      (initiator (get initiator campaign))
      (target (get funding-target campaign))
      (accumulated (get total-contributions campaign))
      (state (get current-status campaign))
    )
    (asserts! (campaign-exists? campaign-ref) ERR_CAMPAIGN_MISSING)
    (asserts! (is-eq tx-sender initiator) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq state "active") ERR_CAMPAIGN_ENDED)
    (asserts! (>= accumulated target) ERR_GOAL_NOT_ACHIEVED)
    (match (stx-transfer? accumulated (as-contract tx-sender) initiator)
      success
        (begin
          (map-set FundraisingCampaigns
            { campaign-ref: campaign-ref }
            (merge campaign { current-status: "completed" })
          )
          (print {event: "funds_retrieved", ref: campaign-ref, amount: accumulated})
          (ok true)
        )
      error ERR_TRANSFER_FAILURE
    )
  )
)

(define-public (request-refund (campaign-ref uint))
  (let
    (
      (campaign (unwrap! (map-get? FundraisingCampaigns { campaign-ref: campaign-ref }) ERR_CAMPAIGN_MISSING))
      (state (get current-status campaign))
      (expiry (get expiry-block campaign))
      (contribution (unwrap! (map-get? ContributorRecords { campaign-ref: campaign-ref, supporter: tx-sender }) ERR_NOT_AUTHORIZED))
      (amount (get pledged-amount contribution))
    )
    (asserts! (campaign-exists? campaign-ref) ERR_CAMPAIGN_MISSING)
    (asserts! (is-eq state "active") ERR_CAMPAIGN_ENDED)
    (asserts! (> stacks-block-height expiry) ERR_CAMPAIGN_ENDED)
    (asserts! (> amount u0) ERR_ALREADY_REFUNDED)
    (match (stx-transfer? amount (as-contract tx-sender) tx-sender)
      success
        (begin
          (map-set ContributorRecords
            { campaign-ref: campaign-ref, supporter: tx-sender }
            { pledged-amount: u0 }
          )
          (map-set FundraisingCampaigns
            { campaign-ref: campaign-ref }
            (merge campaign { total-contributions: (- (get total-contributions campaign) amount) })
          )
          (print {event: "refund_processed", ref: campaign-ref, supporter: tx-sender, amount: amount})
          (ok true)
        )
      error ERR_TRANSFER_FAILURE
    )
  )
)

;; --------------------------- Read-Only Functions ----------------------------
(define-read-only (fetch-campaign (campaign-ref uint))
  (map-get? FundraisingCampaigns { campaign-ref: campaign-ref })
)

(define-read-only (fetch-latest-campaign-ref)
  (ok (var-get latest-campaign-ref))
)

(define-read-only (fetch-contribution (campaign-ref uint) (supporter principal))
  (map-get? ContributorRecords { campaign-ref: campaign-ref, supporter: supporter })
)
