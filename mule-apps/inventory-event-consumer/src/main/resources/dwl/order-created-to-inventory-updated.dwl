/**
 * STATUS: Working example DataWeave transformation.
 * Maps an OrderCreated event + the resulting DB stock query result into an
 * InventoryUpdated event (../../../event-schemas/inventory-updated.v1.schema.json).
 * One InventoryUpdated event is published per line item.
 *
 * Input: vars.orderCreatedEvent (the consumed OrderCreated event)
 *        vars.stockResults (array, one row per SKU, from the DB update query)
 */
%dw 2.0
output application/json
---
vars.orderCreatedEvent.lineItems map (lineItem) -> do {
    var stockRow = (vars.stockResults filter ($.sku == lineItem.sku))[0]
    ---
    {
        eventId: uuid(),
        eventType: "InventoryUpdated",
        schemaVersion: "1.0",
        correlationId: vars.orderCreatedEvent.correlationId,
        occurredAt: now(),
        sku: lineItem.sku,
        orderId: vars.orderCreatedEvent.orderId,
        quantityDelta: -lineItem.quantity,
        availableQuantity: stockRow.availableQuantity,
        replenishmentTriggered: stockRow.availableQuantity < 10
    }
}
