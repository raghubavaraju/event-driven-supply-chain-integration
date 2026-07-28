> **Document type: Architecture documentation**

# Idempotency and Deduplication Design

## Why This Is Required

Kafka's at-least-once delivery (see [event-flow-and-design.md](event-flow-and-design.md)) means every consumer must assume it will occasionally receive the same event more than once. Without deduplication, a redelivered `InventoryUpdated` event could decrement stock twice for the same order, or a redelivered `ShipmentDispatched` event could trigger a duplicate customer notification.

## Design

Every event carries a unique, producer-assigned `eventId` (a UUID, distinct from `orderId`/`sku`, which identify the business entity, not the event occurrence). Every consumer:

1. Before processing, checks whether `eventId` exists in a **processed-events store** (an Object Store — persistent, TTL-bound — keyed by `eventId`, scoped per consumer since each consumer's notion of "already processed" is independent).
2. If present, the event is a duplicate: skip business logic entirely, log at `INFO` level, and acknowledge/commit the offset as normal (a duplicate is not an error).
3. If absent, process the event, then write `eventId` to the processed-events store **as part of the same logical unit of work** as the side effect it guards (e.g., in the Inventory consumer, the stock decrement and the `eventId` record are written in the same database transaction where possible, so a crash between the two cannot happen).
4. TTL on the processed-events store is set longer than the maximum plausible redelivery window (design target: 7 days) — long enough to catch any realistic redelivery, without growing unbounded.

## Idempotency at the Business-Logic Level (Defense in Depth)

Deduplication by `eventId` is the primary mechanism, but where practical, business logic is also written to be naturally idempotent as a second layer of protection:

- Inventory decrement is implemented as "set available quantity to X" reconciled against the order's known line items, rather than a blind "decrement by N" where possible, reducing the blast radius of a deduplication-store failure.
- Publishing a downstream event (e.g., `InventoryUpdated`) reuses the same `eventId`-derivation approach (deterministic, derived from the triggering event's `eventId` + a fixed suffix) so that if the *publish* step is retried after a partial failure, the republished event carries the same `eventId` and is itself deduplicated by downstream consumers.

## What This Does Not Solve

This design assumes a single logical consumer instance processes a given partition at a time (standard Kafka consumer-group behavior) — it does not address out-of-order concurrent processing within the same partition, which Kafka's ordering guarantee (see [ADR-002](decisions/ADR-002-event-ordering-and-partitioning.md)) is what actually prevents.
