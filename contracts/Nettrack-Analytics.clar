;; Predictive Analytics System for Nettrack
;; AI-powered distribution optimization and demand forecasting

(define-constant contract-owner tx-sender)

;; Error constants
(define-constant ERR_ANALYTICS_UNAUTHORIZED (err u300))
(define-constant ERR_ANALYTICS_INVALID_DATA (err u301))
(define-constant ERR_ANALYTICS_NOT_FOUND (err u302))
(define-constant ERR_ANALYTICS_INSUFFICIENT_DATA (err u303))

;; Constants for analytics calculations
(define-constant PREDICTION_WINDOW u2016) ;; ~2 weeks in blocks
(define-constant SEASONAL_CYCLE u52560) ;; ~1 year in blocks
(define-constant MIN_DATA_POINTS u10)
(define-constant ANOMALY_THRESHOLD u150) ;; 150% deviation threshold
(define-constant EFFICIENCY_TARGET u80) ;; 80% efficiency target

;; Helper functions
(define-private (safe-div (a uint) (b uint)) (if (> b u0) (/ a b) u0))
(define-private (abs-diff (a uint) (b uint)) (if (>= a b) (- a b) (- b a)))
(define-private (max (a uint) (b uint)) (if (> a b) a b))
(define-private (min (a uint) (b uint)) (if (< a b) a b))
(define-private (moving-average (current uint) (new-value uint) (weight uint))
  (safe-div (+ (* current weight) new-value) (+ weight u1)))

;; Storage maps for analytics data
(define-map demand-predictions { center-id: uint, time-period: uint }
  { predicted-demand: uint, confidence-level: uint, last-updated: uint })

(define-map distribution-patterns { center-id: uint }
  { avg-daily-distribution: uint, peak-demand-day: uint, efficiency-trend: uint, last-analysis: uint })

(define-map resource-optimization { center-id: uint }
  { optimal-stock-level: uint, reorder-point: uint, recommended-allocation: uint, cost-efficiency: uint })

(define-map anomaly-alerts { alert-id: uint }
  { center-id: uint, anomaly-type: (string-ascii 50), severity: uint, detected-at: uint, resolved: bool })

(define-map performance-metrics { center-id: uint, metric-type: (string-ascii 30) }
  { current-value: uint, trend-direction: int, benchmark-comparison: uint, updated-at: uint })

;; Analytics state variables
(define-data-var next-alert-id uint u1)
(define-data-var last-global-analysis uint u0)
(define-data-var total-predictions uint u0)

;; Public analytics functions

;; Analyze historical demand patterns and update predictions
(define-public (analyze-historical-demand (center-id uint) (lookback-blocks uint))
  (let (
    (center-info (unwrap! (contract-call? .Nettrack get-distribution-center center-id) ERR_ANALYTICS_NOT_FOUND))
    (current-time stacks-block-height)
    (historical-avg (safe-div (get distributed center-info) (max u1 (- current-time (get created-at center-info)))))
    (seasonal-factor (+ u100 (mod (/ current-time u144) u30))) ;; Simple seasonal adjustment
    (predicted-demand (safe-div (* historical-avg seasonal-factor PREDICTION_WINDOW) u100))
    (confidence (min u100 (safe-div lookback-blocks u50)))
  )
    (asserts! (is-eq tx-sender contract-owner) ERR_ANALYTICS_UNAUTHORIZED)
    (asserts! (> lookback-blocks MIN_DATA_POINTS) ERR_ANALYTICS_INSUFFICIENT_DATA)
    
    (map-set demand-predictions { center-id: center-id, time-period: (+ current-time PREDICTION_WINDOW) }
      { predicted-demand: predicted-demand, confidence-level: confidence, last-updated: current-time })
    
    (map-set distribution-patterns { center-id: center-id }
      { avg-daily-distribution: (safe-div historical-avg u144),
        peak-demand-day: (mod current-time u7),
        efficiency-trend: (get efficiency (unwrap-panic (contract-call? .Nettrack get-center-stats center-id))),
        last-analysis: current-time })
    
    (var-set total-predictions (+ (var-get total-predictions) u1))
    (ok predicted-demand)
  )
)

;; Calculate optimal resource allocation for a center
(define-public (optimize-resource-allocation (center-id uint) (target-efficiency uint))
  (let (
    (center-stats (unwrap! (contract-call? .Nettrack get-center-stats center-id) ERR_ANALYTICS_NOT_FOUND))
    (pattern (map-get? distribution-patterns { center-id: center-id }))
    (current-efficiency (get efficiency center-stats))
    (daily-demand (default-to u10 (get avg-daily-distribution pattern)))
    (buffer-factor (if (< current-efficiency target-efficiency) u120 u110))
    (optimal-stock (safe-div (* daily-demand PREDICTION_WINDOW buffer-factor) u100))
    (reorder-threshold (safe-div optimal-stock u3))
  )
    (asserts! (is-eq tx-sender contract-owner) ERR_ANALYTICS_UNAUTHORIZED)
    (asserts! (and (> target-efficiency u50) (< target-efficiency u100)) ERR_ANALYTICS_INVALID_DATA)
    
    (map-set resource-optimization { center-id: center-id }
      { optimal-stock-level: optimal-stock,
        reorder-point: reorder-threshold,
        recommended-allocation: (safe-div optimal-stock u7),
        cost-efficiency: (safe-div (* current-efficiency target-efficiency) u100) })
    
    (ok optimal-stock)
  )
)

;; Detect distribution anomalies and create alerts
(define-public (detect-distribution-anomalies (center-id uint) (analysis-period uint))
  (let (
    (center-stats (unwrap! (contract-call? .Nettrack get-center-stats center-id) ERR_ANALYTICS_NOT_FOUND))
    (pattern (map-get? distribution-patterns { center-id: center-id }))
    (expected-efficiency (default-to EFFICIENCY_TARGET (get efficiency-trend pattern)))
    (actual-efficiency (get efficiency center-stats))
    (efficiency-deviation (abs-diff actual-efficiency expected-efficiency))
    (alert-id (var-get next-alert-id))
    (is-anomaly (> efficiency-deviation (safe-div (* expected-efficiency ANOMALY_THRESHOLD) u100)))
  )
    (asserts! (is-eq tx-sender contract-owner) ERR_ANALYTICS_UNAUTHORIZED)
    
    (if is-anomaly
      (begin
        (map-set anomaly-alerts { alert-id: alert-id }
          { center-id: center-id,
            anomaly-type: (if (< actual-efficiency expected-efficiency) "low-efficiency" "distribution-spike"),
            severity: (min u100 (safe-div efficiency-deviation u5)),
            detected-at: stacks-block-height,
            resolved: false })
        (var-set next-alert-id (+ alert-id u1))
        (ok alert-id)
      )
      (ok u0) ;; No anomaly detected
    )
  )
)

;; Update performance metrics for tracking
(define-public (update-performance-metrics (center-id uint) (metric-type (string-ascii 30)) (new-value uint))
  (let (
    (existing-metric (map-get? performance-metrics { center-id: center-id, metric-type: metric-type }))
    (previous-value (default-to new-value (get current-value existing-metric)))
    (trend-direction (if (> new-value previous-value) 1 (if (< new-value previous-value) -1 0)))
    (benchmark-score (safe-div (* new-value u100) (max u1 EFFICIENCY_TARGET)))
  )
    (asserts! (is-eq tx-sender contract-owner) ERR_ANALYTICS_UNAUTHORIZED)
    
    (map-set performance-metrics { center-id: center-id, metric-type: metric-type }
      { current-value: new-value,
        trend-direction: trend-direction,
        benchmark-comparison: benchmark-score,
        updated-at: stacks-block-height })
    
    (ok true)
  )
)

;; Resolve anomaly alert
(define-public (resolve-anomaly-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? anomaly-alerts { alert-id: alert-id }) ERR_ANALYTICS_NOT_FOUND)))
    (asserts! (is-eq tx-sender contract-owner) ERR_ANALYTICS_UNAUTHORIZED)
    (asserts! (not (get resolved alert)) ERR_ANALYTICS_INVALID_DATA)
    
    (map-set anomaly-alerts { alert-id: alert-id } (merge alert { resolved: true }))
    (ok true)
  )
)

;; Read-only analytics functions

(define-read-only (get-demand-forecast (center-id uint) (time-period uint))
  (map-get? demand-predictions { center-id: center-id, time-period: time-period })
)

(define-read-only (get-distribution-insights (center-id uint))
  (let (
    (pattern (map-get? distribution-patterns { center-id: center-id }))
    (optimization (map-get? resource-optimization { center-id: center-id }))
    (center-stats (contract-call? .Nettrack get-center-stats center-id))
  )
    (ok {
      daily-distribution: (default-to u0 (get avg-daily-distribution pattern)),
      efficiency-trend: (default-to u0 (get efficiency-trend pattern)),
      optimal-stock: (default-to u0 (get optimal-stock-level optimization)),
      cost-efficiency: (default-to u0 (get cost-efficiency optimization)),
      current-performance: (get efficiency (unwrap-panic center-stats))
    })
  )
)

(define-read-only (get-optimization-recommendations (center-id uint))
  (map-get? resource-optimization { center-id: center-id })
)

(define-read-only (get-anomaly-alert (alert-id uint))
  (map-get? anomaly-alerts { alert-id: alert-id })
)

(define-read-only (get-performance-metric (center-id uint) (metric-type (string-ascii 30)))
  (map-get? performance-metrics { center-id: center-id, metric-type: metric-type })
)

(define-read-only (get-predictive-alerts (center-id uint))
  (let (
    (pattern (map-get? distribution-patterns { center-id: center-id }))
    (optimization (map-get? resource-optimization { center-id: center-id }))
    (center-stats (contract-call? .Nettrack get-center-stats center-id))
    (current-stock (get stock (unwrap-panic center-stats)))
    (optimal-stock (default-to u100 (get optimal-stock-level optimization)))
    (reorder-point (default-to u30 (get reorder-point optimization)))
  )
    (ok {
      stock-alert: (< current-stock reorder-point),
      efficiency-alert: (< (get efficiency (unwrap-panic center-stats)) EFFICIENCY_TARGET),
      overstock-alert: (> current-stock (safe-div (* optimal-stock u120) u100)),
      maintenance-alert: false,
      demand-spike-predicted: (> (default-to u0 (get peak-demand-day pattern)) u5)
    })
  )
)

(define-read-only (get-system-analytics-summary)
  (ok {
    total-predictions-made: (var-get total-predictions),
    last-analysis-block: (var-get last-global-analysis),
    active-alerts: (- (var-get next-alert-id) u1),
    prediction-window-blocks: PREDICTION_WINDOW,
    anomaly-threshold-percent: ANOMALY_THRESHOLD
  })
)
