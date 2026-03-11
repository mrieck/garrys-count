---
name: goodnight-garry
description: Commit and push all repos worked on today, then show a summary
disable-model-invocation: true
---

# Goodnight, Garry

Here are the repos worked on today:

```json
!`~/.claude/garryscount/goodnight-report.sh 2>/dev/null || echo '{"error":"No data found. Is Garry'\''s Count installed and have you written any code today?"}'`
```

## Instructions

Commit and push all repos that need it. Work through each path in the `repos` array. Follow these rules exactly:

### For each repo

1. Run `git -C {path} status --short` to check its state
2. If the directory doesn't exist or the git command fails: report "Skipped (not found)"
3. If the working tree is dirty (status output is non-empty):
   - Run `git -C {path} add -A`
   - Run `git -C {path} commit -m "WIP: goodnight commit"`
   - If commit fails, report the error and move to the next repo
4. Check for unpushed commits: `git -C {path} rev-list @{u}..HEAD --count 2>/dev/null || echo "no-upstream"`
5. If the result is a number > 0 or "no-upstream":
   - Check if a remote exists: `git -C {path} remote`
   - If no remote: report "Committed (no remote)" and move on
   - Try: `git -C {path} push`
   - If push fails (no upstream set): try `git -C {path} push --set-upstream origin $(git -C {path} rev-parse --abbrev-ref HEAD)`
   - If push still fails: report the error
6. If status was clean and no unpushed commits: report "Already up to date"

### Final summary

After processing all repos, output a markdown table:

| Repo | Action |
|------|--------|

- **Repo**: show only the last 2 path components (e.g. `github/myapp`)
- **Action**: one of "Committed + pushed", "Pushed", "Already up to date", "Committed (no remote)", "Skipped", or "Error: {message}"

If `repos` is empty or there's an error in the JSON, say: "No repos tracked today. Write some code first!"
