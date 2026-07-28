> **Document type: Architecture documentation (operational runbook)**

# Operational Runbook

## 1. Consumer Lag Alert

**Symptom:** Monitoring signal fires for sustained consumer lag growth on a topic/partition (see [observability-and-monitoring.md](observability-and-monitoring.md)).

1. Check the affected consumer's health (is it running, is it crash-looping, is CPU/memory saturated).
2. If the consumer is healthy but slow, check for a downstream dependency slowdown (e.g., the Inventory consumer's database) via its own timeout/circuit-breaker logs.
3. If the consumer is unhealthy, restart it — safe by design, since redelivered messages are deduplicated (see [idempotency-and-deduplication.md](idempotency-and-deduplication.md)).
4. If lag persists after a healthy restart, consider scaling out consumer instances within the same consumer group (bounded by partition count — see [ADR-002](decisions/ADR-002-event-ordering-and-partitioning.md); you cannot usefully add more consumer instances than partitions).

## 2. Non-Empty Dead-Letter Queue

**Symptom:** DLQ depth alert fires for a `*.dlq` topic.

1. Inspect the DLQ messages' `failureReason` field (see [error-handling-dlq-and-recovery.md](error-handling-dlq-and-recovery.md) for the message shape).
2. If `SCHEMA_VALIDATION_FAILED`: check whether a producer was recently deployed with a breaking, undocumented change — coordinate a producer fix, not a consumer workaround.
3. If a business-rule failure (e.g., unknown SKU): route to the relevant data-owning team for correction.
4. Once root cause is resolved, re-publish the DLQ message(s) to the original topic **preserving the original `eventId`** so downstream idempotency treats it as the original event, not a new one.
5. Do not purge a DLQ topic without either successful reprocessing of every message or an explicit, logged decision (who, when, why) to discard specific messages.

## 3. Suspected Bad Deployment Processed Events Incorrectly

**Symptom:** A consumer deployed within the last N hours is suspected of processing events incorrectly (e.g., a DataWeave bug silently mis-mapped a field).

1. Roll back the consumer deployment first — stop the bleeding before investigating further.
2. Identify the time window during which the bad version was running (deployment timestamps + consumer group offset history).
3. Reset the consumer group's offset to the last known-good point before that window.
4. Restart the consumer on the corrected version; it will reprocess the affected window — safe due to idempotent processing.
5. For any downstream event already published based on incorrect processing, evaluate whether a compensating event is needed (this is a business decision, not purely technical, and is out of scope for this runbook to resolve unilaterally).

## 4. Planned Event Replay (Analytics Backfill)

**Symptom:** Analytics needs to rebuild a downstream dataset from a point in the past.

1. Confirm the required window is within the topic's configured retention (see [event-flow-and-design.md](event-flow-and-design.md) for retention targets).
2. Reset the Analytics consumer group's offset to the desired starting point.
3. Restart the Analytics consumer; it reprocesses from that point forward.
4. This procedure is isolated to the Analytics consumer group and does not affect any operational consumer (Inventory, Fulfillment, Notification), since each has its own independent consumer group and offset.

## 5. Suspected Message Loss

**Symptom:** A downstream system did not receive an expected event.

1. Confirm the event was actually published (check the producer's logs for a successful publish acknowledgment, keyed by `correlationId`/`eventId`).
2. If published but not consumed, check the relevant consumer's offset position relative to the message — it may simply be lagging (see Runbook Item 1) rather than having lost the message.
3. Kafka retains messages for the configured retention window regardless of consumer state — genuine message loss (not lag) should only be possible from a misconfiguration (e.g., retention set too short) or an infrastructure-level incident, and should be treated as a priority investigation if confirmed.
