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

(define-data-var next-listing-id uint u1)
(define-data-var platform-fee uint u250)
(define-data-var contract-paused bool false)
(define-data-var trade-lock-duration uint u144)

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

(define-public (initialize-platform (platform (string-ascii 32)) (fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= fee-rate u1000) ERR-INVALID-PRICE)
    (map-set verified-platforms { platform: platform } { verified: true, fee-rate: fee-rate })
    (map-set platform-stats { platform: platform } { total-volume: u0, total-trades: u0 })
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
    owner: CONTRACT-OWNER
  })

(define-read-only (get-active-listings-count)
  (var-get next-listing-id))

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
