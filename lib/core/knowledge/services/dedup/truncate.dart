/// Truncate [s] to [maxLen] characters, appending `...` when cut.
///
/// Shared by the dedup collaborators (CandidateGenerator fact summaries,
/// DedupLlmVerifier prompt sanitization) — the copies were byte-identical.
String truncate(String s, int maxLen) =>
    s.length <= maxLen ? s : '${s.substring(0, maxLen)}...';
