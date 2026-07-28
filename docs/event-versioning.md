> **Document type: Architecture documentation**

# Event Versioning Strategy

## Approach

Each event type carries its version in both the **topic name** and the **event payload** (`schemaVersion` field), e.g., topic `order.created.v1`, payload `"schemaVersion": "1.0"`.

| Change type | Example | Versioning action |
|---|---|---|
| Additive, backward-compatible | New optional field added to the event payload | No topic change; consumers ignore unknown fields by design (see below) |
| Breaking change | Field removed, field type changed, field semantics changed | New topic (`order.created.v2`), published in parallel with `v1` during a migration window |

## Consumer Tolerance Rules

Every consumer in this platform is written to **ignore unrecognized fields** in an event payload rather than fail on them (a standard "tolerant reader" pattern) — this is what makes additive changes genuinely non-breaking in practice, not just in principle.

## Migration Pattern for a Breaking Change

1. Producer begins publishing both `v1` and `v2` events to their respective topics (dual-write).
2. Consumers migrate to `v2` on their own schedule.
3. Once all known consumers have migrated (confirmed via consumer group monitoring, not assumption), the producer stops publishing `v1`.
4. `v1` topic is retained (not deleted) for the remainder of its retention window in case of a late-discovered dependency, then archived per data retention policy.

## Schema Definitions

The JSON Schema-style definitions for each event type, including the `schemaVersion` field, are in [`../event-schemas/`](../event-schemas) — treated as the source of truth for what fields exist for each version, analogous to how RAML is the source of truth for REST contracts in the companion project.
