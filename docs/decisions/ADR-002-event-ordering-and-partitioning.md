# ADR-002: Partition Keys and Ordering Guarantees Per Topic

**Status:** Accepted
**Date:** 2026-07-28

## Context

Kafka guarantees message order only *within a partition*, not across an entire topic. This platform needs to decide, per topic, what ordering guarantee is required and choose a partition key that delivers it — an unconsidered default (e.g., random/round-robin partitioning) would silently break ordering for consumers that need it.

## Decision, By Topic

| Topic | Partition key | Ordering guarantee | Why |
|---|---|---|---|
| `order.created.v1` | `orderId` | All events for a given order are ordered relative to each other | A single order does not currently produce multiple `OrderCreated` events, but keying by `orderId` keeps this topic consistent with the others and ready for future per-order event types (e.g., `OrderModified`) without a partitioning change |
| `inventory.updated.v1` | `sku` | All stock updates for a given SKU are processed in order | Two near-simultaneous orders affecting the same SKU must be applied in the order they occurred, or available-stock calculations can go negative or double-count a replenishment |
| `shipment.dispatched.v1` | `orderId` | All shipment events for a given order are ordered | An order may ship in multiple packages; per-order ordering keeps status transitions consistent |
| `fulfillment.completed.v1` | `orderId` | Same as above | Same reasoning |

## Consequences

- Consumers that only need per-entity ordering (the common case here) get it "for free" from Kafka's partition guarantee, without needing application-level sequencing logic.
- **Cross-topic ordering is explicitly not guaranteed** — e.g., a consumer cannot assume `InventoryUpdated` for an order always arrives before an unrelated `ShipmentDispatched` for a different order. Consumers are designed to be self-contained per event and must not assume global ordering across topics.
- Partition count must be chosen with these keys in mind: too few partitions limits parallelism for high-cardinality keys like `orderId`; this is documented as an operational tuning parameter in the [operational runbook](../operational-runbook.md) rather than hardcoded here.
- If a future requirement needs strict global ordering across all supply chain events for one order (e.g., a strict order-level audit log), that would require either a single-partition topic (throughput trade-off) or an application-level sequencing/reconciliation step — not solved by this ADR and called out as a known limitation.
