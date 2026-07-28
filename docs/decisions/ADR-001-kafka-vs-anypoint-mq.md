# ADR-001: Use Kafka for Supply Chain Event Streaming; Anypoint MQ Documented as the Alternative

**Status:** Accepted
**Date:** 2026-07-28

## Context

This platform needs an asynchronous messaging backbone for the `OrderCreated → InventoryUpdated → ShipmentDispatched → FulfillmentCompleted` event chain, with multiple independent consumers per event (operational services plus an analytics/reporting consumer) and a requirement to support event replay for analytics backfill and incident recovery. MuleSoft supports both a native managed queue/pub-sub service (Anypoint MQ) and Kafka connectivity (via the Kafka Connector). Both are valid, commonly used choices in real MuleSoft architectures — this ADR documents why Kafka was chosen for *this* scenario, and the conditions under which Anypoint MQ would be the better fit instead.

## Options Considered

### Option A — Apache Kafka
- **Pros:** Native support for multiple independent consumer groups reading the same topic without competing for messages (fan-out without extra queues); configurable log retention enables **event replay** (a named requirement for the analytics consumer and for incident recovery); high-throughput partitioned ordering (ordering guaranteed per partition key, e.g., `orderId` or `sku`); mature ecosystem for schema registries and stream processing if this platform grows.
- **Cons:** Requires operating (or consuming as a managed service) a Kafka cluster — real operational overhead (broker management, partition/replication tuning, monitoring) beyond what a MuleSoft team may already own; steeper operational learning curve than a fully managed queue.

### Option B — Anypoint MQ
- **Pros:** Fully managed within the Anypoint Platform — no cluster to operate; native Mule connector with tight platform integration (queues/exchanges provisioned via Anypoint Platform, consistent with API Manager-based governance used elsewhere in this portfolio); simpler operational model, lower time-to-first-message.
- **Cons:** Exchange/queue model supports pub-sub via fan-out exchanges, but **does not provide log-based replay** the way Kafka's retention model does — once a message is consumed and acknowledged, it is gone unless explicitly re-published; less natural fit for a consumer (analytics) that needs to reprocess historical events on demand.

## Decision

Use **Kafka** as the event backbone for this project, specifically because two of the stated requirements — multi-consumer fan-out to an independent analytics consumer, and event replay for backfill/recovery — are Kafka's core strengths and are materially harder to satisfy with Anypoint MQ's queue/exchange model.

## Consequences

- This project takes on the operational responsibility of a Kafka cluster (or a managed Kafka offering); that cost is treated as justified here because replay and fan-out are explicit, named requirements, not incidental ones.
- Each Mule application uses the Kafka Connector for both publish and consume; partition keys are chosen deliberately (see [ADR-002](ADR-002-event-ordering-and-partitioning.md)) to preserve ordering where it matters.
- **When Anypoint MQ would be the better choice instead:** a simpler event flow with a small, known set of consumers, no replay requirement, and a strong preference for minimizing operational surface area (e.g., a small integration team without Kafka operational experience) — in that situation, Anypoint MQ's fully managed model and tighter Anypoint Platform integration would be the more pragmatic choice, and this ADR's reasoning would not apply.
- This decision is scenario-specific. The companion project's order-creation flow remains synchronous REST (Kafka/MQ is not used there at all) — see [the companion project's ADR-003](https://github.com/raghubavaraju/enterprise-order-integration-platform/blob/main/docs/decisions/ADR-003-sync-vs-async-order-creation.md).
