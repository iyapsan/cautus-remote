import Foundation

/// Fuzzy search scoring for the command palette.
///
/// Ranking: exact match > prefix > fuzzy substring.
/// Favorites and recents receive a boost.
enum FuzzySearch {
    /// Score a candidate string against a query.
    ///
    /// - Parameters:
    ///   - query: Search query (empty matches everything at base score)
    ///   - candidate: String to match against
    ///   - isFavorite: Boost score for favorites
    ///   - isRecent: Boost score for recently used items
    /// - Returns: Score (0 = no match, higher = better match)
    static func score(
        query: String,
        candidate: String,
        isFavorite: Bool = false,
        isRecent: Bool = false
    ) -> Double {
        guard !query.isEmpty else {
            // Empty query: return base score with boosts
            var base = 0.1
            if isFavorite { base += 0.3 }
            if isRecent { base += 0.2 }
            return base
        }

        let queryLower = query.lowercased()
        let candidateLower = candidate.lowercased()

        var score: Double = 0

        // Exact match
        if candidateLower == queryLower {
            score = 1.0
        }
        // Prefix match
        else if candidateLower.hasPrefix(queryLower) {
            score = 0.8
        }
        // Contains match
        else if candidateLower.contains(queryLower) {
            score = 0.5
        }
        // Fuzzy: check if all characters appear in order
        else if fuzzyMatch(query: queryLower, candidate: candidateLower) {
            score = 0.3
        }
        // No match
        else {
            return 0
        }

        // Apply boosts
        if isFavorite { score += 0.15 }
        if isRecent { score += 0.1 }

        return min(score, 1.0)
    }

    /// Check if all characters of query appear in candidate in order.
    private static func fuzzyMatch(query: String, candidate: String) -> Bool {
        var queryIndex = query.startIndex
        var candidateIndex = candidate.startIndex

        while queryIndex < query.endIndex && candidateIndex < candidate.endIndex {
            if query[queryIndex] == candidate[candidateIndex] {
                queryIndex = query.index(after: queryIndex)
            }
            candidateIndex = candidate.index(after: candidateIndex)
        }

        return queryIndex == query.endIndex
    }
}
