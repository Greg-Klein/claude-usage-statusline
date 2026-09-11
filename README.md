# claude-usage-statusline

ASCII loader bars for [Claude Code](https://code.claude.com) usage, rendered in
the status line. The filled part of each bar is the quota you have **burned**, so
the bar fills up as you work.

```
Sonnet 5 · ~/dev/project
5h  [▉▉▉▉▉▉▉▋░░░░░░░░░░░░░░░░]  32%  eta 2h0m
7d  [▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉▉░░░]  88%  eta 3d22h
```

- **line 1** — model name and current directory (relative to `$HOME`)
- **5h** — rolling 5-hour rate-limit window
- **7d** — weekly rate-limit window
- **ctx** — context-window usage, shown only as a fallback when rate-limit data
  isn't available

Bars are green, turn yellow at 60% consumed and red at 85%. `eta` is the time
until that window resets.

## Preview

```sh
./preview.sh          # default sample data
./preview.sh 15 55    # 5h at 15%, 7d at 55%
```

## Requirements

- `bash`
- [`jq`](https://jqlang.org/) — `brew install jq` / `apt install jq`
- The `5h` and `7d` bars need a **Claude.ai Pro or Max** subscription and appear
  only after the first API response in a session. Without them you get the `ctx`
  line.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Greg-Klein/claude-usage-statusline/main/install.sh | bash
```

That copies the script to `~/.claude/statusline.sh` and adds the `statusLine`
block to `~/.claude/settings.json` (the old file is backed up next to it, other
settings are left alone). Re-run it any time to update. Needs `jq` and `curl`.

Tweak it with environment variables:

```sh
curl -fsSL https://raw.githubusercontent.com/Greg-Klein/claude-usage-statusline/main/install.sh \
  | BAR_WIDTH=32 REFRESH=0 bash
```

| Variable            | Default     | Meaning                                        |
| ------------------- | ----------- | ---------------------------------------------- |
| `CLAUDE_CONFIG_DIR` | `~/.claude` | Where to install                               |
| `BAR_WIDTH`         | `24`        | Bar length, written into the `command`         |
| `REFRESH`           | `10`        | `refreshInterval` in seconds, `0` to leave out |

`refreshInterval` keeps the `eta` countdown moving while the session is idle.

Claude Code reloads settings automatically, so just start or resume a session.

<details>
<summary>Manual install</summary>

1. Copy the script somewhere stable and make it executable:

   ```sh
   mkdir -p ~/.claude
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Add it to `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh",
       "padding": 0,
       "refreshInterval": 10
     }
   }
   ```

</details>

## Configuration

Override with environment variables (e.g. set them in the `command`:
`"command": "CLAUDE_BAR_WIDTH=32 ~/.claude/statusline.sh"`):

| Variable            | Default | Meaning                          |
| ------------------- | ------- | -------------------------------- |
| `CLAUDE_BAR_WIDTH`  | `24`    | Bar length in cells             |
| `CLAUDE_BAR_WARN`   | `60`    | % consumed that turns bars yellow |
| `CLAUDE_BAR_CRIT`   | `85`    | % consumed that turns bars red   |

For anything else (glyphs, colors, which lines show), edit the script — it's
short and commented.

## How it works

Claude Code pipes a JSON blob to the script on stdin on every update
(new message, `/compact`, the `refreshInterval` timer, a rate-limit window
reset). The script reads `rate_limits.*`, `context_window.*`, `model` and
`workspace` from it and prints the bars. It runs locally and costs no tokens.

Full field reference: <https://code.claude.com/docs/en/statusline>

## Uninstall

Delete the `statusLine` block from `settings.json` (or run `/statusline` and ask
Claude Code to remove it).

## License

MIT
