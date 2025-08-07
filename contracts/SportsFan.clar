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


(define-map ticket-listings
    { listing-id: uint }
    { seller: principal, seat-number: uint, price: uint, active: bool })

(define-public (list-season-ticket (listing-id uint) (price uint))
    (let ((ticket (unwrap! (map-get? season-tickets {holder: tx-sender}) err-invalid-item)))
        (begin
            (asserts! (> (get valid-until ticket) stacks-block-height) err-invalid-item)
            (map-set ticket-listings
                { listing-id: listing-id }
                { seller: tx-sender, 
                  seat-number: (get seat-number ticket),
                  price: price,
                  active: true })
            (ok true)
        )
    )
)

(define-public (purchase-listed-ticket (listing-id uint))
    (let ((listing (unwrap! (map-get? ticket-listings {listing-id: listing-id}) err-invalid-item)))
        (begin
            (asserts! (get active listing) err-invalid-item)
            (try! (ft-transfer? sportsfan (get price listing) tx-sender (get seller listing)))
            (map-delete season-tickets {holder: (get seller listing)})
            (map-set season-tickets
                { holder: tx-sender }
                { valid-until: (+ stacks-block-height u52560),
                  seat-number: (get seat-number listing) })
            (map-set ticket-listings
                { listing-id: listing-id }
                (merge listing { active: false }))
            (ok true)
        )
    )
)


(define-map sponsor-tiers
    { tier-id: uint }
    { name: (string-ascii 20), required-stake: uint, reward-rate: uint })

(define-map active-sponsors
    { sponsor: principal }
    { tier-id: uint, staked-amount: uint, start-height: uint })

(define-public (initialize-sponsor-tiers)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set sponsor-tiers {tier-id: u1} 
            {name: "Bronze", required-stake: u1000, reward-rate: u10})
        (map-set sponsor-tiers {tier-id: u2}
            {name: "Silver", required-stake: u5000, reward-rate: u20})
        (map-set sponsor-tiers {tier-id: u3}
            {name: "Gold", required-stake: u10000, reward-rate: u40})
        (ok true)
    )
)

(define-public (become-sponsor (tier-id uint))
    (let ((tier (unwrap! (map-get? sponsor-tiers {tier-id: tier-id}) err-invalid-item)))
        (begin
            (try! (ft-transfer? sportsfan (get required-stake tier) tx-sender contract-owner))
            (map-set active-sponsors
                { sponsor: tx-sender }
                { tier-id: tier-id,
                  staked-amount: (get required-stake tier),
                  start-height: stacks-block-height })
            (ok true)
        )
    )
)


(define-public (withdraw-sponsorship)
    (let ((sponsor (unwrap! (map-get? active-sponsors {sponsor: tx-sender}) err-invalid-item)))
        (begin
            (try! (ft-transfer? sportsfan (get staked-amount sponsor) contract-owner tx-sender))
            (map-delete active-sponsors {sponsor: tx-sender})
            (ok true)
        )
    )
)
(define-public (get-sponsor-tier (sponsor principal))
    (let ((sponsor-data (unwrap! (map-get? active-sponsors {sponsor: sponsor}) err-invalid-item)))
        (ok (get tier-id sponsor-data))
    )
)


(define-map stake-pools
    { pool-id: uint }
    { duration-blocks: uint, reward-multiplier: uint, active: bool })

(define-map user-stakes
    { staker: principal, stake-id: uint }
    { amount: uint, pool-id: uint, start-height: uint, claimed: bool })

(define-map staker-counters
    { staker: principal }
    { next-stake-id: uint })

(define-constant err-invalid-pool (err u103))
(define-constant err-stake-not-found (err u104))
(define-constant err-stake-locked (err u105))
(define-constant err-already-claimed (err u106))

(define-public (create-stake-pool (pool-id uint) (duration-blocks uint) (reward-multiplier uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set stake-pools
            { pool-id: pool-id }
            { duration-blocks: duration-blocks, reward-multiplier: reward-multiplier, active: true })
        (ok true)
    )
)

(define-public (stake-tokens (pool-id uint) (amount uint))
    (let (
        (pool (unwrap! (map-get? stake-pools {pool-id: pool-id}) err-invalid-pool))
        (current-stake-id (default-to u0 (get next-stake-id (map-get? staker-counters {staker: tx-sender}))))
    )
    (begin
        (asserts! (get active pool) err-invalid-pool)
        (try! (ft-transfer? sportsfan amount tx-sender contract-owner))
        (map-set user-stakes
            { staker: tx-sender, stake-id: current-stake-id }
            { amount: amount, pool-id: pool-id, start-height: stacks-block-height, claimed: false })
        (map-set staker-counters
            { staker: tx-sender }
            { next-stake-id: (+ current-stake-id u1) })
        (ok current-stake-id)
    ))
)

(define-public (unstake-tokens (stake-id uint))
    (let (
        (stake (unwrap! (map-get? user-stakes {staker: tx-sender, stake-id: stake-id}) err-stake-not-found))
        (pool (unwrap! (map-get? stake-pools {pool-id: (get pool-id stake)}) err-invalid-pool))
        (unlock-height (+ (get start-height stake) (get duration-blocks pool)))
        (reward-amount (/ (* (get amount stake) (get reward-multiplier pool)) u100))
    )
    (begin
        (asserts! (>= stacks-block-height unlock-height) err-stake-locked)
        (asserts! (not (get claimed stake)) err-already-claimed)
        (try! (ft-transfer? sportsfan (get amount stake) contract-owner tx-sender))
        (try! (ft-mint? sportsfan reward-amount tx-sender))
        (map-set user-stakes
            { staker: tx-sender, stake-id: stake-id }
            (merge stake { claimed: true }))
        (ok (+ (get amount stake) reward-amount))
    ))
)

(define-read-only (get-stake-info (staker principal) (stake-id uint))
    (map-get? user-stakes {staker: staker, stake-id: stake-id})
)

(define-read-only (get-pool-info (pool-id uint))
    (map-get? stake-pools {pool-id: pool-id})
)

(define-read-only (calculate-stake-rewards (staker principal) (stake-id uint))
    (let (
        (stake (unwrap! (map-get? user-stakes {staker: staker, stake-id: stake-id}) (err u0)))
        (pool (unwrap! (map-get? stake-pools {pool-id: (get pool-id stake)}) (err u0)))
    )
    (ok (/ (* (get amount stake) (get reward-multiplier pool)) u100)))
)

(define-read-only (is-stake-unlocked (staker principal) (stake-id uint))
    (let (
        (stake (unwrap! (map-get? user-stakes {staker: staker, stake-id: stake-id}) (err u0)))
        (pool (unwrap! (map-get? stake-pools {pool-id: (get pool-id stake)}) (err u0)))
        (unlock-height (+ (get start-height stake) (get duration-blocks pool)))
    )
    (ok (>= stacks-block-height unlock-height)))
)

(define-constant err-auction-not-found (err u107))
(define-constant err-auction-ended (err u108))
(define-constant err-auction-active (err u109))
(define-constant err-not-auction-owner (err u110))
(define-constant err-bid-too-low (err u111))
(define-constant err-self-bid (err u112))
(define-constant err-no-bids (err u113))

(define-map auctions
    { auction-id: uint }
    { owner: principal, 
      item: (string-ascii 100),
      description: (string-ascii 200),
      starting-price: uint,
      current-bid: uint,
      highest-bidder: (optional principal),
      end-height: uint,
      active: bool,
      reserve-met: bool })

(define-map auction-bids
    { auction-id: uint, bidder: principal }
    { amount: uint, timestamp: uint })

(define-map auction-counters
    { counter-key: (string-ascii 10) }
    { value: uint })

(define-public (initialize-auction-system)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set auction-counters {counter-key: "next-id"} {value: u1})
        (ok true)
    )
)

(define-public (create-auction (item (string-ascii 100)) (description (string-ascii 200)) 
    (starting-price uint) (reserve-price uint) (duration-blocks uint))
    (let (
        (auction-id (default-to u1 (get value (map-get? auction-counters {counter-key: "next-id"}))))
        (end-height (+ stacks-block-height duration-blocks))
    )
    (begin
        (asserts! (>= (ft-get-balance sportsfan tx-sender) u100) err-insufficient-balance)
        (try! (ft-burn? sportsfan u100 tx-sender))
        (map-set auctions
            { auction-id: auction-id }
            { owner: tx-sender,
              item: item,
              description: description,
              starting-price: starting-price,
              current-bid: starting-price,
              highest-bidder: none,
              end-height: end-height,
              active: true,
              reserve-met: (>= starting-price reserve-price) })
        (map-set auction-counters 
            {counter-key: "next-id"} 
            {value: (+ auction-id u1)})
        (ok auction-id)
    ))
)

(define-public (place-bid (auction-id uint) (bid-amount uint))
    (let (
        (auction (unwrap! (map-get? auctions {auction-id: auction-id}) err-auction-not-found))
        (current-bidder (get highest-bidder auction))
        (current-bid (get current-bid auction))
        (refund-amount (if (is-some current-bidder) current-bid u0))
    )
    (begin
        (asserts! (get active auction) err-auction-ended)
        (asserts! (< stacks-block-height (get end-height auction)) err-auction-ended)
        (asserts! (not (is-eq tx-sender (get owner auction))) err-self-bid)
        (asserts! (> bid-amount current-bid) err-bid-too-low)
        (try! (ft-transfer? sportsfan bid-amount tx-sender contract-owner))
        (if (is-some current-bidder)
            (try! (ft-transfer? sportsfan refund-amount contract-owner (unwrap-panic current-bidder)))
            true)
        (map-set auction-bids
            { auction-id: auction-id, bidder: tx-sender }
            { amount: bid-amount, timestamp: stacks-block-height })
        (map-set auctions
            { auction-id: auction-id }
            (merge auction { current-bid: bid-amount, highest-bidder: (some tx-sender) }))
        (ok true)
    ))
)

(define-public (end-auction (auction-id uint))
    (let (
        (auction (unwrap! (map-get? auctions {auction-id: auction-id}) err-auction-not-found))
        (winner (get highest-bidder auction))
        (winning-bid (get current-bid auction))
        (owner (get owner auction))
    )
    (begin
        (asserts! (get active auction) err-auction-ended)
        (asserts! (>= stacks-block-height (get end-height auction)) err-auction-active)
        (if (is-some winner)
            (try! (ft-transfer? sportsfan winning-bid contract-owner owner))
            true)
        (map-set auctions
            { auction-id: auction-id }
            (merge auction { active: false }))
        (ok (is-some winner))
    ))
)

(define-public (cancel-auction (auction-id uint))
    (let (
        (auction (unwrap! (map-get? auctions {auction-id: auction-id}) err-auction-not-found))
        (current-bidder (get highest-bidder auction))
        (current-bid (get current-bid auction))
    )
    (begin
        (asserts! (is-eq tx-sender (get owner auction)) err-not-auction-owner)
        (asserts! (get active auction) err-auction-ended)
        (asserts! (< stacks-block-height (get end-height auction)) err-auction-ended)
        (if (is-some current-bidder)
            (try! (ft-transfer? sportsfan current-bid contract-owner (unwrap-panic current-bidder)))
            true)
        (map-set auctions
            { auction-id: auction-id }
            (merge auction { active: false }))
        (ok true)
    ))
)

(define-public (extend-auction (auction-id uint) (additional-blocks uint))
    (let (
        (auction (unwrap! (map-get? auctions {auction-id: auction-id}) err-auction-not-found))
        (new-end-height (+ (get end-height auction) additional-blocks))
    )
    (begin
        (asserts! (is-eq tx-sender (get owner auction)) err-not-auction-owner)
        (asserts! (get active auction) err-auction-ended)
        (asserts! (< stacks-block-height (get end-height auction)) err-auction-ended)
        (try! (ft-burn? sportsfan u50 tx-sender))
        (map-set auctions
            { auction-id: auction-id }
            (merge auction { end-height: new-end-height }))
        (ok true)
    ))
)

(define-read-only (get-auction-info (auction-id uint))
    (map-get? auctions {auction-id: auction-id})
)

(define-read-only (get-user-bid (auction-id uint) (bidder principal))
    (map-get? auction-bids {auction-id: auction-id, bidder: bidder})
)

(define-read-only (get-auction-time-left (auction-id uint))
    (let (
        (auction (unwrap! (map-get? auctions {auction-id: auction-id}) (err u0)))
        (end-height (get end-height auction))
    )
    (ok (if (> end-height stacks-block-height) (- end-height stacks-block-height) u0)))
)

(define-read-only (is-auction-winner (auction-id uint) (user principal))
    (let (
        (auction (unwrap! (map-get? auctions {auction-id: auction-id}) (err u0)))
        (winner (get highest-bidder auction))
    )
    (ok (is-eq (some user) winner)))
)

(define-read-only (get-active-auctions-count)
    (let (
        (total-auctions (default-to u1 (get value (map-get? auction-counters {counter-key: "next-id"}))))
    )
    (ok (- total-auctions u1)))
)

;; Fan Challenge System - Community-driven engagement challenges
(define-constant err-challenge-not-found (err u114))
(define-constant err-challenge-expired (err u115))
(define-constant err-already-participating (err u116))
(define-constant err-not-participating (err u117))
(define-constant err-invalid-progress (err u118))
(define-constant err-challenge-not-completed (err u119))
(define-constant err-reward-already-claimed (err u120))

;; Challenge definitions and metadata
(define-map challenges
    { challenge-id: uint }
    { creator: principal,
      title: (string-ascii 80),
      description: (string-ascii 200),
      challenge-type: uint, ;; 1=attendance, 2=prediction, 3=social, 4=spending, 5=custom
      target-value: uint,
      reward-amount: uint,
      duration-blocks: uint,
      created-at: uint,
      active: bool,
      participants-count: uint })

;; Individual participant progress tracking
(define-map challenge-participants
    { challenge-id: uint, participant: principal }
    { joined-at: uint,
      current-progress: uint,
      completed: bool,
      reward-claimed: bool,
      last-updated: uint })

;; Challenge activity log for verification
(define-map challenge-activities
    { challenge-id: uint, participant: principal, activity-id: uint }
    { activity-type: uint,
      value: uint,
      timestamp: uint,
      verified: bool })

;; Global challenge counter
(define-map challenge-counters
    { key: (string-ascii 15) }
    { value: uint })

;; Challenge categories and their validation requirements
(define-map challenge-types
    { type-id: uint }
    { name: (string-ascii 30),
      min-target: uint,
      max-target: uint,
      base-cost: uint })

;; Initialize the challenge system with predefined types
(define-public (initialize-challenge-system)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        ;; Set up challenge types
        (map-set challenge-types {type-id: u1} 
            {name: "Event Attendance", min-target: u1, max-target: u50, base-cost: u200})
        (map-set challenge-types {type-id: u2}
            {name: "Prediction Accuracy", min-target: u1, max-target: u20, base-cost: u150})
        (map-set challenge-types {type-id: u3}
            {name: "Social Engagement", min-target: u5, max-target: u100, base-cost: u100})
        (map-set challenge-types {type-id: u4}
            {name: "Token Spending", min-target: u50, max-target: u5000, base-cost: u300})
        (map-set challenge-types {type-id: u5}
            {name: "Custom Activity", min-target: u1, max-target: u1000, base-cost: u250})
        ;; Initialize counters
        (map-set challenge-counters {key: "next-challenge"} {value: u1})
        (map-set challenge-counters {key: "total-active"} {value: u0})
        (ok true)
    )
)

;; Create a new community challenge
(define-public (create-challenge (title (string-ascii 80)) (description (string-ascii 200))
    (challenge-type uint) (target-value uint) (reward-amount uint) (duration-blocks uint))
    (let (
        (challenge-id (default-to u1 (get value (map-get? challenge-counters {key: "next-challenge"}))))
        (type-info (unwrap! (map-get? challenge-types {type-id: challenge-type}) err-invalid-item))
        (creation-cost (get base-cost type-info))
    )
    (begin
        ;; Validate challenge parameters
        (asserts! (>= target-value (get min-target type-info)) err-invalid-progress)
        (asserts! (<= target-value (get max-target type-info)) err-invalid-progress)
        (asserts! (>= duration-blocks u144) err-invalid-progress) ;; Minimum 1 day
        (asserts! (<= duration-blocks u525600) err-invalid-progress) ;; Maximum 1 year
        
        ;; Charge creation fee and lock reward tokens
        (try! (ft-burn? sportsfan creation-cost tx-sender))
        (try! (ft-transfer? sportsfan reward-amount tx-sender contract-owner))
        
        ;; Create the challenge
        (map-set challenges
            { challenge-id: challenge-id }
            { creator: tx-sender,
              title: title,
              description: description,
              challenge-type: challenge-type,
              target-value: target-value,
              reward-amount: reward-amount,
              duration-blocks: duration-blocks,
              created-at: stacks-block-height,
              active: true,
              participants-count: u0 })
        
        ;; Update counters
        (map-set challenge-counters {key: "next-challenge"} {value: (+ challenge-id u1)})
        (map-set challenge-counters {key: "total-active"} 
            {value: (+ (default-to u0 (get value (map-get? challenge-counters {key: "total-active"}))) u1)})
        
        (ok challenge-id)
    ))
)

;; Join an active challenge
(define-public (join-challenge (challenge-id uint))
    (let (
        (challenge (unwrap! (map-get? challenges {challenge-id: challenge-id}) err-challenge-not-found))
        (expiry-height (+ (get created-at challenge) (get duration-blocks challenge)))
    )
    (begin
        ;; Validate challenge is active and not expired
        (asserts! (get active challenge) err-challenge-expired)
        (asserts! (< stacks-block-height expiry-height) err-challenge-expired)
        (asserts! (is-none (map-get? challenge-participants {challenge-id: challenge-id, participant: tx-sender})) 
            err-already-participating)
        
        ;; Require minimum token balance to participate
        (asserts! (>= (ft-get-balance sportsfan tx-sender) u10) err-insufficient-balance)
        
        ;; Add participant
        (map-set challenge-participants
            { challenge-id: challenge-id, participant: tx-sender }
            { joined-at: stacks-block-height,
              current-progress: u0,
              completed: false,
              reward-claimed: false,
              last-updated: stacks-block-height })
        
        ;; Update participant count
        (map-set challenges
            { challenge-id: challenge-id }
            (merge challenge { participants-count: (+ (get participants-count challenge) u1) }))
        
        (ok true)
    ))
)

;; Update progress on a challenge (can be called by participant or contract functions)
(define-public (update-challenge-progress (challenge-id uint) (participant principal) (progress-increment uint))
    (let (
        (challenge (unwrap! (map-get? challenges {challenge-id: challenge-id}) err-challenge-not-found))
        (participant-data (unwrap! (map-get? challenge-participants {challenge-id: challenge-id, participant: participant}) 
            err-not-participating))
        (new-progress (+ (get current-progress participant-data) progress-increment))
        (is-completed (>= new-progress (get target-value challenge)))
        (expiry-height (+ (get created-at challenge) (get duration-blocks challenge)))
    )
    (begin
        ;; Validate challenge is still active
        (asserts! (get active challenge) err-challenge-expired)
        (asserts! (< stacks-block-height expiry-height) err-challenge-expired)
        (asserts! (not (get completed participant-data)) err-reward-already-claimed)
        
        ;; Allow self-updates or contract owner updates
        (asserts! (or (is-eq tx-sender participant) (is-eq tx-sender contract-owner)) err-not-participating)
        
        ;; Update participant progress
        (map-set challenge-participants
            { challenge-id: challenge-id, participant: participant }
            (merge participant-data { 
                current-progress: new-progress,
                completed: is-completed,
                last-updated: stacks-block-height }))
        
        ;; Log the activity for verification
        (map-set challenge-activities
            { challenge-id: challenge-id, participant: participant, activity-id: stacks-block-height }
            { activity-type: (get challenge-type challenge),
              value: progress-increment,
              timestamp: stacks-block-height,
              verified: (is-eq tx-sender contract-owner) })
        
        (ok is-completed)
    ))
)

;; Claim reward for completed challenge
(define-public (claim-challenge-reward (challenge-id uint))
    (let (
        (challenge (unwrap! (map-get? challenges {challenge-id: challenge-id}) err-challenge-not-found))
        (participant-data (unwrap! (map-get? challenge-participants {challenge-id: challenge-id, participant: tx-sender}) 
            err-not-participating))
        (reward-per-participant (/ (get reward-amount challenge) 
            (if (> (get participants-count challenge) u0) (get participants-count challenge) u1)))
    )
    (begin
        ;; Validate completion and reward status
        (asserts! (get completed participant-data) err-challenge-not-completed)
        (asserts! (not (get reward-claimed participant-data)) err-reward-already-claimed)
        
        ;; Transfer reward from contract to participant
        (try! (ft-transfer? sportsfan reward-per-participant contract-owner tx-sender))
        
        ;; Mark reward as claimed
        (map-set challenge-participants
            { challenge-id: challenge-id, participant: tx-sender }
            (merge participant-data { reward-claimed: true }))
        
        (ok reward-per-participant)
    ))
)

;; End a challenge early (creator only)
(define-public (end-challenge (challenge-id uint))
    (let (
        (challenge (unwrap! (map-get? challenges {challenge-id: challenge-id}) err-challenge-not-found))
    )
    (begin
        (asserts! (is-eq tx-sender (get creator challenge)) err-not-auction-owner)
        (asserts! (get active challenge) err-challenge-expired)
        
        ;; Mark challenge as inactive
        (map-set challenges
            { challenge-id: challenge-id }
            (merge challenge { active: false }))
        
        ;; Update active counter
        (map-set challenge-counters {key: "total-active"} 
            {value: (- (default-to u0 (get value (map-get? challenge-counters {key: "total-active"}))) u1)})
        
        (ok true)
    ))
)

;; Read-only functions for challenge system
(define-read-only (get-challenge-info (challenge-id uint))
    (map-get? challenges {challenge-id: challenge-id})
)

(define-read-only (get-participant-progress (challenge-id uint) (participant principal))
    (map-get? challenge-participants {challenge-id: challenge-id, participant: participant})
)

(define-read-only (get-challenge-leaderboard (challenge-id uint) (participant principal))
    (let (
        (participant-data (map-get? challenge-participants {challenge-id: challenge-id, participant: participant}))
    )
    (match participant-data
        some-data (ok (get current-progress some-data))
        (ok u0)))
)

(define-read-only (is-challenge-active (challenge-id uint))
    (let (
        (challenge (unwrap! (map-get? challenges {challenge-id: challenge-id}) (err u0)))
        (expiry-height (+ (get created-at challenge) (get duration-blocks challenge)))
    )
    (ok (and (get active challenge) (< stacks-block-height expiry-height))))
)

(define-read-only (get-challenge-time-remaining (challenge-id uint))
    (let (
        (challenge (unwrap! (map-get? challenges {challenge-id: challenge-id}) (err u0)))
        (expiry-height (+ (get created-at challenge) (get duration-blocks challenge)))
    )
    (ok (if (> expiry-height stacks-block-height) (- expiry-height stacks-block-height) u0)))
)

(define-read-only (get-total-challenges)
    (let (
        (total (default-to u1 (get value (map-get? challenge-counters {key: "next-challenge"}))))
    )
    (ok (- total u1)))
)

(define-read-only (get-active-challenges-count)
    (ok (default-to u0 (get value (map-get? challenge-counters {key: "total-active"}))))
)

