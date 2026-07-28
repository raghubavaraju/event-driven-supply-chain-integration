> **Document type: Architecture documentation**

# Monitoring, Observability, and Correlation IDs

## Correlation IDs Across Asynchronous Boundaries

Unlike the companion project's synchronous request-reply chain, there is no single HTTP request to attach a correlation ID to here — instead, correlation propagates through event payloads:

- The `correlationId` present on the original `OrderCreated` event (originating from the `X-Correlation-Id` set in the companion project's Order Process API) is carried forward into every downstream event it causes (`InventoryUpdated`, `ShipmentDispatched`, `FulfillmentCompleted`), even though each is a logically separate message.
- This means a single `correlationId` can be used to reconstruct the entire cross-system, cross-topic journey of one order — from synchronous order creation through every asynchronous downstream effect — by querying logs or a trace store for that ID.
- Each event's own `eventId` remains distinct (needed for deduplication, per [idempotency-and-deduplication.md](idempotency-and-deduplication.md)); `correlationId` and `eventId` serve different purposes and are never conflated.

## Structured Logging

Every consumer emits structured JSON logs following the same shape used in the companion project (see [its logging strategy](https://github.com/raghubavaraju/enterprise-order-integration-platform/blob/main/docs/logging-and-correlation-id-strategy.md)), extended with event-specific fields:

```json
{
  "timestamp": "2026-07-28T10:20:05.117Z",
  "correlationId": "6f2b1a3e-2c31-4e9a-9a2d-1a7b6f8e2b10",
  "eventId": "9a1c2e3f-77b1-4a2e-9c31-2f0a1e6b7d90",
  "application": "inventory-event-consumer",
  "topic": "order.created.v1",
  "partition": 3,
  "offset": 108422,
  "level": "INFO",
  "message": "Inventory decremented",
  "durationMs": 44
}
```

## Metrics

Each consumer exposes/logs (design target, not a claimed production dashboard):

- **Consumer lag** per topic/partition — the primary early-warning signal that a consumer is falling behind.
- **DLQ message count** per topic, alerting on any non-zero, sustained value.
- **Processing duration** per event, to catch performance regressions before they cause lag.
- **Duplicate-event rate** (from the idempotency check) — a rising rate can indicate an upstream producer or broker issue worth investigating even though duplicates are handled safely.

## Monitoring and Alerting Targets

| Signal | Alert condition (design target) |
|---|---|
| Consumer lag | Sustained growth over a defined window (e.g., lag not decreasing over 15 minutes under normal load) |
| DLQ depth | Any message present for longer than a defined grace period (e.g., 5 minutes) |
| Consumer group rebalance frequency | Unusually frequent rebalancing, often indicative of consumer instability |
| Processing error rate | Error rate exceeding a defined threshold over a rolling window |

These are documented as the metrics and thresholds this design is built to support — not measured results from a running system.
