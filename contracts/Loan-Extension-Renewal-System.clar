(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_LOAN_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u108))

(define-constant EXTENSION_FEE_RATE u3)
(define-constant MAX_EXTENSIONS u3)
(define-constant EXTENSION_DURATION u72)
(define-constant INTEREST_RATE u5)

(define-constant ERR_MAX_EXTENSIONS_REACHED (err u111))
(define-constant ERR_EXTENSION_NOT_ALLOWED (err u112))

(define-map loans uint {borrower: principal, collateral-amount: uint, loan-amount: uint, interest-amount: uint, repaid-amount: uint, start-block: uint, due-block: uint, status: (string-ascii 10), extensions-used: uint})
(define-map contract-balances (string-ascii 10) uint)

(define-private (get-contract-balance (token (string-ascii 10)))
  (default-to u0 (map-get? contract-balances token))
)

(define-private (set-contract-balance (token (string-ascii 10)) (amount uint))
  (map-set contract-balances token amount)
)

(define-private (calculate-interest (principal-amount uint))
  (/ (* principal-amount INTEREST_RATE) u100)
)

(define-private (calculate-total-repayment (loan-amount uint))
  (+ loan-amount (calculate-interest loan-amount))
)

(define-private (calculate-extension-fee (remaining-amount uint))
  (/ (* remaining-amount EXTENSION_FEE_RATE) u100)
)

(define-private (is-extension-allowed (loan-data {borrower: principal, collateral-amount: uint, loan-amount: uint, interest-amount: uint, repaid-amount: uint, start-block: uint, due-block: uint, status: (string-ascii 10), extensions-used: uint}))
  (and 
    (is-eq (get status loan-data) "active")
    (< (get extensions-used loan-data) MAX_EXTENSIONS)
    (> (get due-block loan-data) (- stacks-block-height u10))
  )
)

(define-public (extend-loan (loan-id uint))
  (let (
    (loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    (total-due (calculate-total-repayment (get loan-amount loan-data)))
    (remaining-due (- total-due (get repaid-amount loan-data)))
    (extension-fee (calculate-extension-fee remaining-due))
    (new-due-block (+ (get due-block loan-data) EXTENSION_DURATION))
    (new-extensions-count (+ (get extensions-used loan-data) u1))
  )
    (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-extension-allowed loan-data) ERR_EXTENSION_NOT_ALLOWED)
    (asserts! (< (get extensions-used loan-data) MAX_EXTENSIONS) ERR_MAX_EXTENSIONS_REACHED)
    (asserts! (> extension-fee u0) ERR_INVALID_AMOUNT)
    
    (map-set loans loan-id (merge loan-data {
      due-block: new-due-block,
      extensions-used: new-extensions-count,
      repaid-amount: (+ (get repaid-amount loan-data) extension-fee)
    }))
    
    (set-contract-balance "stablecoin" (+ (get-contract-balance "stablecoin") extension-fee))
    (ok {
      new-due-block: new-due-block,
      extension-fee: extension-fee,
      extensions-remaining: (- MAX_EXTENSIONS new-extensions-count)
    })
  )
)

(define-read-only (get-extension-info (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
    (let (
      (total-due (calculate-total-repayment (get loan-amount loan-data)))
      (remaining-due (- total-due (get repaid-amount loan-data)))
      (extension-fee (calculate-extension-fee remaining-due))
    )
      (ok {
        extensions-used: (get extensions-used loan-data),
        extensions-remaining: (- MAX_EXTENSIONS (get extensions-used loan-data)),
        extension-fee: extension-fee,
        can-extend: (is-extension-allowed loan-data)
      })
    )
    ERR_LOAN_NOT_FOUND
  )
)