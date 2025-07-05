(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_LOAN_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u102))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u103))
(define-constant ERR_LOAN_NOT_ACTIVE (err u104))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u105))
(define-constant ERR_LOAN_OVERDUE (err u106))
(define-constant ERR_INSUFFICIENT_BALANCE (err u107))
(define-constant ERR_INVALID_AMOUNT (err u108))

(define-constant COLLATERAL_RATIO u150)
(define-constant LIQUIDATION_PENALTY u10)
(define-constant INTEREST_RATE u5)
(define-constant LOAN_DURATION u144)

(define-data-var next-loan-id uint u1)
(define-data-var total-loans-issued uint u0)
(define-data-var total-active-loans uint u0)

(define-map loans
  uint
  {
    borrower: principal,
    collateral-amount: uint,
    loan-amount: uint,
    interest-amount: uint,
    repaid-amount: uint,
    start-block: uint,
    due-block: uint,
    status: (string-ascii 10)
  }
)

(define-map user-loans principal (list 50 uint))

(define-map contract-balances
  (string-ascii 10)
  uint
)

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

(define-private (is-loan-overdue (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
    (and 
      (is-eq (get status loan-data) "active")
      (> stacks-block-height (get due-block loan-data))
    )
    false
  )
)

(define-private (add-user-loan (user principal) (loan-id uint))
  (let ((current-loans (default-to (list) (map-get? user-loans user))))
    (ok (map-set user-loans user (unwrap! (as-max-len? (append current-loans loan-id) u50) (err u999))))
  )
)

(define-public (create-loan (collateral-amount uint) (loan-amount uint))
  (let (
    (loan-id (var-get next-loan-id))
    (required-collateral (/ (* loan-amount COLLATERAL_RATIO) u100))
    (interest-amount (calculate-interest loan-amount))
    (due-block (+ stacks-block-height LOAN_DURATION))
  )
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> loan-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= collateral-amount required-collateral) ERR_INSUFFICIENT_COLLATERAL)
    (asserts! (<= loan-amount (get-contract-balance "stablecoin")) ERR_INSUFFICIENT_BALANCE)
    
    (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
    
    (map-set loans loan-id {
      borrower: tx-sender,
      collateral-amount: collateral-amount,
      loan-amount: loan-amount,
      interest-amount: interest-amount,
      repaid-amount: u0,
      start-block: stacks-block-height,
      due-block: due-block,
      status: "active"
    })
    
    (try! (add-user-loan tx-sender loan-id))
    
    (set-contract-balance "stablecoin" (- (get-contract-balance "stablecoin") loan-amount))
    (set-contract-balance "btc" (+ (get-contract-balance "btc") collateral-amount))
    
    (var-set next-loan-id (+ loan-id u1))
    (var-set total-loans-issued (+ (var-get total-loans-issued) u1))
    (var-set total-active-loans (+ (var-get total-active-loans) u1))
    
    (ok loan-id)
  )
)

(define-public (repay-loan (loan-id uint) (payment-amount uint))
  (let (
    (loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    (total-due (calculate-total-repayment (get loan-amount loan-data)))
    (remaining-due (- total-due (get repaid-amount loan-data)))
    (new-repaid-amount (+ (get repaid-amount loan-data) payment-amount))
  )
    (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
    (asserts! (> payment-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= payment-amount remaining-due) ERR_INSUFFICIENT_PAYMENT)
    
    (if (>= new-repaid-amount total-due)
      (begin
        (try! (as-contract (stx-transfer? (get collateral-amount loan-data) tx-sender (get borrower loan-data))))
        (map-set loans loan-id (merge loan-data {
          repaid-amount: total-due,
          status: "repaid"
        }))
        (set-contract-balance "btc" (- (get-contract-balance "btc") (get collateral-amount loan-data)))
        (var-set total-active-loans (- (var-get total-active-loans) u1))
      )
      (map-set loans loan-id (merge loan-data {
        repaid-amount: new-repaid-amount
      }))
    )
    
    (set-contract-balance "stablecoin" (+ (get-contract-balance "stablecoin") payment-amount))
    (ok true)
  )
)

(define-public (liquidate-loan (loan-id uint))
  (let (
    (loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    (penalty-amount (/ (* (get collateral-amount loan-data) LIQUIDATION_PENALTY) u100))
    (liquidator-reward penalty-amount)
  )
    (asserts! (is-loan-overdue loan-id) ERR_LOAN_NOT_ACTIVE)
    (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
    
    (try! (as-contract (stx-transfer? liquidator-reward tx-sender tx-sender)))
    
    (map-set loans loan-id (merge loan-data {
      status: "liquidated"
    }))
    
    (set-contract-balance "btc" (- (get-contract-balance "btc") (get collateral-amount loan-data)))
    (var-set total-active-loans (- (var-get total-active-loans) u1))
    
    (ok true)
  )
)

(define-public (deposit-stablecoin (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (set-contract-balance "stablecoin" (+ (get-contract-balance "stablecoin") amount))
    (ok true)
  )
)

(define-public (withdraw-stablecoin (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (get-contract-balance "stablecoin")) ERR_INSUFFICIENT_BALANCE)
    (set-contract-balance "stablecoin" (- (get-contract-balance "stablecoin") amount))
    (ok true)
  )
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

(define-read-only (get-user-loans (user principal))
  (default-to (list) (map-get? user-loans user))
)

(define-read-only (get-loan-status (loan-id uint))
  (match (map-get? loans loan-id)
    loan-data
    (ok {
      status: (get status loan-data),
      total-due: (calculate-total-repayment (get loan-amount loan-data)),
      repaid: (get repaid-amount loan-data),
      remaining: (- (calculate-total-repayment (get loan-amount loan-data)) (get repaid-amount loan-data)),
      overdue: (is-loan-overdue loan-id)
    })
    ERR_LOAN_NOT_FOUND
  )
)

(define-read-only (calculate-required-collateral (loan-amount uint))
  (/ (* loan-amount COLLATERAL_RATIO) u100)
)

(define-read-only (get-contract-stats)
  {
    total-loans-issued: (var-get total-loans-issued),
    total-active-loans: (var-get total-active-loans),
    available-liquidity: (get-contract-balance "stablecoin"),
    total-collateral: (get-contract-balance "btc"),
    collateral-ratio: COLLATERAL_RATIO,
    interest-rate: INTEREST_RATE,
    loan-duration: LOAN_DURATION
  }
)