# mule-apps/

Standard Mule 4 / Maven project structures for the event-driven supply chain platform.

```
mule-apps/
├── common/
│   └── dlq-error-handler.xml         ← STATUS: working example, shared DLQ-routing error handler
├── order-event-producer/             ← publishes OrderCreated (triggered by the companion project's Order Process API)
│   ├── pom.xml, mule-artifact.json
│   └── src/main/{mule,resources/{dwl,config}}
├── inventory-event-consumer/         ← consumes OrderCreated, publishes InventoryUpdated
│   └── (same shape)
├── fulfillment-event-consumer/       ← consumes InventoryUpdated, publishes ShipmentDispatched + FulfillmentCompleted
│   ├── (same shape)
│   └── src/test/munit/               ← fully worked MUnit example
└── notification-event-consumer/      ← consumes ShipmentDispatched/FulfillmentCompleted
    └── STATUS: pseudocode — structure and flow logic only, to illustrate the pattern
        without fully re-implementing a fourth near-identical consumer
```

Every consumer imports `common/dlq-error-handler.xml`, which classifies errors per [`../docs/error-handling-dlq-and-recovery.md`](../docs/error-handling-dlq-and-recovery.md) and routes non-retryable failures to that topic's `.dlq` topic.
