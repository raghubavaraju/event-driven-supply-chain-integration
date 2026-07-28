> **Document type: Architecture documentation** — fictional scenario, no proprietary information. See [Fictional Scenario Disclosure](../README.md#fictional-scenario-disclosure) in this repository's README.

# Business Scenario

## Fictional Enterprise: Northbridge Consumer Products — Supply Chain Platform

This project extends the same fictional enterprise used in the companion project, [`enterprise-order-integration-platform`](https://github.com/raghubavaraju/enterprise-order-integration-platform), into its supply chain and fulfillment operations.

## The Problem

Once an order is created (via the Order Process API in the companion project), several independent systems need to react to it and to each other's downstream events:

- **Inventory Management** must decrement available stock and, if stock falls below a threshold, trigger a replenishment signal.
- **Fulfillment / Warehouse Management** must pick, pack, and dispatch the shipment once inventory is confirmed.
- **Customer Notification** must inform the customer at each meaningful state change (order confirmed, shipped, delivered).
- **Analytics / Reporting** must ingest every state change for supply chain visibility dashboards, independent of the operational systems.

Modeling this as a chain of **synchronous REST calls** (as the companion project does for order creation) would be the wrong fit here, for reasons specific to this part of the platform:

1. **Multiple independent consumers of the same event.** Inventory update, notification, and analytics all need to know when an order is created — a synchronous caller would have to call each one directly, or the Inventory service would have to know about and call Notification and Analytics, coupling systems that shouldn't need to know about each other.
2. **Unbounded/variable processing time.** Warehouse picking and dispatch is a physical-world process; it does not complete within an HTTP request's reasonable timeout window.
3. **New consumers should not require producer changes.** Adding a new downstream capability (e.g., a future fraud-detection service reacting to order events) should not require changing the Order Process API or the Inventory service.
4. **Systems must tolerate downstream unavailability.** If Notification is down, order processing and fulfillment must not stop.

These four properties are the textbook case for **event-driven, asynchronous integration** — the direct counterpart to [ADR-003 in the companion project](https://github.com/raghubavaraju/enterprise-order-integration-platform/blob/main/docs/decisions/ADR-003-sync-vs-async-order-creation.md), which explains why order *creation* itself remains synchronous while everything *downstream* of order creation is event-driven.

## Event Flow (Narrative)

1. `OrderCreated` is published when the Order Process API successfully creates an order.
2. The Inventory service consumes `OrderCreated`, decrements stock, and publishes `InventoryUpdated`.
3. The Fulfillment service consumes `InventoryUpdated`, orchestrates picking/packing, and publishes `ShipmentDispatched` and later `FulfillmentCompleted`.
4. Notification and Analytics independently consume whichever events are relevant to them, without the producers knowing they exist.

A full sequence and topic/queue design is in [`event-flow-and-design.md`](event-flow-and-design.md); the diagram is in [`../diagrams/architecture-overview.mmd`](../diagrams/architecture-overview.mmd).

## Why This Scenario Was Chosen

It reflects the general shape of real manufacturing/supply-chain event flows (inventory, order, shipment, fulfillment) without describing any specific real employer's systems, topics, schemas, or data — see the fictional-scenario disclosure linked above.
