(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_SCORE (err u201))
(define-constant ERR_BORROWER_NOT_FOUND (err u202))

(define-constant MAX_CREDIT_SCORE u1000)
(define-constant DEFAULT_CREDIT_SCORE u500)
(define-constant SCORE_INCREASE_ONTIME u50)
(define-constant SCORE_INCREASE_EARLY u75)
(define-constant SCORE_DECREASE_LIQUIDATION u200)
(define-constant SCORE_DECREASE_LATE u100)

(define-data-var contract-owner principal tx-sender)
(define-data-var total-borrowers uint u0)

(define-map borrower-credit-records
  principal
  {
    credit-score: uint,
    total-loans: uint,
    successful-repayments: uint,
    liquidations: uint,
    late-repayments: uint,
    early-repayments: uint,
    last-updated-block: uint
  }
)

(define-private (get-borrower-record (borrower principal))
  (default-to {
    credit-score: DEFAULT_CREDIT_SCORE,
    total-loans: u0,
    successful-repayments: u0,
    liquidations: u0,
    late-repayments: u0,
    early-repayments: u0,
    last-updated-block: u0
  }
    (map-get? borrower-credit-records borrower)
  )
)

(define-private (cap-score (score uint))
  (if (> score MAX_CREDIT_SCORE)
    MAX_CREDIT_SCORE
    score
  )
)

(define-public (record-loan-created (borrower principal))
  (let ((record (get-borrower-record borrower)))
    (map-set borrower-credit-records borrower (merge record {
      total-loans: (+ (get total-loans record) u1),
      last-updated-block: stacks-block-height
    }))
    (if (is-eq (get total-loans record) u0)
      (var-set total-borrowers (+ (var-get total-borrowers) u1))
      true
    )
    (ok true)
  )
)

(define-public (record-successful-repayment (borrower principal) (was-early bool))
  (let (
    (record (get-borrower-record borrower))
    (score-increase (if was-early SCORE_INCREASE_EARLY SCORE_INCREASE_ONTIME))
    (new-score (cap-score (+ (get credit-score record) score-increase)))
  )
    (map-set borrower-credit-records borrower (merge record {
      credit-score: new-score,
      successful-repayments: (+ (get successful-repayments record) u1),
      early-repayments: (if was-early (+ (get early-repayments record) u1) (get early-repayments record)),
      last-updated-block: stacks-block-height
    }))
    (ok new-score)
  )
)

(define-public (record-liquidation (borrower principal))
  (let (
    (record (get-borrower-record borrower))
    (new-score (if (> (get credit-score record) SCORE_DECREASE_LIQUIDATION)
                  (- (get credit-score record) SCORE_DECREASE_LIQUIDATION)
                  u0))
  )
    (map-set borrower-credit-records borrower (merge record {
      credit-score: new-score,
      liquidations: (+ (get liquidations record) u1),
      last-updated-block: stacks-block-height
    }))
    (ok new-score)
  )
)

(define-public (record-late-repayment (borrower principal))
  (let (
    (record (get-borrower-record borrower))
    (new-score (if (> (get credit-score record) SCORE_DECREASE_LATE)
                  (- (get credit-score record) SCORE_DECREASE_LATE)
                  u0))
  )
    (map-set borrower-credit-records borrower (merge record {
      credit-score: new-score,
      late-repayments: (+ (get late-repayments record) u1),
      last-updated-block: stacks-block-height
    }))
    (ok new-score)
  )
)

(define-read-only (get-credit-score (borrower principal))
  (ok (get credit-score (get-borrower-record borrower)))
)

(define-read-only (get-full-credit-report (borrower principal))
  (ok (get-borrower-record borrower))
)

(define-read-only (get-credit-rating (borrower principal))
  (let ((score (get credit-score (get-borrower-record borrower))))
    (ok (if (>= score u800) "excellent"
          (if (>= score u650) "good"
            (if (>= score u500) "fair"
              (if (>= score u350) "poor" "critical")))))
  )
)

(define-read-only (get-platform-stats)
  (ok {
    total-borrowers: (var-get total-borrowers),
    contract-owner: (var-get contract-owner)
  })
)
