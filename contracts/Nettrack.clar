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
(define-constant err-equipment-not-found (err u109))
(define-constant err-equipment-already-exists (err u110))
(define-constant err-equipment-maintenance-overdue (err u111))
(define-constant err-equipment-inactive (err u112))
(define-constant err-invalid-equipment-type (err u113))
(define-constant err-batch-not-found (err u114))
(define-constant err-invalid-batch-status (err u115))
(define-constant err-batch-already-shipped (err u116))
(define-constant err-invalid-manufacturer (err u117))
(define-constant err-batch-expired (err u118))
(define-constant err-insufficient-batch-quantity (err u119))

(define-data-var total-nets-distributed uint u0)
(define-data-var total-distribution-centers uint u0)
(define-data-var contract-active bool true)
(define-data-var total-equipment uint u0)
(define-data-var total-batches uint u0)
(define-data-var total-shipments uint u0)

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

(define-map equipment
  { equipment-id: uint }
  {
    name: (string-ascii 100),
    equipment-type: (string-ascii 50),
    center-id: uint,
    purchase-date: uint,
    last-maintenance: uint,
    next-maintenance: uint,
    maintenance-interval: uint,
    condition: (string-ascii 20),
    active: bool,
    total-maintenance-cost: uint,
    maintenance-count: uint,
    manufacturer: (string-ascii 100),
    model: (string-ascii 100),
    serial-number: (string-ascii 100)
  }
)

(define-map maintenance-records
  { record-id: uint }
  {
    equipment-id: uint,
    maintenance-type: (string-ascii 50),
    performed-by: principal,
    maintenance-date: uint,
    cost: uint,
    description: (string-ascii 200),
    next-due-date: uint,
    parts-replaced: (string-ascii 200),
    duration-hours: uint
  }
)

(define-map equipment-alerts
  { alert-id: uint }
  {
    equipment-id: uint,
    alert-type: (string-ascii 50),
    severity: (string-ascii 20),
    message: (string-ascii 200),
    created-at: uint,
    resolved: bool,
    resolved-at: (optional uint),
    resolved-by: (optional principal)
  }
)

(define-data-var next-maintenance-record-id uint u1)
(define-data-var next-alert-id uint u1)

(define-map net-batches
  { batch-id: uint }
  {
    manufacturer: (string-ascii 100),
    manufacturing-date: uint,
    expiry-date: uint,
    batch-size: uint,
    remaining-quantity: uint,
    quality-grade: (string-ascii 20),
    insecticide-type: (string-ascii 50),
    batch-code: (string-ascii 50),
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map shipments
  { shipment-id: uint }
  {
    batch-id: uint,
    from-location: (string-ascii 100),
    to-center-id: uint,
    quantity: uint,
    shipped-date: uint,
    expected-delivery: uint,
    actual-delivery: (optional uint),
    status: (string-ascii 20),
    tracking-code: (string-ascii 50),
    transport-method: (string-ascii 50),
    shipped-by: principal,
    received-by: (optional principal)
  }
)

(define-map batch-quality-tests
  { test-id: uint }
  {
    batch-id: uint,
    test-type: (string-ascii 50),
    test-date: uint,
    test-result: (string-ascii 20),
    tested-by: principal,
    notes: (string-ascii 200),
    compliance-standard: (string-ascii 50)
  }
)

(define-map supply-chain-events
  { event-id: uint }
  {
    batch-id: uint,
    event-type: (string-ascii 50),
    location: (string-ascii 100),
    timestamp: uint,
    details: (string-ascii 200),
    recorded-by: principal
  }
)

(define-data-var next-batch-id uint u1)
(define-data-var next-shipment-id uint u1)
(define-data-var next-test-id uint u1)
(define-data-var next-event-id uint u1)

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

(define-public (add-equipment (name (string-ascii 100)) (equipment-type (string-ascii 50)) (center-id uint) (maintenance-interval uint) (manufacturer (string-ascii 100)) (model (string-ascii 100)) (serial-number (string-ascii 100)))
  (let (
    (equipment-id (+ (var-get total-equipment) u1))
    (center (unwrap! (map-get? distribution-centers { center-id: center-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len name) u0) err-invalid-equipment-type)
    (asserts! (> (len equipment-type) u0) err-invalid-equipment-type)
    (asserts! (> maintenance-interval u0) err-invalid-equipment-type)
    (map-set equipment
      { equipment-id: equipment-id }
      {
        name: name,
        equipment-type: equipment-type,
        center-id: center-id,
        purchase-date: stacks-block-height,
        last-maintenance: stacks-block-height,
        next-maintenance: (+ stacks-block-height maintenance-interval),
        maintenance-interval: maintenance-interval,
        condition: "excellent",
        active: true,
        total-maintenance-cost: u0,
        maintenance-count: u0,
        manufacturer: manufacturer,
        model: model,
        serial-number: serial-number
      }
    )
    (var-set total-equipment equipment-id)
    (ok equipment-id)
  )
)

(define-public (perform-maintenance (equipment-id uint) (maintenance-type (string-ascii 50)) (cost uint) (description (string-ascii 200)) (parts-replaced (string-ascii 200)) (duration-hours uint))
  (let (
    (equip (unwrap! (map-get? equipment { equipment-id: equipment-id }) err-equipment-not-found))
    (record-id (var-get next-maintenance-record-id))
    (new-next-maintenance (+ stacks-block-height (get maintenance-interval equip)))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get active equip) err-equipment-inactive)
    (asserts! (> (len maintenance-type) u0) err-invalid-equipment-type)
    
    (map-set maintenance-records
      { record-id: record-id }
      {
        equipment-id: equipment-id,
        maintenance-type: maintenance-type,
        performed-by: tx-sender,
        maintenance-date: stacks-block-height,
        cost: cost,
        description: description,
        next-due-date: new-next-maintenance,
        parts-replaced: parts-replaced,
        duration-hours: duration-hours
      }
    )
    
    (map-set equipment
      { equipment-id: equipment-id }
      (merge equip {
        last-maintenance: stacks-block-height,
        next-maintenance: new-next-maintenance,
        total-maintenance-cost: (+ (get total-maintenance-cost equip) cost),
        maintenance-count: (+ (get maintenance-count equip) u1),
        condition: (if (>= cost u1000) "fair" "good")
      })
    )
    
    (var-set next-maintenance-record-id (+ record-id u1))
    (ok record-id)
  )
)

(define-public (create-equipment-alert (equipment-id uint) (alert-type (string-ascii 50)) (severity (string-ascii 20)) (message (string-ascii 200)))
  (let (
    (equip (unwrap! (map-get? equipment { equipment-id: equipment-id }) err-equipment-not-found))
    (alert-id (var-get next-alert-id))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get active equip) err-equipment-inactive)
    (asserts! (> (len alert-type) u0) err-invalid-equipment-type)
    (asserts! (> (len message) u0) err-invalid-equipment-type)
    
    (map-set equipment-alerts
      { alert-id: alert-id }
      {
        equipment-id: equipment-id,
        alert-type: alert-type,
        severity: severity,
        message: message,
        created-at: stacks-block-height,
        resolved: false,
        resolved-at: none,
        resolved-by: none
      }
    )
    
    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

(define-public (resolve-equipment-alert (alert-id uint))
  (let (
    (alert (unwrap! (map-get? equipment-alerts { alert-id: alert-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get resolved alert)) err-already-exists)
    
    (map-set equipment-alerts
      { alert-id: alert-id }
      (merge alert {
        resolved: true,
        resolved-at: (some stacks-block-height),
        resolved-by: (some tx-sender)
      })
    )
    
    (ok true)
  )
)

(define-public (deactivate-equipment (equipment-id uint))
  (let (
    (equip (unwrap! (map-get? equipment { equipment-id: equipment-id }) err-equipment-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get active equip) err-equipment-inactive)
    
    (map-set equipment
      { equipment-id: equipment-id }
      (merge equip { active: false })
    )
    
    (ok true)
  )
)

(define-public (update-equipment-condition (equipment-id uint) (new-condition (string-ascii 20)))
  (let (
    (equip (unwrap! (map-get? equipment { equipment-id: equipment-id }) err-equipment-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get active equip) err-equipment-inactive)
    (asserts! (> (len new-condition) u0) err-invalid-equipment-type)
    
    (map-set equipment
      { equipment-id: equipment-id }
      (merge equip { condition: new-condition })
    )
    
    (ok true)
  )
)

(define-read-only (get-equipment (equipment-id uint))
  (map-get? equipment { equipment-id: equipment-id })
)

(define-read-only (get-maintenance-record (record-id uint))
  (map-get? maintenance-records { record-id: record-id })
)

(define-read-only (get-equipment-alert (alert-id uint))
  (map-get? equipment-alerts { alert-id: alert-id })
)

(define-read-only (get-total-equipment)
  (var-get total-equipment)
)

(define-read-only (get-equipment-maintenance-status (equipment-id uint))
  (let (
    (equip (unwrap! (map-get? equipment { equipment-id: equipment-id }) err-equipment-not-found))
    (current-block stacks-block-height)
    (next-maintenance (get next-maintenance equip))
    (days-until-maintenance (if (>= next-maintenance current-block) (- next-maintenance current-block) u0))
    (overdue (< next-maintenance current-block))
  )
    (ok {
      equipment-id: equipment-id,
      condition: (get condition equip),
      last-maintenance: (get last-maintenance equip),
      next-maintenance: next-maintenance,
      days-until-maintenance: days-until-maintenance,
      overdue: overdue,
      maintenance-count: (get maintenance-count equip),
      total-cost: (get total-maintenance-cost equip)
    })
  )
)

(define-read-only (get-center-equipment (center-id uint))
  (let (
    (center (unwrap! (map-get? distribution-centers { center-id: center-id }) err-not-found))
  )
    (ok {
      center-id: center-id,
      center-name: (get name center),
      active: (get active center)
    })
  )
)

(define-read-only (is-equipment-maintenance-overdue (equipment-id uint))
  (let (
    (equip (unwrap! (map-get? equipment { equipment-id: equipment-id }) false))
    (current-block stacks-block-height)
  )
    (< (get next-maintenance equip) current-block)
  )
)

(define-read-only (get-equipment-efficiency (equipment-id uint))
  (let (
    (equip (unwrap! (map-get? equipment { equipment-id: equipment-id }) err-equipment-not-found))
    (age-blocks (- stacks-block-height (get purchase-date equip)))
    (maintenance-ratio (if (> age-blocks u0) (/ (* (get maintenance-count equip) u100) age-blocks) u0))
  )
    (ok {
      equipment-id: equipment-id,
      age-blocks: age-blocks,
      maintenance-ratio: maintenance-ratio,
      cost-per-maintenance: (if (> (get maintenance-count equip) u0) (/ (get total-maintenance-cost equip) (get maintenance-count equip)) u0),
      condition: (get condition equip)
    })
  )
)

(define-public (create-net-batch (manufacturer (string-ascii 100)) (batch-size uint) (expiry-blocks uint) (quality-grade (string-ascii 20)) (insecticide-type (string-ascii 50)) (batch-code (string-ascii 50)))
  (let (
    (batch-id (var-get next-batch-id))
    (expiry-date (+ stacks-block-height expiry-blocks))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len manufacturer) u0) err-invalid-manufacturer)
    (asserts! (> batch-size u0) err-invalid-batch-status)
    (asserts! (> (len quality-grade) u0) err-invalid-batch-status)
    (asserts! (> (len batch-code) u0) err-invalid-batch-status)
    (asserts! (> expiry-blocks u0) err-invalid-batch-status)
    
    (map-set net-batches
      { batch-id: batch-id }
      {
        manufacturer: manufacturer,
        manufacturing-date: stacks-block-height,
        expiry-date: expiry-date,
        batch-size: batch-size,
        remaining-quantity: batch-size,
        quality-grade: quality-grade,
        insecticide-type: insecticide-type,
        batch-code: batch-code,
        status: "manufactured",
        created-at: stacks-block-height
      }
    )
    
    (try! (record-supply-chain-event batch-id "batch-created" "manufacturing-facility" "Batch manufactured and recorded"))
    (var-set next-batch-id (+ batch-id u1))
    (var-set total-batches (+ (var-get total-batches) u1))
    (ok batch-id)
  )
)

(define-public (ship-batch (batch-id uint) (to-center-id uint) (quantity uint) (from-location (string-ascii 100)) (tracking-code (string-ascii 50)) (transport-method (string-ascii 50)) (expected-delivery-blocks uint))
  (let (
    (batch (unwrap! (map-get? net-batches { batch-id: batch-id }) err-batch-not-found))
    (center (unwrap! (map-get? distribution-centers { center-id: to-center-id }) err-not-found))
    (shipment-id (var-get next-shipment-id))
    (expected-delivery (+ stacks-block-height expected-delivery-blocks))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= (get remaining-quantity batch) quantity) err-insufficient-batch-quantity)
    (asserts! (or (is-eq (get status batch) "manufactured") (is-eq (get status batch) "partially-shipped")) err-batch-already-shipped)
    (asserts! (< stacks-block-height (get expiry-date batch)) err-batch-expired)
    (asserts! (> quantity u0) err-invalid-batch-status)
    (asserts! (> (len tracking-code) u0) err-invalid-batch-status)
    
    (map-set shipments
      { shipment-id: shipment-id }
      {
        batch-id: batch-id,
        from-location: from-location,
        to-center-id: to-center-id,
        quantity: quantity,
        shipped-date: stacks-block-height,
        expected-delivery: expected-delivery,
        actual-delivery: none,
        status: "in-transit",
        tracking-code: tracking-code,
        transport-method: transport-method,
        shipped-by: tx-sender,
        received-by: none
      }
    )
    
    (map-set net-batches
      { batch-id: batch-id }
      (merge batch {
        remaining-quantity: (- (get remaining-quantity batch) quantity),
        status: (if (is-eq (- (get remaining-quantity batch) quantity) u0) "shipped" "partially-shipped")
      })
    )
    
    (try! (record-supply-chain-event batch-id "shipment-created" from-location "Batch shipped to distribution center"))
    (var-set next-shipment-id (+ shipment-id u1))
    (var-set total-shipments (+ (var-get total-shipments) u1))
    (ok shipment-id)
  )
)

(define-public (receive-shipment (shipment-id uint))
  (let (
    (shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) err-not-found))
    (batch (unwrap! (map-get? net-batches { batch-id: (get batch-id shipment) }) err-batch-not-found))
    (center (unwrap! (map-get? distribution-centers { center-id: (get to-center-id shipment) }) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status shipment) "in-transit") err-invalid-batch-status)
    
    (map-set shipments
      { shipment-id: shipment-id }
      (merge shipment {
        status: "delivered",
        actual-delivery: (some stacks-block-height),
        received-by: (some tx-sender)
      })
    )
    
    (map-set distribution-centers
      { center-id: (get to-center-id shipment) }
      (merge center {
        stock: (+ (get stock center) (get quantity shipment))
      })
    )
    
    (try! (record-supply-chain-event (get batch-id shipment) "shipment-received" (get name center) "Shipment received at distribution center"))
    (ok true)
  )
)

(define-public (perform-quality-test (batch-id uint) (test-type (string-ascii 50)) (test-result (string-ascii 20)) (notes (string-ascii 200)) (compliance-standard (string-ascii 50)))
  (let (
    (batch (unwrap! (map-get? net-batches { batch-id: batch-id }) err-batch-not-found))
    (test-id (var-get next-test-id))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len test-type) u0) err-invalid-batch-status)
    (asserts! (> (len test-result) u0) err-invalid-batch-status)
    
    (map-set batch-quality-tests
      { test-id: test-id }
      {
        batch-id: batch-id,
        test-type: test-type,
        test-date: stacks-block-height,
        test-result: test-result,
        tested-by: tx-sender,
        notes: notes,
        compliance-standard: compliance-standard
      }
    )
    
    (try! (record-supply-chain-event batch-id "quality-test" "quality-lab" (concat-strings "Quality test performed: " test-result)))
    (var-set next-test-id (+ test-id u1))
    (ok test-id)
  )
)

(define-public (record-supply-chain-event (batch-id uint) (event-type (string-ascii 50)) (location (string-ascii 100)) (details (string-ascii 200)))
  (let (
    (batch (unwrap! (map-get? net-batches { batch-id: batch-id }) err-batch-not-found))
    (event-id (var-get next-event-id))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (len event-type) u0) err-invalid-batch-status)
    (asserts! (> (len location) u0) err-invalid-batch-status)
    
    (map-set supply-chain-events
      { event-id: event-id }
      {
        batch-id: batch-id,
        event-type: event-type,
        location: location,
        timestamp: stacks-block-height,
        details: details,
        recorded-by: tx-sender
      }
    )
    
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

(define-public (expire-batch (batch-id uint))
  (let (
    (batch (unwrap! (map-get? net-batches { batch-id: batch-id }) err-batch-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= stacks-block-height (get expiry-date batch)) err-invalid-batch-status)
    
    (map-set net-batches
      { batch-id: batch-id }
      (merge batch { status: "expired" })
    )
    
    (try! (record-supply-chain-event batch-id "batch-expired" "system" "Batch expired and marked as unusable"))
    (ok true)
  )
)

(define-read-only (get-batch (batch-id uint))
  (map-get? net-batches { batch-id: batch-id })
)

(define-read-only (get-shipment (shipment-id uint))
  (map-get? shipments { shipment-id: shipment-id })
)

(define-read-only (get-quality-test (test-id uint))
  (map-get? batch-quality-tests { test-id: test-id })
)

(define-read-only (get-supply-chain-event (event-id uint))
  (map-get? supply-chain-events { event-id: event-id })
)

(define-read-only (get-batch-traceability (batch-id uint))
  (let (
    (batch (unwrap! (map-get? net-batches { batch-id: batch-id }) err-batch-not-found))
  )
    (ok {
      batch-info: batch,
      is-expired: (>= stacks-block-height (get expiry-date batch)),
      age-blocks: (- stacks-block-height (get manufacturing-date batch)),
      utilization-rate: (if (> (get batch-size batch) u0) (/ (* (- (get batch-size batch) (get remaining-quantity batch)) u100) (get batch-size batch)) u0)
    })
  )
)

(define-read-only (get-shipment-status (tracking-code (string-ascii 50)))
  (let (
    (shipment-found none)
  )
    (ok {
      tracking-code: tracking-code,
      status: "not-found"
    })
  )
)

(define-read-only (get-total-batches)
  (var-get total-batches)
)

(define-read-only (get-total-shipments)
  (var-get total-shipments)
)

(define-read-only (get-batch-quality-summary (batch-id uint))
  (let (
    (batch (unwrap! (map-get? net-batches { batch-id: batch-id }) err-batch-not-found))
  )
    (ok {
      batch-id: batch-id,
      quality-grade: (get quality-grade batch),
      insecticide-type: (get insecticide-type batch),
      manufacturing-date: (get manufacturing-date batch),
      expiry-date: (get expiry-date batch),
      is-expired: (>= stacks-block-height (get expiry-date batch)),
      manufacturer: (get manufacturer batch)
    })
  )
)

(define-private (concat-strings (str1 (string-ascii 200)) (str2 (string-ascii 200)))
  str1
)


