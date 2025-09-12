;; Fan Loyalty Program Contract
;; Tracks long-term fan engagement and rewards loyalty milestones

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u121))
(define-constant err-not-enrolled (err u122))
(define-constant err-already-enrolled (err u123))
(define-constant err-cooldown-active (err u124))
(define-constant err-insufficient-tenure (err u125))

;; Loyalty level thresholds (in blocks - approximately days * 144)
(define-constant bronze-threshold u1440)   ;; 10 days
(define-constant silver-threshold u7200)   ;; 50 days  
(define-constant gold-threshold u21600)    ;; 150 days
(define-constant platinum-threshold u43200) ;; 300 days

;; Reward amounts per loyalty level
(define-constant bronze-daily-reward u5)
(define-constant silver-daily-reward u12)
(define-constant gold-daily-reward u25)
(define-constant platinum-daily-reward u50)

;; Milestone bonus rewards
(define-constant milestone-30-days u100)
(define-constant milestone-100-days u300)
(define-constant milestone-365-days u1000)

;; Fan enrollment and loyalty tracking
(define-map loyalty-members
    { fan: principal }
    { enrolled-at: uint,
      loyalty-level: uint,
      total-activity-score: uint,
      last-reward-claim: uint,
      lifetime-rewards: uint,
      consecutive-days: uint,
      milestones-claimed: (list 10 uint) })

;; Activity tracking for loyalty scoring
(define-map daily-activity
    { fan: principal, day: uint }
    { activities: uint,
      tokens-spent: uint,
      engagement-score: uint })

;; Loyalty level multipliers for various activities
(define-map loyalty-multipliers
    { level: uint }
    { ticket-discount: uint,
      voting-weight: uint,
      reward-bonus: uint,
      event-priority: bool })

;; Initialize loyalty program with level multipliers
(define-public (initialize-loyalty-program)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        ;; Set up loyalty level multipliers
        (map-set loyalty-multipliers {level: u1} 
            {ticket-discount: u5, voting-weight: u100, reward-bonus: u110, event-priority: false})
        (map-set loyalty-multipliers {level: u2}
            {ticket-discount: u10, voting-weight: u120, reward-bonus: u125, event-priority: true})
        (map-set loyalty-multipliers {level: u3}
            {ticket-discount: u20, voting-weight: u150, reward-bonus: u150, event-priority: true})
        (map-set loyalty-multipliers {level: u4}
            {ticket-discount: u30, voting-weight: u200, reward-bonus: u200, event-priority: true})
        
        (ok true)
    )
)

;; Enroll a new fan in the loyalty program
(define-public (enroll-in-loyalty-program)
    (begin
        (asserts! (is-none (map-get? loyalty-members {fan: tx-sender})) err-already-enrolled)
        (asserts! (>= (contract-call? .SportsFan get-balance tx-sender) u50) (err u101))
        
        (map-set loyalty-members
            { fan: tx-sender }
            { enrolled-at: stacks-block-height,
              loyalty-level: u1,
              total-activity-score: u0,
              last-reward-claim: stacks-block-height,
              lifetime-rewards: u0,
              consecutive-days: u1,
              milestones-claimed: (list) })
        
        (ok true)
    )
)

;; Calculate current loyalty level based on tenure and activity
(define-public (update-loyalty-level (fan principal))
    (let (
        (member-data (unwrap! (map-get? loyalty-members {fan: fan}) err-not-enrolled))
        (tenure (- stacks-block-height (get enrolled-at member-data)))
        (activity-score (get total-activity-score member-data))
        (new-level (if (>= tenure platinum-threshold) u4
            (if (>= tenure gold-threshold) u3
                (if (>= tenure silver-threshold) u2 u1))))
    )
    (begin
        (map-set loyalty-members
            { fan: fan }
            (merge member-data { loyalty-level: new-level }))
        
        (ok new-level)
    ))
)

;; Record daily fan activity for loyalty scoring
(define-public (record-fan-activity (fan principal) (activity-type uint) (tokens-spent uint))
    (let (
        (current-day (/ stacks-block-height u144))
        (existing-activity (default-to {activities: u0, tokens-spent: u0, engagement-score: u0}
            (map-get? daily-activity {fan: fan, day: current-day})))
        (member-data (unwrap! (map-get? loyalty-members {fan: fan}) err-not-enrolled))
        (activity-points (if (is-eq activity-type u1) u5   ;; Event attendance
            (if (is-eq activity-type u2) u3   ;; Voting participation  
                (if (is-eq activity-type u3) u2   ;; Token spending
                    (if (is-eq activity-type u4) u4   ;; Social engagement
                        u1)))))    ;; Default
        (new-engagement-score (+ (get engagement-score existing-activity) activity-points))
    )
    (begin
        ;; Update daily activity
        (map-set daily-activity
            { fan: fan, day: current-day }
            { activities: (+ (get activities existing-activity) u1),
              tokens-spent: (+ (get tokens-spent existing-activity) tokens-spent),
              engagement-score: new-engagement-score })
        
        ;; Update member total activity score
        (map-set loyalty-members
            { fan: fan }
            (merge member-data { 
                total-activity-score: (+ (get total-activity-score member-data) activity-points) }))
        
        ;; Update loyalty level
        (try! (update-loyalty-level fan))
        (ok true)
    ))
)

;; Claim daily loyalty rewards
(define-public (claim-loyalty-rewards)
    (let (
        (member-data (unwrap! (map-get? loyalty-members {fan: tx-sender}) err-not-enrolled))
        (last-claim (get last-reward-claim member-data))
        (blocks-since-claim (- stacks-block-height last-claim))
        (loyalty-level (get loyalty-level member-data))
        (daily-reward (if (is-eq loyalty-level u1) bronze-daily-reward
            (if (is-eq loyalty-level u2) silver-daily-reward
                (if (is-eq loyalty-level u3) gold-daily-reward
                    (if (is-eq loyalty-level u4) platinum-daily-reward
                        bronze-daily-reward)))))
        (days-eligible (/ blocks-since-claim u144))
        (total-reward (* daily-reward days-eligible))
    )
    (begin
        (asserts! (>= blocks-since-claim u144) err-cooldown-active) ;; Must wait 1 day
        (asserts! (> days-eligible u0) err-cooldown-active)
        
        ;; Mint loyalty rewards
        (try! (contract-call? .SportsFan mint total-reward tx-sender))
        
        ;; Update member data
        (map-set loyalty-members
            { fan: tx-sender }
            (merge member-data { 
                last-reward-claim: stacks-block-height,
                lifetime-rewards: (+ (get lifetime-rewards member-data) total-reward) }))
        
        (ok total-reward)
    ))
)

;; Claim milestone rewards for tenure achievements
(define-public (claim-milestone-reward (milestone-days uint))
    (let (
        (member-data (unwrap! (map-get? loyalty-members {fan: tx-sender}) err-not-enrolled))
        (tenure (- stacks-block-height (get enrolled-at member-data)))
        (milestone-blocks (* milestone-days u144))
        (milestone-reward (if (is-eq milestone-days u30) milestone-30-days
            (if (is-eq milestone-days u100) milestone-100-days  
                (if (is-eq milestone-days u365) milestone-365-days
                    u0))))
        (claimed-milestones (get milestones-claimed member-data))
        (already-claimed (is-some (index-of claimed-milestones milestone-days)))
    )
    (begin
        (asserts! (>= tenure milestone-blocks) err-insufficient-tenure)
        (asserts! (> milestone-reward u0) err-owner-only)
        (asserts! (not already-claimed) err-already-enrolled)
        
        ;; Mint milestone reward
        (try! (contract-call? .SportsFan mint milestone-reward tx-sender))
        
        ;; Update claimed milestones list
        (map-set loyalty-members
            { fan: tx-sender }
            (merge member-data { 
                milestones-claimed: (unwrap! (as-max-len? (append claimed-milestones milestone-days) u10) err-owner-only),
                lifetime-rewards: (+ (get lifetime-rewards member-data) milestone-reward) }))
        
        (ok milestone-reward)
    ))
)

;; Get loyalty member information
(define-read-only (get-loyalty-info (fan principal))
    (map-get? loyalty-members {fan: fan})
)

;; Get loyalty level multipliers
(define-read-only (get-loyalty-multipliers (level uint))
    (map-get? loyalty-multipliers {level: level})
)

;; Check if milestone is available to claim
(define-read-only (get-available-milestones (fan principal))
    (let (
        (member-data (unwrap! (map-get? loyalty-members {fan: fan}) (err u0)))
        (tenure (- stacks-block-height (get enrolled-at member-data)))
        (claimed-milestones (get milestones-claimed member-data))
        (days-30-eligible (and (>= tenure u4320) (is-none (index-of claimed-milestones u30))))
        (days-100-eligible (and (>= tenure u14400) (is-none (index-of claimed-milestones u100))))
        (days-365-eligible (and (>= tenure u52560) (is-none (index-of claimed-milestones u365))))
    )
    (ok { milestone-30: days-30-eligible,
          milestone-100: days-100-eligible,
          milestone-365: days-365-eligible }))
)

;; Get fan's daily activity for a specific day
(define-read-only (get-daily-activity (fan principal) (day uint))
    (map-get? daily-activity {fan: fan, day: day})
)

;; Calculate loyalty discount for tickets/merchandise
(define-read-only (calculate-loyalty-discount (fan principal) (base-price uint))
    (let (
        (member-data (unwrap! (map-get? loyalty-members {fan: fan}) (err u0)))
        (loyalty-level (get loyalty-level member-data))
        (multipliers (unwrap! (map-get? loyalty-multipliers {level: loyalty-level}) (err u0)))
        (discount-percent (get ticket-discount multipliers))
        (discount-amount (/ (* base-price discount-percent) u100))
    )
    (ok (- base-price discount-amount)))
)