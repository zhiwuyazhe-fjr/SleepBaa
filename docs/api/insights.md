# Insights API

## Owner

- Extended content teammate

## Facade

- `InsightsFacade.interferenceInsights`
- `InsightsFacade.currentReport`
- `InsightsFacade.refresh()`

## Derived inputs

- Sleep sessions
- Dorm events and dorm state
- Dream entries

## Cloud data

- No dedicated source-of-truth collection in v1
- Optional future materialization: `report_snapshots/{snapshotId}`

## Integration notes

- Keep reports and interference rankings derived until query cost becomes a real problem
- UI should treat these outputs as read models, not mutable documents
