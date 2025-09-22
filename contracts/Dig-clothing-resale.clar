;; title: Dig-clothing-resale
;; version: 1.0.0
;; summary: Digital Clothing Resale Market for NFT wearables across metaverse platforms
;; description: A decentralized marketplace for trading NFT wearables with platform verification and escrow

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-INVALID-PRICE (err u103))
(define-constant ERR-LISTING-EXPIRED (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-ALREADY-LISTED (err u106))
(define-constant ERR-INVALID-PLATFORM (err u107))
(define-constant ERR-TRADE-LOCKED (err u108))
(define-constant ERR-INVALID-CONDITION (err u109))
(define-constant ERR-DISCOUNT-EXISTS (err u110))
(define-constant ERR-INVALID-DISCOUNT (err u111))
(define-constant ERR-AUCTION-NOT-FOUND (err u112))
(define-constant ERR-AUCTION-ENDED (err u113))
(define-constant ERR-BID-TOO-LOW (err u114))
(define-constant ERR-CANNOT-BID-OWN-AUCTION (err u115))
(define-constant ERR-AUCTION-ACTIVE (err u116))

(define-data-var next-listing-id uint u1)
(define-data-var platform-fee uint u250)
(define-data-var contract-paused bool false)
(define-data-var trade-lock-duration uint u144)
(define-data-var next-auction-id uint u1)
(define-data-var min-bid-increment uint u1000000)

(define-map clothing-listings
  { listing-id: uint }
  {
    seller: principal,
    nft-contract: principal,
    token-id: uint,
    price: uint,
    platform: (string-ascii 32),
    condition: (string-ascii 16),
    size: (string-ascii 8),
    brand: (string-ascii 32),
    category: (string-ascii 32),
    expiry-block: uint,
    active: bool,
    created-at: uint
  })

(define-map verified-platforms
  { platform: (string-ascii 32) }
  { verified: bool, fee-rate: uint })

(define-map user-profiles
  { user: principal }
  {
    username: (string-ascii 32),
    reputation: uint,
    total-sales: uint,
    total-purchases: uint,
    created-at: uint
  })

(define-map trade-history
  { trade-id: uint }
  {
    listing-id: uint,
    seller: principal,
    buyer: principal,
    price: uint,
    platform: (string-ascii 32),
    timestamp: uint
  })

(define-map platform-stats
  { platform: (string-ascii 32) }
  { total-volume: uint, total-trades: uint })

(define-data-var next-trade-id uint u1)

(define-map discount-campaigns
  { listing-id: uint }
  {
    discount-type: (string-ascii 16),
    discount-rate: uint,
    min-blocks-old: uint,
    expires-at: uint,
    max-uses: uint,
    used-count: uint,
    active: bool
  })

(define-map bulk-discount-tiers
  { tier: uint }
  { min-items: uint, discount-rate: uint })

(define-map user-discount-usage
  { user: principal, listing-id: uint }
  { used: bool, timestamp: uint })

(define-map auctions
  { auction-id: uint }
  {
    seller: principal,
    listing-id: uint,
    starting-price: uint,
    current-bid: uint,
    highest-bidder: (optional principal),
    end-block: uint,
    active: bool,
    created-at: uint
  })

(define-map auction-bids
  { auction-id: uint, bidder: principal }
  { bid-amount: uint, timestamp: uint })

(define-public (initialize-platform (platform (string-ascii 32)) (fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= fee-rate u1000) ERR-INVALID-PRICE)
    (map-set verified-platforms { platform: platform } { verified: true, fee-rate: fee-rate })
    (map-set platform-stats { platform: platform } { total-volume: u0, total-trades: u0 })
    (map-set bulk-discount-tiers { tier: u1 } { min-items: u3, discount-rate: u500 })
    (map-set bulk-discount-tiers { tier: u2 } { min-items: u5, discount-rate: u1000 })
    (map-set bulk-discount-tiers { tier: u3 } { min-items: u10, discount-rate: u1500 })
    (ok true)))

(define-public (create-profile (username (string-ascii 32)))
  (begin
    (asserts! (not (var-get contract-paused)) ERR-TRADE-LOCKED)
    (map-set user-profiles 
      { user: tx-sender }
      {
        username: username,
        reputation: u100,
        total-sales: u0,
        total-purchases: u0,
        created-at: stacks-block-height
      })
    (ok true)))

(define-public (list-clothing 
  (nft-contract principal)
  (token-id uint)
  (price uint)
  (platform (string-ascii 32))
  (condition (string-ascii 16))
  (size (string-ascii 8))
  (brand (string-ascii 32))
  (category (string-ascii 32))
  (duration uint))
  (let ((listing-id (var-get next-listing-id)))
    (begin
      (asserts! (not (var-get contract-paused)) ERR-TRADE-LOCKED)
      (asserts! (> price u0) ERR-INVALID-PRICE)
      (asserts! (> duration u0) ERR-LISTING-EXPIRED)
      (asserts! (is-verified-platform platform) ERR-INVALID-PLATFORM)
      (asserts! (is-none (map-get? clothing-listings { listing-id: listing-id })) ERR-ALREADY-LISTED)
      
      (map-set clothing-listings
        { listing-id: listing-id }
        {
          seller: tx-sender,
          nft-contract: nft-contract,
          token-id: token-id,
          price: price,
          platform: platform,
          condition: condition,
          size: size,
          brand: brand,
          category: category,
          expiry-block: (+ stacks-block-height duration),
          active: true,
          created-at: stacks-block-height
        })
      
      (var-set next-listing-id (+ listing-id u1))
      (ok listing-id))))

(define-public (create-discount-campaign 
  (listing-id uint)
  (discount-type (string-ascii 16))
  (discount-rate uint)
  (min-blocks-old uint)
  (duration uint)
  (max-uses uint))
  (let ((listing (unwrap! (map-get? clothing-listings { listing-id: listing-id }) ERR-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get seller listing)) ERR-UNAUTHORIZED)
      (asserts! (get active listing) ERR-NOT-FOUND)
      (asserts! (<= discount-rate u5000) ERR-INVALID-DISCOUNT)
      (asserts! (> duration u0) ERR-INVALID-DISCOUNT)
      (asserts! (is-none (map-get? discount-campaigns { listing-id: listing-id })) ERR-DISCOUNT-EXISTS)
      
      (map-set discount-campaigns
        { listing-id: listing-id }
        {
          discount-type: discount-type,
          discount-rate: discount-rate,
          min-blocks-old: min-blocks-old,
          expires-at: (+ stacks-block-height duration),
          max-uses: max-uses,
          used-count: u0,
          active: true
        })
      (ok true))))

(define-public (purchase-with-discount (listing-id uint))
  (let ((listing (unwrap! (map-get? clothing-listings { listing-id: listing-id }) ERR-NOT-FOUND))
        (discount-data (map-get? discount-campaigns { listing-id: listing-id })))
    (begin
      (asserts! (not (var-get contract-paused)) ERR-TRADE-LOCKED)
      (asserts! (get active listing) ERR-NOT-FOUND)
      (asserts! (< stacks-block-height (get expiry-block listing)) ERR-LISTING-EXPIRED)
      (asserts! (not (is-eq tx-sender (get seller listing))) ERR-UNAUTHORIZED)
      
      (let ((final-price (if (is-some discount-data)
                           (get-discounted-price listing-id (get price listing) discount-data)
                           (get price listing)))
            (platform-data (unwrap! (map-get? verified-platforms { platform: (get platform listing) }) ERR-INVALID-PLATFORM))
            (fee-amount (/ (* final-price (get fee-rate platform-data)) u10000))
            (seller-amount (- final-price fee-amount))
            (trade-id (var-get next-trade-id)))
        
        (if (is-some discount-data)
          (begin
            (asserts! (is-discount-valid listing-id (unwrap-panic discount-data)) ERR-INVALID-DISCOUNT)
            (update-discount-usage listing-id))
          true)
        
        (try! (stx-transfer? final-price tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller listing))))
        (try! (as-contract (stx-transfer? fee-amount tx-sender CONTRACT-OWNER)))
        
        (map-set clothing-listings
          { listing-id: listing-id }
          (merge listing { active: false }))
        
        (map-set trade-history
          { trade-id: trade-id }
          {
            listing-id: listing-id,
            seller: (get seller listing),
            buyer: tx-sender,
            price: final-price,
            platform: (get platform listing),
            timestamp: stacks-block-height
          })
        
        (update-user-stats (get seller listing) true final-price)
        (update-user-stats tx-sender false final-price)
        (update-platform-stats (get platform listing) final-price)
        
        (var-set next-trade-id (+ trade-id u1))
        (ok trade-id)))))

(define-public (calculate-bulk-discount (item-count uint))
  (begin
    (if (>= item-count u10)
      (ok u1500)
      (if (>= item-count u5)
        (ok u1000)
        (if (>= item-count u3)
          (ok u500)
          (ok u0))))))

(define-public (deactivate-discount-campaign (listing-id uint))
  (let ((listing (unwrap! (map-get? clothing-listings { listing-id: listing-id }) ERR-NOT-FOUND))
        (discount-data (unwrap! (map-get? discount-campaigns { listing-id: listing-id }) ERR-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get seller listing)) ERR-UNAUTHORIZED)
      (map-set discount-campaigns
        { listing-id: listing-id }
        (merge discount-data { active: false }))
      (ok true))))

(define-public (create-auction
  (listing-id uint)
  (starting-price uint)
  (duration uint))
  (let ((listing (unwrap! (map-get? clothing-listings { listing-id: listing-id }) ERR-NOT-FOUND))
        (auction-id (var-get next-auction-id)))
    (begin
      (asserts! (not (var-get contract-paused)) ERR-TRADE-LOCKED)
      (asserts! (is-eq tx-sender (get seller listing)) ERR-UNAUTHORIZED)
      (asserts! (get active listing) ERR-NOT-FOUND)
      (asserts! (> starting-price u0) ERR-INVALID-PRICE)
      (asserts! (> duration u0) ERR-AUCTION-ENDED)
      
      (map-set auctions
        { auction-id: auction-id }
        {
          seller: tx-sender,
          listing-id: listing-id,
          starting-price: starting-price,
          current-bid: starting-price,
          highest-bidder: none,
          end-block: (+ stacks-block-height duration),
          active: true,
          created-at: stacks-block-height
        })
      
      (var-set next-auction-id (+ auction-id u1))
      (ok auction-id))))

(define-public (place-bid (auction-id uint) (bid-amount uint))
  (let ((auction (unwrap! (map-get? auctions { auction-id: auction-id }) ERR-AUCTION-NOT-FOUND)))
    (begin
      (asserts! (not (var-get contract-paused)) ERR-TRADE-LOCKED)
      (asserts! (get active auction) ERR-AUCTION-ENDED)
      (asserts! (< stacks-block-height (get end-block auction)) ERR-AUCTION-ENDED)
      (asserts! (not (is-eq tx-sender (get seller auction))) ERR-CANNOT-BID-OWN-AUCTION)
      (asserts! (>= bid-amount (+ (get current-bid auction) (var-get min-bid-increment))) ERR-BID-TOO-LOW)
      
      (let ((previous-bidder (get highest-bidder auction))
            (previous-bid (get current-bid auction)))
        
        (match previous-bidder
          prev-bidder (try! (as-contract (stx-transfer? previous-bid tx-sender prev-bidder)))
          true)
        
        (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
        
        (map-set auctions
          { auction-id: auction-id }
          (merge auction {
            current-bid: bid-amount,
            highest-bidder: (some tx-sender)
          }))
        
        (map-set auction-bids
          { auction-id: auction-id, bidder: tx-sender }
          {
            bid-amount: bid-amount,
            timestamp: stacks-block-height
          })
        
        (ok true)))))

(define-public (finalize-auction (auction-id uint))
  (let ((auction (unwrap! (map-get? auctions { auction-id: auction-id }) ERR-AUCTION-NOT-FOUND))
        (listing (unwrap! (map-get? clothing-listings { listing-id: (get listing-id auction) }) ERR-NOT-FOUND)))
    (begin
      (asserts! (get active auction) ERR-AUCTION-ENDED)
      (asserts! (>= stacks-block-height (get end-block auction)) ERR-AUCTION-ACTIVE)
      
      (match (get highest-bidder auction)
        winner
        (let ((final-price (get current-bid auction))
              (platform-data (unwrap! (map-get? verified-platforms { platform: (get platform listing) }) ERR-INVALID-PLATFORM))
              (fee-amount (/ (* final-price (get fee-rate platform-data)) u10000))
              (seller-amount (- final-price fee-amount))
              (trade-id (var-get next-trade-id)))
          
          (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller auction))))
          (try! (as-contract (stx-transfer? fee-amount tx-sender CONTRACT-OWNER)))
          
          (map-set auctions
            { auction-id: auction-id }
            (merge auction { active: false }))
          
          (map-set clothing-listings
            { listing-id: (get listing-id auction) }
            (merge listing { active: false }))
          
          (map-set trade-history
            { trade-id: trade-id }
            {
              listing-id: (get listing-id auction),
              seller: (get seller auction),
              buyer: winner,
              price: final-price,
              platform: (get platform listing),
              timestamp: stacks-block-height
            })
          
          (update-user-stats (get seller auction) true final-price)
          (update-user-stats winner false final-price)
          (update-platform-stats (get platform listing) final-price)
          
          (var-set next-trade-id (+ trade-id u1))
          (ok trade-id))
        
        (begin
          (map-set auctions
            { auction-id: auction-id }
            (merge auction { active: false }))
          (ok u0))))))

(define-public (cancel-auction (auction-id uint))
  (let ((auction (unwrap! (map-get? auctions { auction-id: auction-id }) ERR-AUCTION-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get seller auction)) ERR-UNAUTHORIZED)
      (asserts! (get active auction) ERR-AUCTION-ENDED)
      (asserts! (is-none (get highest-bidder auction)) ERR-AUCTION-ACTIVE)
      
      (map-set auctions
        { auction-id: auction-id }
        (merge auction { active: false }))
      (ok true))))

(define-public (purchase-clothing (listing-id uint))
  (let ((listing (unwrap! (map-get? clothing-listings { listing-id: listing-id }) ERR-NOT-FOUND)))
    (begin
      (asserts! (not (var-get contract-paused)) ERR-TRADE-LOCKED)
      (asserts! (get active listing) ERR-NOT-FOUND)
      (asserts! (< stacks-block-height (get expiry-block listing)) ERR-LISTING-EXPIRED)
      (asserts! (not (is-eq tx-sender (get seller listing))) ERR-UNAUTHORIZED)
      
      (let ((platform-data (unwrap! (map-get? verified-platforms { platform: (get platform listing) }) ERR-INVALID-PLATFORM))
            (fee-amount (/ (* (get price listing) (get fee-rate platform-data)) u10000))
            (seller-amount (- (get price listing) fee-amount))
            (trade-id (var-get next-trade-id)))
        
        (try! (stx-transfer? (get price listing) tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller listing))))
        (try! (as-contract (stx-transfer? fee-amount tx-sender CONTRACT-OWNER)))
        
        (map-set clothing-listings
          { listing-id: listing-id }
          (merge listing { active: false }))
        
        (map-set trade-history
          { trade-id: trade-id }
          {
            listing-id: listing-id,
            seller: (get seller listing),
            buyer: tx-sender,
            price: (get price listing),
            platform: (get platform listing),
            timestamp: stacks-block-height
          })
        
        (update-user-stats (get seller listing) true (get price listing))
        (update-user-stats tx-sender false (get price listing))
        (update-platform-stats (get platform listing) (get price listing))
        
        (var-set next-trade-id (+ trade-id u1))
        (ok trade-id)))))

(define-public (cancel-listing (listing-id uint))
  (let ((listing (unwrap! (map-get? clothing-listings { listing-id: listing-id }) ERR-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get seller listing)) ERR-UNAUTHORIZED)
      (asserts! (get active listing) ERR-NOT-FOUND)
      
      (map-set clothing-listings
        { listing-id: listing-id }
        (merge listing { active: false }))
      (ok true))))

(define-public (update-listing-price (listing-id uint) (new-price uint))
  (let ((listing (unwrap! (map-get? clothing-listings { listing-id: listing-id }) ERR-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get seller listing)) ERR-UNAUTHORIZED)
      (asserts! (get active listing) ERR-NOT-FOUND)
      (asserts! (> new-price u0) ERR-INVALID-PRICE)
      
      (map-set clothing-listings
        { listing-id: listing-id }
        (merge listing { price: new-price }))
      (ok true))))

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= new-fee u1000) ERR-INVALID-PRICE)
    (var-set platform-fee new-fee)
    (ok true)))

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set contract-paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set contract-paused false)
    (ok true)))

(define-read-only (get-listing (listing-id uint))
  (map-get? clothing-listings { listing-id: listing-id }))

(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user }))

(define-read-only (get-trade-history (trade-id uint))
  (map-get? trade-history { trade-id: trade-id }))

(define-read-only (get-platform-stats (platform (string-ascii 32)))
  (map-get? platform-stats { platform: platform }))

(define-read-only (is-verified-platform (platform (string-ascii 32)))
  (match (map-get? verified-platforms { platform: platform })
    platform-data (get verified platform-data)
    false))

(define-read-only (get-contract-info)
  {
    next-listing-id: (var-get next-listing-id),
    platform-fee: (var-get platform-fee),
    contract-paused: (var-get contract-paused),
    trade-lock-duration: (var-get trade-lock-duration),
    next-auction-id: (var-get next-auction-id),
    min-bid-increment: (var-get min-bid-increment),
    owner: CONTRACT-OWNER
  })

(define-read-only (get-active-listings-count)
  (var-get next-listing-id))

(define-read-only (get-discount-campaign (listing-id uint))
  (map-get? discount-campaigns { listing-id: listing-id }))

(define-read-only (get-bulk-discount-tier (tier uint))
  (map-get? bulk-discount-tiers { tier: tier }))

(define-read-only (check-discount-eligibility (listing-id uint) (user principal))
  (let ((discount-data (map-get? discount-campaigns { listing-id: listing-id }))
        (usage-data (map-get? user-discount-usage { user: user, listing-id: listing-id })))
    (match discount-data
      campaign
      {
        has-campaign: true,
        is-active: (get active campaign),
        not-expired: (< stacks-block-height (get expires-at campaign)),
        under-usage-limit: (< (get used-count campaign) (get max-uses campaign)),
        user-not-used: (is-none usage-data)
      }
      { has-campaign: false, is-active: false, not-expired: false, under-usage-limit: false, user-not-used: false })))

(define-read-only (get-auction (auction-id uint))
  (map-get? auctions { auction-id: auction-id }))

(define-read-only (get-auction-bid (auction-id uint) (bidder principal))
  (map-get? auction-bids { auction-id: auction-id, bidder: bidder }))

(define-read-only (get-auction-status (auction-id uint))
  (match (map-get? auctions { auction-id: auction-id })
    auction
    {
      exists: true,
      active: (get active auction),
      ended: (>= stacks-block-height (get end-block auction)),
      time-remaining: (if (>= stacks-block-height (get end-block auction)) 
                       u0 
                       (- (get end-block auction) stacks-block-height)),
      current-bid: (get current-bid auction),
      has-bidder: (is-some (get highest-bidder auction))
    }
    { exists: false, active: false, ended: true, time-remaining: u0, current-bid: u0, has-bidder: false }))

(define-private (get-discounted-price (listing-id uint) (original-price uint) (discount-data (optional {discount-type: (string-ascii 16), discount-rate: uint, min-blocks-old: uint, expires-at: uint, max-uses: uint, used-count: uint, active: bool})))
  (match discount-data
    campaign
    (let ((listing (unwrap-panic (map-get? clothing-listings { listing-id: listing-id })))
          (age-in-blocks (- stacks-block-height (get created-at listing))))
      (if (and (get active campaign)
               (< stacks-block-height (get expires-at campaign))
               (>= age-in-blocks (get min-blocks-old campaign))
               (< (get used-count campaign) (get max-uses campaign)))
        (- original-price (/ (* original-price (get discount-rate campaign)) u10000))
        original-price))
    original-price))

(define-private (is-discount-valid (listing-id uint) (campaign {discount-type: (string-ascii 16), discount-rate: uint, min-blocks-old: uint, expires-at: uint, max-uses: uint, used-count: uint, active: bool}))
  (let ((listing (unwrap-panic (map-get? clothing-listings { listing-id: listing-id })))
        (age-in-blocks (- stacks-block-height (get created-at listing)))
        (usage-data (map-get? user-discount-usage { user: tx-sender, listing-id: listing-id })))
    (and (get active campaign)
         (< stacks-block-height (get expires-at campaign))
         (>= age-in-blocks (get min-blocks-old campaign))
         (< (get used-count campaign) (get max-uses campaign))
         (is-none usage-data))))

(define-private (update-discount-usage (listing-id uint))
  (let ((campaign (unwrap-panic (map-get? discount-campaigns { listing-id: listing-id }))))
    (map-set discount-campaigns
      { listing-id: listing-id }
      (merge campaign { used-count: (+ (get used-count campaign) u1) }))
    (map-set user-discount-usage
      { user: tx-sender, listing-id: listing-id }
      { used: true, timestamp: stacks-block-height })
    true))

(define-private (update-user-stats (user principal) (is-seller bool) (amount uint))
  (let ((profile (default-to 
    { username: "", reputation: u100, total-sales: u0, total-purchases: u0, created-at: stacks-block-height }
    (map-get? user-profiles { user: user }))))
    (if is-seller
      (map-set user-profiles 
        { user: user }
        (merge profile { 
          total-sales: (+ (get total-sales profile) u1),
          reputation: (+ (get reputation profile) u1)
        }))
      (map-set user-profiles 
        { user: user }
        (merge profile { 
          total-purchases: (+ (get total-purchases profile) u1),
          reputation: (+ (get reputation profile) u1)
        })))
    true))

(define-private (update-platform-stats (platform (string-ascii 32)) (amount uint))
  (let ((stats (default-to 
    { total-volume: u0, total-trades: u0 }
    (map-get? platform-stats { platform: platform }))))
    (map-set platform-stats 
      { platform: platform }
      { 
        total-volume: (+ (get total-volume stats) amount),
        total-trades: (+ (get total-trades stats) u1)
      })
    true))
