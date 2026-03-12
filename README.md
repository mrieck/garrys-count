# Garry's Count

This week Garry Tan (CEO of YC) posted about writing 310K lines of "hand-written source code" in 45 days.

<img src="assets/garry-tweet.jpeg" alt="Garry Tan's original post about 310K lines of hand-written source code" width="300">

I actually [defended him on X](https://x.com/prodmarkllc/status/2030435027796779288) — we don't really know all the features he shipped.

But his post got me wondering... **"Am I shipping at YC speed?"** With Garry's Count, I no longer have to guess.

### What it does

Garry's Count uses a Claude Code hook and skill to track how many lines of code Claude writes per day and display a running total in your status bar.

```
Garry's Count: 4,207 lines of hand-written source code
```

## Install

```bash
git clone https://github.com/mrieck/garryscount.git && cd garryscount && bash install.sh
```

Restart Claude Code. Start coding. Watch the number go up.

## How it works

A PostToolUse hook fires every time Claude writes or edits a file. It counts the lines and adds them to a daily tally stored at `~/.claude/garryscount/`. A status line script reads the tally and shows it in the status bar.

The daily count resets at **5am** (configurable).

## Report command

Type `/garryscount` in Claude Code to get a Garry-style breakdown report:

- Lines of code by file type, just like the tweet
- Last 7 days of daily totals
- Shipping speed label if you have a full week of data (100k+ lines = "Shipping at YC speed")

## Configuration

Edit `~/.claude/garryscount/config.json`:

```json
{
  "reset_hour": 5,
  "count_mode": "default",
  "label": "lines of hand-written source code",
  "show_directory": false
}
```

### Counting modes

| Mode | Description |
|------|-------------|
| `"default"` | **(default)** Net new lines only. For edits, subtracts old lines from new. |
| `"yc-mode"` | Every line Claude writes or modifies counts, even if it rewrites the same file. Great for VC updates. |

### Label

The text shown after the number in the status bar. Default is `"lines of hand-written source code"`. Set to `"loc"` if you want it short.

### Show directory

Set `"show_directory": true` to append your current working directory to the status bar in orange:

```
Garry's Count: 4,207 lines of hand-written source code ~/Sites/github/myproject
```

Default is `false`.

### Reset hour

The hour (0-23) when the daily count resets. Default is `5` (5am). Set to `0` for midnight reset.

## Color coding

The status bar changes color as Claude's daily output grows:

- **Green** — under 1,000 lines (warming up)
- **Yellow** — 1,000-5,000 lines (cooking)
- **Red** — 5,000-10,000 lines (on fire)
- **Magenta** — 10,000+ lines (legendary)

Note: As per best practices I haven't read any of the the code in this repo.  

## Uninstall

```bash
cd garryscount && bash uninstall.sh
```

## Requirements

- [Claude Code](https://claude.ai/code)
- `jq` (`brew install jq` on macOS)
- macOS or Linux (Windows users need [WSL](https://learn.microsoft.com/en-us/windows/wsl/install))

---

## Ship even faster with SnipCSS

If you're using Claude Code to build UI, check out [SnipCSS](https://www.snipcss.com/claude_plugin) — my Claude Code plugin that extracts CSS from any website and converts it to Tailwind instantly. 

Give your coding agent a reference website/section and get pixel-perfect Tailwind that can quickly be integrated into your project.

## License

MIT
