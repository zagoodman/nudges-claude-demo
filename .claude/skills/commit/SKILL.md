---
name: commit
description: Commit current changes to git without co-author line
---

Commit current changes to git.

1. Run `git status` and `git diff` in parallel with `git log --oneline -5` to understand what changed and follow the existing commit message style.
2. Stage all modified files by name (do not use `git add -A` or `git add .`).
3. Write a concise commit message (1-2 sentences) focused on the "why". Do NOT include any Co-Authored-By line.
4. Commit and run `git status` to confirm success.
