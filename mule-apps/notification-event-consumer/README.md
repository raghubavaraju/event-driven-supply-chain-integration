# notification-event-consumer/

**STATUS: Pseudocode.** This app is intentionally not fully re-implemented, since it would be structurally identical to `inventory-event-consumer` and `fulfillment-event-consumer` (Kafka consumer + idempotency check via Object Store + DLQ error handler) with a different payload and side effect. It's described here to complete the architecture picture without padding the repository with a fourth near-duplicate flow.

## Intended Structure (same shape as the other consumers)

```
notification-event-consumer/
├── pom.xml                      (same dependencies as fulfillment-event-consumer, minus DB connector)
├── mule-artifact.json
└── src/main/
    ├── mule/notification-event-consumer.xml
    └── resources/
        ├── dwl/event-to-notification.dwl
        └── config/config-placeholder.yaml
```

## Intended Flow Logic (pseudocode)

```
flow consume-shipment-and-fulfillment-events:
    listen to topics: shipment.dispatched.v1, fulfillment.completed.v1
      (two Kafka listener sources feeding the same idempotency-checked processing logic)

    parse event, capture correlationId, eventId, Kafka offset metadata

    if eventId already in notificationProcessedEventsStore (Object Store):
        log "duplicate, skipping" and commit offset
    else:
        map event -> customer notification payload (DataWeave)
        call Notification Service API (templated message per eventType:
            ShipmentDispatched -> "Your order has shipped" template
            FulfillmentCompleted -> "Your order was delivered" template)
        store eventId in notificationProcessedEventsStore
        commit offset

    error-handler ref="dlq-error-handler"
        (same DLQ routing pattern as the other two consumers, targeting
         shipment.dispatched.v1.dlq / fulfillment.completed.v1.dlq respectively)
```

This mirrors the working, fully-implemented pattern in [`../inventory-event-consumer/`](../inventory-event-consumer) and [`../fulfillment-event-consumer/`](../fulfillment-event-consumer) — those two are the ones to review for actual working Mule 4 XML syntax.
