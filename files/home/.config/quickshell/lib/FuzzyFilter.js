.pragma library
.import "FuzzySort.js" as FuzzySort

// Shared FuzzySort.go wrapper. Options pass through untouched so every
// caller keeps its exact semantics (threshold/limit/all/keys/scoreFn).
// pick selects the per-result extraction: "obj" (default), "target",
// "raw" (unmapped Result objects), or a function.
function search(query, pool, options) {
    options = options || {};
    const results = FuzzySort.go(query, pool, {
        threshold: options.threshold ?? 0,
        limit: options.limit ?? 999,
        all: options.all ?? true,
        keys: options.keys,
        scoreFn: options.scoreFn
    });
    const pick = options.pick ?? "obj";
    if (pick === "raw")
        return results;
    if (typeof pick === "function")
        return results.map(pick);
    return results.map(item => item[pick]);
}
