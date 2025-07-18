;; wages-vault - Time-locked Salary Release Contract
;; A smart contract for releasing employee salaries after specified time delays

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-not-ready (err u104))
(define-constant err-already-released (err u105))
(define-constant err-unauthorized (err u106))

;; Data Variables
(define-data-var contract-active bool true)

;; Data Maps
(define-map employees
  { employee: principal }
  {
    employer: principal,
    salary-amount: uint,
    release-interval: uint,
    last-release-block: uint,
    total-deposited: uint,
    total-released: uint,
    active: bool
  }
)

(define-map salary-deposits
  { employee: principal, deposit-id: uint }
  {
    employer: principal,
    amount: uint,
    deposit-block: uint,
    release-block: uint,
    released: bool
  }
)

(define-map employee-deposit-count
  { employee: principal }
  { count: uint }
)

;; Read-only functions

(define-read-only (get-employee-info (employee principal))
  (map-get? employees { employee: employee })
)

(define-read-only (get-salary-deposit (employee principal) (deposit-id uint))
  (map-get? salary-deposits { employee: employee, deposit-id: deposit-id })
)

(define-read-only (get-deposit-count (employee principal))
  (default-to { count: u0 } (map-get? employee-deposit-count { employee: employee }))
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (is-salary-ready (employee principal) (deposit-id uint))
  (match (map-get? salary-deposits { employee: employee, deposit-id: deposit-id })
    deposit-info
    (and 
      (not (get released deposit-info))
      (>= block-height (get release-block deposit-info))
    )
    false
  )
)

(define-read-only (get-available-salary (employee principal))
  (let ((employee-info (unwrap! (map-get? employees { employee: employee }) u0)))
    (- (get total-deposited employee-info) (get total-released employee-info))
  )
)

;; Private functions

(define-private (get-next-deposit-id (employee principal))
  (let ((current-count (get count (get-deposit-count employee))))
    (+ current-count u1)
  )
)

;; Public functions

;; Register a new employee
(define-public (register-employee 
  (employee principal) 
  (salary-amount uint) 
  (release-interval uint))
  (let ((sender tx-sender))
    (asserts! (var-get contract-active) err-owner-only)
    (asserts! (is-none (map-get? employees { employee: employee })) err-already-exists)
    (asserts! (> salary-amount u0) err-insufficient-funds)
    (asserts! (> release-interval u0) err-not-ready)
    
    (map-set employees
      { employee: employee }
      {
        employer: sender,
        salary-amount: salary-amount,
        release-interval: release-interval,
        last-release-block: block-height,
        total-deposited: u0,
        total-released: u0,
        active: true
      }
    )
    (ok true)
  )
)

;; Employer deposits salary for an employee
(define-public (deposit-salary (employee principal) (amount uint))
  (let (
    (sender tx-sender)
    (employee-info (unwrap! (map-get? employees { employee: employee }) err-not-found))
    (deposit-id (get-next-deposit-id employee))
    (release-block (+ block-height (get release-interval employee-info)))
  )
    (asserts! (var-get contract-active) err-owner-only)
    (asserts! (is-eq sender (get employer employee-info)) err-unauthorized)
    (asserts! (get active employee-info) err-not-found)
    (asserts! (> amount u0) err-insufficient-funds)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Record the deposit
    (map-set salary-deposits
      { employee: employee, deposit-id: deposit-id }
      {
        employer: sender,
        amount: amount,
        deposit-block: block-height,
        release-block: release-block,
        released: false
      }
    )
    
    ;; Update deposit count
    (map-set employee-deposit-count
      { employee: employee }
      { count: deposit-id }
    )
    
    ;; Update employee total deposited
    (map-set employees
      { employee: employee }
      (merge employee-info { total-deposited: (+ (get total-deposited employee-info) amount) })
    )
    
    (ok deposit-id)
  )
)

;; Employee claims their salary
(define-public (claim-salary (deposit-id uint))
  (let (
    (employee tx-sender)
    (deposit-info (unwrap! (map-get? salary-deposits { employee: employee, deposit-id: deposit-id }) err-not-found))
    (employee-info (unwrap! (map-get? employees { employee: employee }) err-not-found))
  )
    (asserts! (var-get contract-active) err-owner-only)
    (asserts! (get active employee-info) err-not-found)
    (asserts! (not (get released deposit-info)) err-already-released)
    (asserts! (>= block-height (get release-block deposit-info)) err-not-ready)
    
    ;; Transfer salary to employee
    (try! (as-contract (stx-transfer? (get amount deposit-info) tx-sender employee)))
    
    ;; Mark as released
    (map-set salary-deposits
      { employee: employee, deposit-id: deposit-id }
      (merge deposit-info { released: true })
    )
    
    ;; Update employee total released
    (map-set employees
      { employee: employee }
      (merge employee-info { 
        total-released: (+ (get total-released employee-info) (get amount deposit-info)),
        last-release-block: block-height
      })
    )
    
    (ok (get amount deposit-info))
  )
)

;; Emergency withdrawal by employer (before release time)
(define-public (emergency-withdraw (employee principal) (deposit-id uint))
  (let (
    (sender tx-sender)
    (deposit-info (unwrap! (map-get? salary-deposits { employee: employee, deposit-id: deposit-id }) err-not-found))
    (employee-info (unwrap! (map-get? employees { employee: employee }) err-not-found))
  )
    (asserts! (var-get contract-active) err-owner-only)
    (asserts! (is-eq sender (get employer deposit-info)) err-unauthorized)
    (asserts! (not (get released deposit-info)) err-already-released)
    (asserts! (< block-height (get release-block deposit-info)) err-not-ready)
    
    ;; Transfer back to employer
    (try! (as-contract (stx-transfer? (get amount deposit-info) tx-sender sender)))
    
    ;; Mark as released (withdrawn)
    (map-set salary-deposits
      { employee: employee, deposit-id: deposit-id }
      (merge deposit-info { released: true })
    )
    
    ;; Update employee total deposited (subtract withdrawn amount)
    (map-set employees
      { employee: employee }
      (merge employee-info { 
        total-deposited: (- (get total-deposited employee-info) (get amount deposit-info))
      })
    )
    
    (ok (get amount deposit-info))
  )
)

;; Deactivate an employee
(define-public (deactivate-employee (employee principal))
  (let (
    (sender tx-sender)
    (employee-info (unwrap! (map-get? employees { employee: employee }) err-not-found))
  )
    (asserts! (is-eq sender (get employer employee-info)) err-unauthorized)
    (map-set employees
      { employee: employee }
      (merge employee-info { active: false })
    )
    (ok true)
  )
)

;; Contract owner emergency functions
(define-public (toggle-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)