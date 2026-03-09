---
name: garryscount
description: Generate a Garry's Count LOC report showing lines of code written today and this week
disable-model-invocation: true
---

# Garry's Count Report

Here is the raw report data:

```json
!`~/.claude/garryscount/report.sh 2>/dev/null || echo '{"error":"No data found. Is Garry'\''s Count installed?"}'`
```

## Instructions

Format this data as a report. Follow these rules exactly:

1. **Header**: "Garry's Count Report - {today's date}"

2. **Today's Breakdown** table (if `by_extension` has entries):
   - Map file extensions to language names using these common mappings:
     - `.rb` = Ruby, `.ts` = TypeScript, `.tsx` = TypeScript (TSX), `.js` = JavaScript, `.jsx` = JavaScript (JSX)
     - `.py` = Python, `.sh` = Shell, `.css` = CSS, `.html` = HTML, `.json` = JSON, `.md` = Markdown
     - `.go` = Go, `.rs` = Rust, `.java` = Java, `.erb` = ERB templates, `.yml`/`.yaml` = YAML
     - `.sql` = SQL, `.swift` = Swift, `.kt` = Kotlin, `.c` = C, `.cpp` = C++, `.h` = C/C++ Header
     - For unknown extensions, show the extension as-is
   - Show as a markdown table with "Breakdown" and "LOC" columns (like Garry's tweet)
   - Sort by LOC descending
   - Format numbers with comma separators (e.g., 1,500)
   - Include a **Total** row at the bottom
   - If no `by_extension` data exists, just show the total

3. **Last 7 Days** table:
   - Show each day with date and LOC
   - Include a **Total** row
   - Format numbers with comma separators

4. **Shipping speed** (only if `has_full_week` is true OR `days_with_data` >= 7):
   - If weekly total >= 100,000: show "🚀 Shipping at YC speed"
   - If weekly total < 100,000: show "🏗️ Keep shipping"

5. **Count mode note**: At the bottom, show "Mode: {count_mode}" in italics

6. If there's an error or no data, show a friendly message suggesting to install Garry's Count or write some code first.
