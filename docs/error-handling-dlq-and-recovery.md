> **Document type: Architecture documentation**

# Error Handling, Dead-Letter Queue, and Failure Recovery

## Error Classification

| Error type | Example | Handling |
|---|---|---|
| **Transient** | Downstream DB timeout, temporary network blip | Bounded retry (3 attempts, exponential backoff), then DLQ if still failing |
| **Permanent / malformed** | Event fails schema validation, required field missing | Immediate DLQ, no retry (retrying a malformed message wastes time and delays the messages behind it) |
| **Business rule violation** | e.g., `InventoryUpdated` references a SKU that does not exist | Immediate DLQ, tagged for manual review — this is a data-quality issue, not a transient fault |

## Dead-Letter Queue Design

Each topic has a corresponding DLQ topic (`<topic>.dlq`, e.g., `order.created.v1.dlq`). A message sent to a DLQ carries:

```json
{
  "originalTopic": "order.created.v1",
  "originalPartition": 3,
  "originalOffset": 108422,
  "eventId": "9a1c2e3f-...",
  "correlationId": "6f2b1a3e-...",
  "failureReason": "SCHEMA_VALIDATION_FAILED",
  "failureDetail": "Missing required field: lineItems",
  "consumerApplication": "inventory-event-consumer",
  "failedAt": "2026-07-28T10:20:11.004Z",
  "originalPayload": { "...": "..." }
}
```

This shape is deliberately self-describing: an operator (or an automated reprocessing tool) can inspect a DLQ message and understand what failed, where, and why without cross-referencing logs.

## Recovery From the DLQ

1. **Triage.** DLQ messages are monitored (see [observability-and-monitoring.md](observability-and-monitoring.md)); a non-empty DLQ triggers an alert, since a healthy system should have an empty or near-empty DLQ.
2. **Root-cause.** For schema/validation failures, the fix is usually a producer-side or schema fix; for business-data issues, the fix is usually a manual data correction.
3. **Reprocess.** Once the root cause is fixed, a DLQ message can be manually or automatically re-published to its original topic (preserving its original `eventId`, so downstream idempotency correctly treats it as the same logical event, not a new one).
4. **Never silently discard.** No automated process deletes a DLQ message without either successful reprocessing or an explicit, logged manual decision to discard it — full procedure in the [operational runbook](operational-runbook.md).

## Circuit Breaking for Downstream Calls

Where a consumer's processing logic calls another service (e.g., the Fulfillment consumer calling a warehouse management system), that call is wrapped in the same timeout/retry/circuit-breaker pattern used in the companion project (see [scalability-and-resilience.md](https://github.com/raghubavaraju/enterprise-order-integration-platform/blob/main/docs/scalability-and-resilience.md)) — the difference here is that a circuit-open failure results in the *message* going to the DLQ (or being retried on redelivery) rather than an HTTP error being returned to a caller, since there is no synchronous caller to return an error to.
