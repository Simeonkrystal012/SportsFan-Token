;; SportsFan Token
;; A fungible token for sports team membership and voting rights

;; Define the fungible token
(define-fungible-token sportsfan)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))

;; Data maps
(define-map user-votes { voter: principal } { has-voted: bool })
(define-map match-tickets { match-id: uint, holder: principal } { amount: uint })

;; Public functions

;; Mint new tokens (restricted to contract owner)
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ft-mint? sportsfan amount recipient)
    )
)

;; Transfer tokens between users
(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (ft-transfer? sportsfan amount sender recipient)
)

;; Purchase match tickets with tokens
(define-public (buy-match-ticket (match-id uint) (amount uint))
    (let ((ticket-price u10))
        (begin
            (try! (ft-burn? sportsfan ticket-price tx-sender))
            (map-set match-tickets { match-id: match-id, holder: tx-sender } { amount: amount })
            (ok true)
        )
    )
)

;; Cast vote on team decisions
(define-public (cast-vote (proposal-id uint))
    (let ((voter-balance (ft-get-balance sportsfan tx-sender)))
        (begin
            (asserts! (> voter-balance u0) err-insufficient-balance)
            (asserts! (not (default-to false (get has-voted (map-get? user-votes { voter: tx-sender })))) err-owner-only)
            (map-set user-votes { voter: tx-sender } { has-voted: true })
            (ok true)
        )
    )
)

;; Read only functions

;; Get token balance
(define-read-only (get-balance (account principal))
    (ft-get-balance sportsfan account)
)

;; Check if user has voted
(define-read-only (has-voted (account principal))
    (default-to false (get has-voted (map-get? user-votes { voter: account })))
)

;; Get ticket balance for a match
(define-read-only (get-match-tickets (match-id uint) (account principal))
    (default-to { amount: u0 } (map-get? match-tickets { match-id: match-id, holder: account }))
)
