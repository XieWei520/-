# Sensitive Word Filtering

This reference describes a hot-path moderation design suitable for chat,
profile, group, and searchable content.

## Normalize Pipeline

Run `normalize` before matching so trivial bypasses do not defeat the filter:

1. `normalizeWidth`: fold full-width characters to half-width.
2. `normalizeCase`: lowercase and apply locale-safe Unicode mapping.
3. `normalizeWhitespace`: collapse tabs, zero-width characters, and duplicate spaces.
4. `normalizePunctuation`: strip or canonicalize separator punctuation often used for evasion.
5. `normalizeHomophone`: optionally map common phonetic substitutions for the active locale.

```go
func normalize(raw string) string {
	step1 := normalizeWidth(raw)
	step2 := normalizeCase(step1)
	step3 := normalizeWhitespace(step2)
	step4 := normalizePunctuation(step3)
	return normalizeHomophone(step4)
}
```

## Trie / DFA Matcher

Use an in-memory `Trie` or DFA automaton for O(n) scanning of normalized text.

```go
type Decision string

const (
	DecisionAllow   Decision = "allow"
	DecisionReplace Decision = "replace"
	DecisionBlock   Decision = "block"
)

func ModerateText(raw string, trie *Trie) (Decision, []string) {
	normalized := normalize(raw)
	hits := trie.FindAll(normalized)
	if len(hits) == 0 {
		return DecisionAllow, nil
	}

	if shouldReplaceOnly(hits) {
		return DecisionReplace, hits
	}

	return DecisionBlock, hits
}
```

## Hot Path Decisioning

- `DecisionAllow`: message continues to persistence and delivery.
- `DecisionReplace`: replace matched spans with masking characters and attach a
  moderation audit trail.
- `DecisionBlock`: reject the write and surface a user-visible moderation code.

## Storage And Update Strategy

- Store the canonical word list in MySQL or Redis with a monotonically
  increasing version.
- Rebuild the in-memory Trie whenever the version changes.
- Broadcast version updates over Redis pub/sub or an internal config channel so
  every gateway refreshes without restart.
- Keep a separate allowlist for product terms and branded names that would
  otherwise generate false positives.

## Moderation Audit Trail

- Persist the original raw text, normalized text, matched terms, and final
  decision in a write-only moderation log.
- Sample `DecisionReplace` events aggressively and retain every
  `DecisionBlock` event for manual review.
- Feed confirmed misses back into the dictionary build pipeline with versioned
  approvals.

## Performance Notes

- Build the Trie once per version and reuse it across requests.
- Avoid regex-heavy filtering on the hot path; regex can complement the Trie for
  rare patterns in an asynchronous review tier.
- Apply the same normalize function to chat messages, profile fields, group
  names, and searchable content to avoid policy drift.
