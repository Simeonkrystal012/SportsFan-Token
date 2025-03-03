;; SportsFan Token
;; A fungible token for sports team membership and voting rights

;; Define the fungible token
(define-fungible-token sportsfan)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-item (err u102))

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


;; Add to data maps
(define-map fan-points { user: principal } { points: uint })

;; Add public function
(define-public (award-fan-points (user principal) (points uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set fan-points { user: user } { points: points })
        (ok true)
    )
)


;; Add to constants
(define-constant merchandise-prices (list 
    {item: "jersey", price: u50}
    {item: "scarf", price: u20}
))

(define-public (buy-merchandise (item-id uint))
    (let ((price (unwrap! (element-at merchandise-prices item-id) err-invalid-item)))
        (try! (ft-burn? sportsfan (get price price) tx-sender))
        (ok true)
    )
)


;; Add to data maps
(define-map vip-status { holder: principal } { is-vip: bool })

(define-public (upgrade-to-vip)
    (let ((vip-cost u100))
        (begin
            (try! (ft-burn? sportsfan vip-cost tx-sender))
            (map-set vip-status { holder: tx-sender } { is-vip: true })
            (ok true)
        )
    )
)


;; Add to data maps
(define-map match-predictions 
    { match-id: uint, predictor: principal } 
    { prediction: uint, staked-amount: uint })

(define-public (make-prediction (match-id uint) (prediction uint) (stake-amount uint))
    (begin
        (try! (ft-burn? sportsfan stake-amount tx-sender))
        (map-set match-predictions 
            { match-id: match-id, predictor: tx-sender }
            { prediction: prediction, staked-amount: stake-amount }
        )
        (ok true)
    )
)


;; Add to data maps
(define-map fan-tiers { fan: principal } { tier: uint })

(define-public (upgrade-fan-tier)
    (let ((current-balance (ft-get-balance sportsfan tx-sender)))
        (begin
            (map-set fan-tiers { fan: tx-sender }
                { tier: (if (>= current-balance u1000) u3
                    (if (>= current-balance u500) u2 u1)) })
            (ok true)
        )
    )
)


;; Add to data maps
(define-map team-polls 
    { poll-id: uint } 
    { question: (string-ascii 50), options: (list 4 uint), active: bool })

(define-public (create-team-poll (poll-id uint) (question (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set team-polls 
            { poll-id: poll-id }
            { question: question, options: (list u0 u0 u0 u0), active: true }
        )
        (ok true)
    )
)


;; Add to data maps
(define-map season-tickets 
    { holder: principal } 
    { valid-until: uint, seat-number: uint })

(define-public (purchase-season-ticket (seat-number uint))
    (let ((season-price u500))
        (begin
            (try! (ft-burn? sportsfan season-price tx-sender))
            (map-set season-tickets 
                { holder: tx-sender }
                { valid-until: (+ stacks-block-height u52560), seat-number: seat-number }
            )
            (ok true)
        )
    )
)


;; Add to data maps
(define-map fan-messages
    { message-id: uint }
    { author: principal, content: (string-ascii 280), timestamp: uint })

(define-public (post-message (message-id uint) (content (string-ascii 280)))
    (let ((min-tokens u10))
        (begin
            (asserts! (>= (ft-get-balance sportsfan tx-sender) min-tokens) err-insufficient-balance)
            (map-set fan-messages
                { message-id: message-id }
                { author: tx-sender, content: content, timestamp: stacks-block-height }
            )
            (ok true)
        )
    )
)
