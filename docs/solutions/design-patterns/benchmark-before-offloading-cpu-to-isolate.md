---
title: Benchmark before Isolate.run — the data copy can cost more than the work
date: 2026-06-10
category: design-patterns
module: knowledge graph retrieval
problem_type: design_pattern
component: database
severity: medium
applies_when:
  - "Considering Isolate.run/compute to move CPU work off the main/agent isolate"
  - "The work's input is a large materialized data set (embeddings, images, parsed documents)"
  - "A per-query scan over DB-resident data is growing with data size"
tags: [isolate-run, embeddings, cosine-similarity, benchmark, keyset-pagination, performance]
---

# Benchmark before Isolate.run — the data copy can cost more than the work

## Context

The KG retrieval roadmap item said "move the O(n) cosine scan off the agent isolate with `Isolate.run()`". Dart isolates share no memory: `Isolate.run` deep-copies its captured inputs. For a 768-dim Float32 embedding scan, the input is ~2.9 MB at 1K entities and ~14.6 MB at 5K — and the plan wisely gated the choice on a benchmark instead of committing.

## Guidance

**Measure the copy + work total against the inline baseline before introducing an isolate hop.** The benchmark (`tool/benchmark_cosine_scan.dart`, plain `dart run` script, results recorded in-file):

| Scale (768-dim Float32) | Inline scan (median) | Isolate.run total (copy + scan) |
|---|---|---|
| 1,000 entities (2.9 MB) | 1.13 ms | 1.58 ms |
| 5,000 entities (14.6 MB) | 5.54 ms | 11.05 ms |

`Isolate.run` was ~2× **worse** at 5K — the blob copy dominates the cosine math. (Dev-machine numbers; a mid-range phone is ~5–10× slower with the *ratio* skewing further against the copy.)

The chosen design instead removes the reason the scan felt heavy: **keyset-paginated scanning inside the service** (`getActiveEntityEmbeddingsPage({afterId, pageSize})`, page = 500), scoring page by page with a running top-N. Memory is bounded to one page of BLOBs, no full list is ever materialized, and the silent 1000-entity cap could be deleted outright — full-KB coverage with identical scores.

Decision rule worth keeping:

- Work is heavy, input is small (parse one document, run a model) → isolate is a good fit.
- Work is light per byte, input is the whole data set (similarity scans, aggregations) → keep it where the data lives: page it, push it into SQL, or index it (`sqlite-vec`-class solutions) — don't ship megabytes across an isolate boundary per query.

## Why This Matters

`Isolate.run` reads as the canonical "fix jank" move, and applied blindly here it would have *doubled* per-turn retrieval latency while adding complexity. A 30-line throwaway benchmark prevented a regression dressed as an optimization.

## When to Apply

- Before any `Isolate.run`/`compute` adoption where captured inputs exceed ~1 MB.
- When tempted to raise a hardcoded scan cap: prefer pagination that removes the cap over a bigger cap.
- Re-benchmark if the KB realistically exceeds ~10K entities — at some scale an index (e.g., `sqlite-vec`, gated on a split-per-abi build check) beats any linear scan, paged or not.

## Examples

Paged scan with running top-N (shape, see `knowledge_service.dart:_scanEmbeddings`):

```dart
int? afterId;
while (true) {
  final page = await db.getActiveEntityEmbeddingsPage(
      afterId: afterId, pageSize: AppConstants.knowledgeEmbeddingScanPageSize);
  if (page.isEmpty) break;
  for (final row in page) { /* cosine + keep running top-N (maxCandidates) */ }
  afterId = page.last.id;
}
```

Coverage pinned by `test/knowledge/embedding_scan_coverage_test.dart` (highest-id entity beyond the old cap is found; page count asserted).

## Related

- `docs/solutions/logic-errors/knowledge-graph-retrieval-fts5-tokenization-and-semantic-gap.md` — the retrieval-quality work this scan serves (the vector path is the semantic-gap bridge).
