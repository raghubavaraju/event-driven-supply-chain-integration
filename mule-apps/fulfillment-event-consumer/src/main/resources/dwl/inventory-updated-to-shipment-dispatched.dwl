/**
 * STATUS: Working example DataWeave transformation.
 * Maps the fictional warehouse management system's dispatch confirmation, combined
 * with the triggering InventoryUpdated event, into a ShipmentDispatched event
 * (../../../event-schemas/shipment-dispatched.v1.schema.json).
 *
 * Input: vars.inventoryUpdatedEvent (triggering event), payload (warehouse API response)
 */
%dw 2.0
output application/json
---
{
    eventId: uuid(),
    eventType: "ShipmentDispatched",
    schemaVersion: "1.0",
    correlationId: vars.inventoryUpdatedEvent.correlationId,
    occurredAt: now(),
    orderId: vars.inventoryUpdatedEvent.orderId,
    shipmentId: payload.shipmentId,
    carrier: payload.carrier,
    trackingNumber: payload.trackingNumber,
    estimatedDeliveryDate: payload.estimatedDeliveryDate
}
