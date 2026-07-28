> **Document type: Architecture documentation**

# Event Flow Documentation

## Topics and Producers/Consumers

| Topic | Producer | Consumer(s) | Partition key |
|---|---|---|---|
| `order.created.v1` | Order Process API (companion project) | Inventory Event Consumer, Analytics Consumer | `orderId` |
| `inventory.updated.v1` | Inventory Event Consumer | Fulfillment Event Consumer, Analytics Consumer | `sku` |
| `shipment.dispatched.v1` | Fulfillment Event Consumer | Notification Event Consumer, Analytics Consumer | `orderId` |
| `fulfillment.completed.v1` | Fulfillment Event Consumer | Notification Event Consumer, Analytics Consumer | `orderId` |

## Asynchronous Processing Model

Every consumer in this platform follows the same processing shape:

1. **Consume** a message from its subscribed topic (consumer group per service, so each service scales independently and processes each message exactly once per group).
2. **Deduplicate** using the idempotency design described in [`idempotency-and-deduplication.md`](idempotency-and-deduplication.md), before any side-effecting logic runs.
3. **Process** the business logic for that event.
4. **Publish** any resulting downstream event(s), if applicable.
5. **Acknowledge/commit the offset** only after steps 2–4 complete successfully — never before, so a crash mid-processing results in redelivery (handled safely by step 2's deduplication) rather than silent message loss.

## Message Ordering Considerations

See [ADR-002](decisions/ADR-002-event-ordering-and-partitioning.md) for the full per-topic partition key rationale. In short: ordering is guaranteed **per entity** (per `orderId` or per `sku`, depending on the topic) via partition key selection, not globally across a topic or across topics.

## Duplicate-Event Handling

Kafka's at-least-once delivery (the default in this design, favored over at-most-once because silently dropping a supply chain event is a worse failure mode than processing one twice) means every consumer **will**, eventually, see redelivered messages — after a consumer restart, a rebalance, or a retried commit. Every consumer treats this as a normal, expected condition, not an edge case, via the idempotency design referenced above.

## Event Replay

Kafka topic retention (configured per topic, minimum 7 days for operational topics and 90 days for the topics the Analytics Consumer reads, per the [operational runbook](operational-runbook.md)) allows:

- **Analytics backfill:** the Analytics Consumer can reset its consumer group offset to the beginning of retained history and reprocess events to rebuild or correct a downstream dataset.
- **Incident recovery:** if a bug in a consumer processed events incorrectly for a window of time, that consumer's offset can be reset to just before the bad deployment and events reprocessed — safe specifically because processing is idempotent.

Replay is an operational action (offset reset), not a feature built into the Mule flows themselves — see the runbook for the exact procedure and its preconditions.

## Retry Strategy

Each consumer wraps its processing logic in a bounded retry (3 attempts, exponential backoff starting at 500ms) for **transient** failures only (downstream service timeout, transient DB connection issue). Retries happen **before** committing the offset, so a message is only considered "done" after either success or exhausting retries. Non-transient failures (malformed event, business rule violation) are not retried — they go straight to the dead-letter queue, since retrying a malformed message will never succeed. Full detail: [`error-handling-dlq-and-recovery.md`](error-handling-dlq-and-recovery.md).

## Failure Recovery Summary

| Failure type | Handling |
|---|---|
| Transient downstream failure | Bounded retry with backoff, then DLQ if exhausted |
| Malformed/invalid event | Immediate DLQ, no retry |
| Consumer crash mid-processing | Message redelivered on restart; idempotency makes reprocessing safe |
| Consumer down for an extended period | Messages accumulate in the topic (bounded by retention); consumer catches up on restart; no message loss within the retention window |
| Bad deployment processed events incorrectly | Manual offset reset + replay, per the operational runbook |
