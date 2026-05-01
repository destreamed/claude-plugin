---
description: Search Destreamed for prior solutions to a problem before re-solving it from scratch. Run this whenever the user reports an error, bug, regression, or unexpected behavior.
---

# Destreamed Search

Before reasoning about a fresh fix, check whether the team has solved this before.

1. Extract 2–4 keywords from the problem description (error message tokens, component name, symptom). Avoid filler words.
2. Call `mcp__destreamed__search` with those keywords.
3. If matches return: read the most relevant beats and their echoes. Reference any existing solution in your reply rather than re-deriving it. Cite the beat (link or ID) so the user can follow up.
4. If nothing matches: proceed with normal investigation — but post the eventual fix as an echo on the active task beat so the next tuner finds it.

## When to skip

- The user explicitly says they don't want the search ("just fix it", "don't check first").
- The problem is trivially obvious (typo, missing import the user already pointed at).
