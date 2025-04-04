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



(define-constant reward-tiers (list 
    {tier: "bronze", threshold: u100, bonus: u5}
    {tier: "silver", threshold: u500, bonus: u10}
    {tier: "gold", threshold: u1000, bonus: u20}
))

(define-map user-rewards 
    { user: principal } 
    { total-rewards: uint, last-claim: uint })

(define-public (claim-rewards)
    (let (
        (user-balance (ft-get-balance sportsfan tx-sender))
        (last-claim-height (default-to u0 (get last-claim (map-get? user-rewards {user: tx-sender}))))
        (blocks-since-claim (- stacks-block-height last-claim-height))
        (reward-amount (if (>= user-balance u1000) u20
            (if (>= user-balance u500) u10 u5)))
    )
    (begin
        (asserts! (>= blocks-since-claim u144) err-insufficient-balance) ;; 1 day minimum
        (try! (ft-mint? sportsfan reward-amount tx-sender))
        (map-set user-rewards {user: tx-sender} 
            {total-rewards: reward-amount, last-claim: stacks-block-height})
        (ok true)
    ))
)


(define-map fan-clubs
    { club-id: uint }
    { name: (string-ascii 50), members: uint, fee: uint })

(define-map club-members
    { club-id: uint, member: principal }
    { joined-at: uint, active: bool })

(define-public (create-fan-club (club-id uint) (name (string-ascii 50)) (fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set fan-clubs
            { club-id: club-id }
            { name: name, members: u0, fee: fee })
        (ok true)
    )
)

(define-public (join-fan-club (club-id uint))
    (let ((club (unwrap! (map-get? fan-clubs {club-id: club-id}) err-invalid-item)))
        (begin
            (try! (ft-burn? sportsfan (get fee club) tx-sender))
            (map-set club-members
                { club-id: club-id, member: tx-sender }
                { joined-at: stacks-block-height, active: true })
            (ok true)
        )
    )
)


(define-map events
    { event-id: uint }
    { name: (string-ascii 50), date: uint, points: uint })

(define-map event-attendance
    { event-id: uint, attendee: principal }
    { checked-in: bool, timestamp: uint })

(define-public (create-event (event-id uint) (name (string-ascii 50)) (points uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set events
            { event-id: event-id }
            { name: name, date: stacks-block-height, points: points })
        (ok true)
    )
)

(define-public (check-in-event (event-id uint))
    (let ((event (unwrap! (map-get? events {event-id: event-id}) err-invalid-item)))
        (begin
            (map-set event-attendance
                { event-id: event-id, attendee: tx-sender }
                { checked-in: true, timestamp: stacks-block-height })
            (try! (award-fan-points tx-sender (get points event)))
            (ok true)
        )
    )
)

(define-map merchandise-listings
    { listing-id: uint }
    { seller: principal, item: (string-ascii 50), price: uint, available: bool })

(define-public (list-merchandise (listing-id uint) (item (string-ascii 50)) (price uint))
    (begin
        (map-set merchandise-listings
            { listing-id: listing-id }
            { seller: tx-sender, item: item, price: price, available: true })
        (ok true)
    )
)

(define-public (buy-listed-merchandise (listing-id uint))
    (let ((listing (unwrap! (map-get? merchandise-listings {listing-id: listing-id}) err-invalid-item)))
        (begin
            (asserts! (get available listing) err-invalid-item)
            (try! (ft-transfer? sportsfan (get price listing) tx-sender (get seller listing)))
            (map-set merchandise-listings
                { listing-id: listing-id }
                (merge listing { available: false }))
            (ok true)
        )
    )
)


(define-map achievements
    { achievement-id: uint }
    { name: (string-ascii 50), description: (string-ascii 100), points: uint })

(define-map user-achievements
    { user: principal, achievement-id: uint }
    { earned: bool, earned-at: uint })

(define-public (create-achievement (achievement-id uint) (name (string-ascii 50)) 
    (description (string-ascii 100)) (points uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set achievements
            { achievement-id: achievement-id }
            { name: name, description: description, points: points })
        (ok true)
    )
)

(define-public (award-achievement (user principal) (achievement-id uint))
    (let ((achievement (unwrap! (map-get? achievements {achievement-id: achievement-id}) err-invalid-item)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (map-set user-achievements
                { user: user, achievement-id: achievement-id }
                { earned: true, earned-at: stacks-block-height })
            (try! (award-fan-points user (get points achievement)))
            (ok true)
        )
    )
)


(define-map mascot-proposals
    { proposal-id: uint }
    { name: (string-ascii 50), description: (string-ascii 200), votes: uint })

(define-map mascot-votes
    { proposal-id: uint, voter: principal }
    { voted: bool })

(define-public (propose-mascot (proposal-id uint) (name (string-ascii 50)) 
    (description (string-ascii 200)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set mascot-proposals
            { proposal-id: proposal-id }
            { name: name, description: description, votes: u0 })
        (ok true)
    )
)

(define-public (vote-for-mascot (proposal-id uint))
    (let ((proposal (unwrap! (map-get? mascot-proposals {proposal-id: proposal-id}) err-invalid-item)))
        (begin
            (asserts! (not (default-to false 
                (get voted (map-get? mascot-votes {proposal-id: proposal-id, voter: tx-sender})))) 
                err-owner-only)
            (map-set mascot-votes
                { proposal-id: proposal-id, voter: tx-sender }
                { voted: true })
            (map-set mascot-proposals
                { proposal-id: proposal-id }
                (merge proposal { votes: (+ (get votes proposal) u1) }))
            (ok true)
        )
    )
)

;; Add to data maps
(define-map referrals
    { referrer: principal }
    { total-referrals: uint, rewards-earned: uint })

(define-map referred-users
    { user: principal }
    { referred-by: principal, referred-at: uint })

(define-constant referral-reward u50)

(define-public (refer-user (new-user principal))
    (begin
        (asserts! (is-none (map-get? referred-users {user: new-user})) err-invalid-item)
        (map-set referred-users
            { user: new-user }
            { referred-by: tx-sender, referred-at: stacks-block-height })
        (try! (ft-mint? sportsfan referral-reward tx-sender))
        (map-set referrals
            { referrer: tx-sender }
            { total-referrals: (+ (default-to u0 
                (get total-referrals (map-get? referrals {referrer: tx-sender}))) u1),
              rewards-earned: (+ (default-to u0 
                (get rewards-earned (map-get? referrals {referrer: tx-sender}))) 
                referral-reward) })
        (ok true)
    )
)