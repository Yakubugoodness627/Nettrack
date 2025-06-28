;; Nettrack - Malaria Net Distribution Tracker
;; Verify handouts via location and QR code verification

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-location (err u103))
(define-constant err-insufficient-stock (err u104))
(define-constant err-already-distributed (err u105))
(define-constant err-invalid-qr (err u106))
(define-constant err-center-inactive (err u107))
(define-constant err-recipient-exists (err u108))

(define-data-var total-nets-distributed uint u0)
(define-data-var total-distribution-centers uint u0)
(define-data-var contract-active bool true)

(define-map distribution-centers
  { center-id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    latitude: int,
    longitude: int,
    stock: uint,
    distributed: uint,
    active: bool,
    created-at: uint
  }
)

(define-map recipients
  { recipient-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    center-id: uint,
    nets-received: uint,
    qr-code: (string-ascii 100),
    distributed-at: uint,
    verified: bool
  }
)

(define-map qr-codes
  { qr-hash: (string-ascii 100) }
  {
    center-id: uint,
    recipient-id: (string-ascii 50),
    valid: bool,
    created-at: uint,
    used-at: (optional uint)
  }
)

(define-map distribution-logs
  { log-id: uint }
  {
    center-id: uint,
    recipient-id: (string-ascii 50),
    nets-count: uint,
    qr-code: (string-ascii 100),
    location-verified: bool,
    timestamp: uint,
    distributor: principal
  }
)

(define-data-var next-log-id uint u1)

(define-public (initialize-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok true)
  )
)

(define-public (add-distribution-center (name (string-ascii 100)) (location (string-ascii 100)) (latitude int) (longitude int) (initial-stock uint))
  (let (
    (center-id (+ (var-get total-distribution-centers) u1))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len name) u0) err-invalid-location)
    (asserts! (> (len location) u0) err-invalid-location)
    (map-set distribution-centers
      { center-id: center-id }
      {
        name: name,
        location: location,
        latitude: latitude,
        longitude: longitude,
        stock: initial-stock,
        distributed: u0,
        active: true,
        created-at: stacks-block-height
      }
    )
    (var-set total-distribution-centers center-id)
    (ok center-id)
  )
)

(define-public (update-center-stock (center-id uint) (new-stock uint))
  (let (
    (center (unwrap! (map-get? distribution-centers { center-id: center-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set distribution-centers
      { center-id: center-id }
      (merge center { stock: new-stock })
    )
    (ok true)
  )
)

(define-public (deactivate-center (center-id uint))
  (let (
    (center (unwrap! (map-get? distribution-centers { center-id: center-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set distribution-centers
      { center-id: center-id }
      (merge center { active: false })
    )
    (ok true)
  )
)

(define-public (generate-qr-code (center-id uint) (recipient-id (string-ascii 50)) (qr-hash (string-ascii 100)))
  (let (
    (center (unwrap! (map-get? distribution-centers { center-id: center-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get active center) err-center-inactive)
    (asserts! (is-none (map-get? qr-codes { qr-hash: qr-hash })) err-already-exists)
    (map-set qr-codes
      { qr-hash: qr-hash }
      {
        center-id: center-id,
        recipient-id: recipient-id,
        valid: true,
        created-at: stacks-block-height,
        used-at: none
      }
    )
    (ok true)
  )
)

(define-public (register-recipient (recipient-id (string-ascii 50)) (name (string-ascii 100)) (location (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none (map-get? recipients { recipient-id: recipient-id })) err-recipient-exists)
    (asserts! (> (len name) u0) err-invalid-location)
    (map-set recipients
      { recipient-id: recipient-id }
      {
        name: name,
        location: location,
        center-id: u0,
        nets-received: u0,
        qr-code: "",
        distributed-at: u0,
        verified: false
      }
    )
    (ok true)
  )
)

(define-public (distribute-nets (center-id uint) (recipient-id (string-ascii 50)) (nets-count uint) (qr-hash (string-ascii 100)) (latitude int) (longitude int))
  (let (
    (center (unwrap! (map-get? distribution-centers { center-id: center-id }) err-not-found))
    (recipient (unwrap! (map-get? recipients { recipient-id: recipient-id }) err-not-found))
    (qr-data (unwrap! (map-get? qr-codes { qr-hash: qr-hash }) err-invalid-qr))
    (log-id (var-get next-log-id))
    (location-verified (verify-location center-id latitude longitude))
  )
    (asserts! (get active center) err-center-inactive)
    (asserts! (>= (get stock center) nets-count) err-insufficient-stock)
    (asserts! (get valid qr-data) err-invalid-qr)
    (asserts! (is-eq (get center-id qr-data) center-id) err-invalid-qr)
    (asserts! (is-eq (get recipient-id qr-data) recipient-id) err-invalid-qr)
    (asserts! (is-none (get used-at qr-data)) err-already-distributed)
    
    (map-set distribution-centers
      { center-id: center-id }
      (merge center { 
        stock: (- (get stock center) nets-count),
        distributed: (+ (get distributed center) nets-count)
      })
    )
    
    (map-set recipients
      { recipient-id: recipient-id }
      (merge recipient {
        center-id: center-id,
        nets-received: (+ (get nets-received recipient) nets-count),
        qr-code: qr-hash,
        distributed-at: stacks-block-height,
        verified: location-verified
      })
    )
    
    (map-set qr-codes
      { qr-hash: qr-hash }
      (merge qr-data { used-at: (some stacks-block-height) })
    )
    
    (map-set distribution-logs
      { log-id: log-id }
      {
        center-id: center-id,
        recipient-id: recipient-id,
        nets-count: nets-count,
        qr-code: qr-hash,
        location-verified: location-verified,
        timestamp: stacks-block-height,
        distributor: tx-sender
      }
    )
    
    (var-set next-log-id (+ log-id u1))
    (var-set total-nets-distributed (+ (var-get total-nets-distributed) nets-count))
    (ok log-id)
  )
)

(define-public (verify-distribution (qr-hash (string-ascii 100)))
  (let (
    (qr-data (unwrap! (map-get? qr-codes { qr-hash: qr-hash }) err-invalid-qr))
  )
    (asserts! (is-some (get used-at qr-data)) err-not-found)
    (ok {
      center-id: (get center-id qr-data),
      recipient-id: (get recipient-id qr-data),
      used-at: (get used-at qr-data)
    })
  )
)

(define-public (emergency-stop)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-active false)
    (ok true)
  )
)

(define-public (resume-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-active true)
    (ok true)
  )
)

(define-read-only (get-distribution-center (center-id uint))
  (map-get? distribution-centers { center-id: center-id })
)

(define-read-only (get-recipient (recipient-id (string-ascii 50)))
  (map-get? recipients { recipient-id: recipient-id })
)

(define-read-only (get-qr-code-info (qr-hash (string-ascii 100)))
  (map-get? qr-codes { qr-hash: qr-hash })
)

(define-read-only (get-distribution-log (log-id uint))
  (map-get? distribution-logs { log-id: log-id })
)

(define-read-only (get-total-distributions)
  (var-get total-nets-distributed)
)

(define-read-only (get-total-centers)
  (var-get total-distribution-centers)
)

(define-read-only (is-contract-active)
  (var-get contract-active)
)

(define-read-only (get-center-stats (center-id uint))
  (let (
    (center (unwrap! (map-get? distribution-centers { center-id: center-id }) err-not-found))
  )
    (ok {
      stock: (get stock center),
      distributed: (get distributed center),
      active: (get active center),
      efficiency: (if (> (get distributed center) u0)
                     (/ (* (get distributed center) u100) (+ (get stock center) (get distributed center)))
                     u0)
    })
  )
)

(define-private (verify-location (center-id uint) (latitude int) (longitude int))
  (let (
    (center (unwrap! (map-get? distribution-centers { center-id: center-id }) false))
    (center-lat (get latitude center))
    (center-long (get longitude center))
    (lat-diff (if (>= latitude center-lat) (- latitude center-lat) (- center-lat latitude)))
    (long-diff (if (>= longitude center-long) (- longitude center-long) (- center-long longitude)))
  )
    (and (<= lat-diff 1000) (<= long-diff 1000))
  )
)

(define-private (calculate-distance (lat1 int) (long1 int) (lat2 int) (long2 int))
  (let (
    (lat-diff (if (>= lat1 lat2) (- lat1 lat2) (- lat2 lat1)))
    (long-diff (if (>= long1 long2) (- long1 long2) (- long2 long1)))
  )
    (+ (* lat-diff lat-diff) (* long-diff long-diff))
  )
)

(define-read-only (is-qr-code-valid (qr-hash (string-ascii 100)))
  (let (
    (qr-data (map-get? qr-codes { qr-hash: qr-hash }))
  )
    (match qr-data
      some-qr (and (get valid some-qr) (is-none (get used-at some-qr)))
      false
    )
  )
)

(define-read-only (get-recipient-history (recipient-id (string-ascii 50)))
  (let (
    (recipient (map-get? recipients { recipient-id: recipient-id }))
  )
    (match recipient
      some-recipient (ok {
        nets-received: (get nets-received some-recipient),
        last-distribution: (get distributed-at some-recipient),
        verified: (get verified some-recipient)
      })
      err-not-found
    )
  )
)
