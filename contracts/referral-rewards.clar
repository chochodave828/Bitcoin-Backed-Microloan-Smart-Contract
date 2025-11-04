(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_SELF_REFERRAL (err u301))
(define-constant ERR_ALREADY_REFERRED (err u302))
(define-constant ERR_REFERRER_NOT_FOUND (err u303))
(define-constant ERR_INVALID_AMOUNT (err u304))

(define-constant TIER_1_REWARD_RATE u15)
(define-constant TIER_2_REWARD_RATE u10)
(define-constant TIER_3_REWARD_RATE u5)
(define-constant TIER_1_THRESHOLD u5)
(define-constant TIER_2_THRESHOLD u3)

(define-data-var contract-owner principal tx-sender)
(define-data-var total-referrers uint u0)
(define-data-var total-rewards-distributed uint u0)

(define-map referral-relationships
  principal
  {
    referrer: principal,
    referral-block: uint,
    loans-completed: uint,
    total-rewards-earned: uint
  }
)

(define-map referrer-stats
  principal
  {
    total-referrals: uint,
    active-referrals: uint,
    successful-loans: uint,
    total-rewards-earned: uint,
    tier: (string-ascii 10)
  }
)

(define-private (get-referrer-record (referrer principal))
  (default-to {
    total-referrals: u0,
    active-referrals: u0,
    successful-loans: u0,
    total-rewards-earned: u0,
    tier: "tier-3"
  }
    (map-get? referrer-stats referrer)
  )
)

(define-private (calculate-tier (successful-loans uint))
  (if (>= successful-loans TIER_1_THRESHOLD) "tier-1"
    (if (>= successful-loans TIER_2_THRESHOLD) "tier-2" "tier-3"))
)

(define-private (get-reward-rate (tier (string-ascii 10)))
  (if (is-eq tier "tier-1") TIER_1_REWARD_RATE
    (if (is-eq tier "tier-2") TIER_2_REWARD_RATE TIER_3_REWARD_RATE))
)

(define-public (register-referral (borrower principal) (referrer principal))
  (begin
    (asserts! (not (is-eq borrower referrer)) ERR_SELF_REFERRAL)
    (asserts! (is-none (map-get? referral-relationships borrower)) ERR_ALREADY_REFERRED)
    (let ((referrer-record (get-referrer-record referrer)))
      (map-set referral-relationships borrower {
        referrer: referrer,
        referral-block: stacks-block-height,
        loans-completed: u0,
        total-rewards-earned: u0
      })
      (map-set referrer-stats referrer (merge referrer-record {
        total-referrals: (+ (get total-referrals referrer-record) u1),
        active-referrals: (+ (get active-referrals referrer-record) u1)
      }))
      (if (is-eq (get total-referrals referrer-record) u0)
        (var-set total-referrers (+ (var-get total-referrers) u1))
        true
      )
      (ok true)
    )
  )
)

(define-public (distribute-referral-reward (borrower principal) (interest-collected uint))
  (match (map-get? referral-relationships borrower)
    relationship
    (let (
      (referrer (get referrer relationship))
      (referrer-record (get-referrer-record referrer))
      (new-successful-loans (+ (get successful-loans referrer-record) u1))
      (new-tier (calculate-tier new-successful-loans))
      (reward-rate (get-reward-rate new-tier))
      (reward-amount (/ (* interest-collected reward-rate) u100))
    )
      (asserts! (> interest-collected u0) ERR_INVALID_AMOUNT)
      (map-set referral-relationships borrower (merge relationship {
        loans-completed: (+ (get loans-completed relationship) u1),
        total-rewards-earned: (+ (get total-rewards-earned relationship) reward-amount)
      }))
      (map-set referrer-stats referrer (merge referrer-record {
        successful-loans: new-successful-loans,
        total-rewards-earned: (+ (get total-rewards-earned referrer-record) reward-amount),
        tier: new-tier
      }))
      (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) reward-amount))
      (ok reward-amount)
    )
    (ok u0)
  )
)

(define-read-only (get-referrer-info (referrer principal))
  (ok (get-referrer-record referrer))
)

(define-read-only (get-borrower-referral (borrower principal))
  (ok (map-get? referral-relationships borrower))
)

(define-read-only (get-platform-referral-stats)
  (ok {
    total-referrers: (var-get total-referrers),
    total-rewards-distributed: (var-get total-rewards-distributed)
  })
)
