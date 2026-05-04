# Backend Prometheus Instrumentation

This reference shows how to expose backend metrics that support the rollout KPI
contract in `deploy/dashboard/realtime-kpis.md`.

## Instrumentation Goals

- Expose delivery success and failure counts for backend message fan-out.
- Record end-to-end delivery latency for queueing and persistence analysis.
- Keep raw metric names stable so the dashboard can derive:
  - `gateway_connect_success_rate`
  - `gateway_reconnect_count`
  - `control_frame_decode_error_count`
  - `pull_after_seq_repair_count`
  - `sqlite_page_query_p95_ms`
  - `conversation_list_patch_apply_p95_ms`

## Go Metric Definitions

```go
package metrics

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	messageDeliveryTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "message_delivery_total",
			Help: "Count of backend message delivery attempts by result and channel type",
		},
		[]string{"result", "channel_type"},
	)

	messageDeliveryLatencySeconds = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "message_delivery_latency_seconds",
			Help:    "Observed backend delivery latency in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"channel_type"},
	)

	gatewayConnectAttemptTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "gateway_connect_attempt_total",
			Help: "Realtime gateway connection attempts",
		},
	)

	successfulGatewayConnectCount = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "successful_gateway_connect_count",
			Help: "Realtime gateway connections that completed successfully",
		},
	)

	controlFrameDecodeErrorCount = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "control_frame_decode_error_count",
			Help: "Control frame decode failures by protocol and reason",
		},
		[]string{"protocol", "reason"},
	)

	pullAfterSeqRepairCount = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "pull_after_seq_repair_count",
			Help: "Gap-repair pulls issued after seq mismatch detection",
		},
	)

	gatewayReconnectCount = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "gateway_reconnect_count",
			Help:    "Reconnect attempts per session window",
			Buckets: []float64{0, 1, 2, 3, 5, 8, 13, 21},
		},
	)

	sqlitePageQuerySeconds = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "sqlite_page_query_seconds",
			Help:    "Latency for page-based message queries",
			Buckets: prometheus.DefBuckets,
		},
	)

	conversationPatchApplySeconds = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "conversation_patch_apply_seconds",
			Help:    "Latency for applying a conversation list patch",
			Buckets: prometheus.DefBuckets,
		},
	)
)

func RecordMessageDelivery(channelType string, startedAt time.Time, err error) {
	result := "success"
	if err != nil {
		result = "failure"
	}

	messageDeliveryTotal.WithLabelValues(result, channelType).Inc()
	messageDeliveryLatencySeconds.WithLabelValues(channelType).Observe(
		time.Since(startedAt).Seconds(),
	)
}
```

## Hook Points For Realtime KPIs

```go
func RecordGatewayConnect(success bool) {
	gatewayConnectAttemptTotal.Inc()
	if success {
		successfulGatewayConnectCount.Inc()
	}
}

func RecordGatewayReconnect(reconnectsInWindow int) {
	gatewayReconnectCount.Observe(float64(reconnectsInWindow))
}

func RecordControlFrameDecodeError(protocol string, reason string) {
	controlFrameDecodeErrorCount.WithLabelValues(protocol, reason).Inc()
}

func RecordGapRepairPull() {
	pullAfterSeqRepairCount.Inc()
}

func ObserveSQLitePageQuery(startedAt time.Time) {
	sqlitePageQuerySeconds.Observe(time.Since(startedAt).Seconds())
}

func ObserveConversationPatchApply(startedAt time.Time) {
	conversationPatchApplySeconds.Observe(time.Since(startedAt).Seconds())
}
```

## Expose `/metrics`

```go
package server

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func RegisterMetricsEndpoint(mux *http.ServeMux) {
	mux.Handle("/metrics", promhttp.Handler())
}
```

## KPI Alignment

| Dashboard KPI | Raw Prometheus series | Notes |
|---|---|---|
| `gateway_connect_success_rate` | `successful_gateway_connect_count`, `gateway_connect_attempt_total` | Derived as success/attempt ratio in PromQL. |
| `gateway_reconnect_count` | `gateway_reconnect_count` histogram | Query with `histogram_quantile` in Grafana/Prometheus. |
| `control_frame_decode_error_count` | `control_frame_decode_error_count` | Split by protocol/reason labels. |
| `pull_after_seq_repair_count` | `pull_after_seq_repair_count` | Counter for seq gap repair traffic. |
| `sqlite_page_query_p95_ms` | `sqlite_page_query_seconds` | Convert seconds to milliseconds in the panel query. |
| `conversation_list_patch_apply_p95_ms` | `conversation_patch_apply_seconds` | Convert seconds to milliseconds in the panel query. |

## Delivery Success And Latency Alerting

- Treat `message_delivery_total{result="failure"}` as the backend failure counter
  for delivery SLOs.
- Use `message_delivery_latency_seconds` to build p95/p99 latency panels for
  queue fan-out, retry storms, and persistence contention.
- Keep label cardinality bounded; do not label by message ID, user ID, or
  channel ID on hot-path metrics.
