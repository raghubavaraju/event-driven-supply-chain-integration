/**
 * STATUS: Working example DataWeave transformation.
 * Maps an OrderSummary (from the companion project's Order Process API, see
 * enterprise-order-integration-platform/api-specs/order-process-api.raml) to the
 * OrderCreated event schema (../../../event-schemas/order-created.v1.schema.json).
 */
%dw 2.0
output application/json
import * from dw::core::Strings
---
{
    eventId: uuid(),
    eventType: "OrderCreated",
    schemaVersion: "1.0",
    correlationId: vars.correlationId,
    occurredAt: now(),
    orderId: payload.orderId,
    customerId: payload.customer.customerId default payload.customerId,
    lineItems: payload.lineItems map (li) -> {
        sku: li.sku,
        quantity: li.quantity
    }
}
