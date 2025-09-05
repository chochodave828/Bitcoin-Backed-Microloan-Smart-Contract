(define-constant EXTENSION_FEE_RATE u3)
(define-constant MAX_EXTENSIONS u2)
(define-constant EXTENSION_DURATION u72)
(define-constant ERR_MAX_EXTENSIONS_REACHED (err u109))
(define-constant ERR_EXTENSION_NOT_NEEDED (err u110))
(define-constant ERR_EXTENSION_TOO_LATE (err u111))
(define-constant ERR_LOAN_NOT_FOUND (err u101))
(define-constant ERR_UNAUTHORIZED (err u102))

(define-map contract-balances
  (string-ascii 10)
  uint
)

(define-map loans
  uint
  {
    borrower: principal,
    loan-amount: uint,
    interest-amount: uint,
    collateral-amount: uint,
    due-block: uint,
    status: (string-ascii 10),
    repaid-amount: uint,
  }
)

(define-private (get-contract-balance (token (string-ascii 10)))
  (default-to u0 (map-get? contract-balances token))
)

(define-private (set-contract-balance
    (token (string-ascii 10))
    (amount uint)
  )
  (map-set contract-balances token amount)
)

(define-map loan-extensions
  uint
  {
    extensions-used: uint,
    total-extension-fees: uint,
    last-extension-block: uint,
  }
)

(define-private (get-extension-data (loan-id uint))
  (default-to {
    extensions-used: u0,
    total-extension-fees: u0,
    last-extension-block: u0,
  }
    (map-get? loan-extensions loan-id)
  )
)

(define-private (calculate-extension-fee (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data (let (
        (total-repayment (+ (get loan-amount loan-data) (get interest-amount loan-data)))
        (outstanding-balance (- total-repayment (get repaid-amount loan-data)))
      )
      (/ (* outstanding-balance EXTENSION_FEE_RATE) u100)
    )
    u0
  )
)

(define-private (can-extend-loan (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data (let ((extension-data (get-extension-data loan-id)))
      (and
        (is-eq (get status loan-data) "active")
        (< (get extensions-used extension-data) MAX_EXTENSIONS)
        (>= stacks-block-height (- (get due-block loan-data) u20))
        (<= stacks-block-height (+ (get due-block loan-data) u10))
      )
    )
    false
  )
)

(define-public (extend-loan (loan-id uint))
  (let (
      (loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (extension-data (get-extension-data loan-id))
      (extension-fee (calculate-extension-fee loan-id))
      (new-due-block (+ (get due-block loan-data) EXTENSION_DURATION))
    )
    (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (can-extend-loan loan-id) ERR_EXTENSION_NOT_NEEDED)
    (asserts! (< (get extensions-used extension-data) MAX_EXTENSIONS)
      ERR_MAX_EXTENSIONS_REACHED
    )
    (asserts! (>= stacks-block-height (- (get due-block loan-data) u20))
      ERR_EXTENSION_TOO_LATE
    )
    (asserts! (<= stacks-block-height (+ (get due-block loan-data) u10))
      ERR_EXTENSION_TOO_LATE
    )
    (map-set loans loan-id (merge loan-data { due-block: new-due-block }))
    (map-set loan-extensions loan-id {
      extensions-used: (+ (get extensions-used extension-data) u1),
      total-extension-fees: (+ (get total-extension-fees extension-data) extension-fee),
      last-extension-block: stacks-block-height,
    })
    (set-contract-balance "stablecoin"
      (+ (get-contract-balance "stablecoin") extension-fee)
    )
    (ok {
      new-due-block: new-due-block,
      extension-fee: extension-fee,
      extensions-remaining: (- MAX_EXTENSIONS (+ (get extensions-used extension-data) u1)),
    })
  )
)

(define-read-only (get-extension-info (loan-id uint))
  (let ((extension-data (get-extension-data loan-id)))
    (ok {
      extensions-used: (get extensions-used extension-data),
      extensions-remaining: (- MAX_EXTENSIONS (get extensions-used extension-data)),
      total-extension-fees: (get total-extension-fees extension-data),
      can-extend: (can-extend-loan loan-id),
      extension-fee: (calculate-extension-fee loan-id),
    })
  )
)
