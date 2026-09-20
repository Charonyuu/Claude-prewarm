# Claude Prewarm

A macOS menu bar app that fires one tiny Claude Haiku request before your workday starts,
so your first 5-hour usage window opens early instead of when you sit down.

```
09:00 work start  →  2 hours before  →  07:00 warm  →  ~12:00 next window
```

It does not add quota. It only moves the window earlier.

```
100% local.
No API keys.
No telemetry.
```

## Requirements

- macOS 14 or later
- Claude Code CLI installed and signed in (`claude` in your PATH)

## Build and install

```bash
./build.sh            # builds build/Claude Prewarm.app (universal)
./build.sh --install  # also copies it to /Applications and launches it
./build.sh --release  # Developer ID signature, dmg, notarization, staple
```

Install into `/Applications` before turning on **Launch at login** — `SMAppService`
refuses to register an app running from a build folder.

## Verify

```bash
./Tools/verify.sh
```

Checks the schedule maths (weekend skipping, no back-fill, offsets crossing midnight,
validation) and the `/usage` parser, then performs one real warm and one real usage
read through the CLI.

## How it works

| Piece | Behaviour |
|---|---|
| Limits block | `claude -p "/usage"`, parsed into the 5-hour and weekly windows; refreshed every 10 minutes, when the panel opens (if over a minute old) and after every warm |
| Reset shown | The real session reset from `/usage`; falls back to `last warm + 5h` when that is unavailable |
| Warm command | `claude -p "Reply only OK." --model haiku --effort low --no-session-persistence --strict-mcp-config --disable-slash-commands` |
| Working directory | An empty temp folder, so no project files or `CLAUDE.md` are read |
| Binary lookup | `command -v claude` through a login shell, then the usual install paths |
| Timeout | 30 seconds, then the process is terminated |
| Next warm | First enabled weekday whose `workStart - offset` is still in the future; a time that already passed today is never back-filled |
| Duplicate guard | No second warm within 10 minutes; `Warm Now` is disabled during that window |
| Wake recovery | If a warm was missed while asleep and it is under 60 minutes late on a work day, it runs on wake; otherwise it is skipped |
| Notifications | Failures only |
| Storage | `UserDefaults`, plus the last 20 warm log entries |

## Structure

```
Sources/ClaudePrewarm/
├── App/          ClaudePrewarmApp, AppState, SettingsWindowController
├── Models/       AppSettings, RuntimeState, WarmLog, UsageSnapshot
├── Services/     ClaudeRunner, UsageReader, ProcessRunner, ScheduleService,
│                 LoginItemService, SettingsStore, NotificationService
├── Views/        MenuBarView, SettingsView, Theme
└── Utilities/    DateCalculator, ClaudeBinaryFinder
```

## Panel

```
Claude Prewarm
● Active
─────────────────────────────
Next warmup        Tomorrow 07:00
Work starts                 09:00
Claude resets around        19:10
[ ▶ Warm Now ]
─────────────────────────────
5h limit                 59% used
▬▬▬▬▬▬▭▭▭▭▭▭  resets 19:10
Weekly limit             83% used
▬▬▬▬▬▬▬▬▬▬▭▭  resets Tomorrow 04:59
─────────────────────────────
Settings…
Quit
```

The bar fills with what has been spent. It turns amber past 70% and red past 90%.

## Menu bar states

| Dot | Meaning |
|---|---|
| Active | Scheduled and ready |
| Warming… | A request is in flight |
| Setup Required | `claude` not found |
| Error | Last warm failed; the reason is shown in the panel |

## Releasing

`./build.sh --release` signs with Developer ID under the hardened runtime,
packages a dmg, notarizes it and staples the ticket.

Notarization needs credentials in the keychain once. Generate an app-specific
password at [appleid.apple.com](https://appleid.apple.com) (Sign-In and Security
› App-Specific Passwords), then:

```bash
xcrun notarytool store-credentials "prewarm-notary" \
    --apple-id "<your Apple ID>" \
    --team-id XADL3RD65Y \
    --password "<app-specific password>"
```

Without it the script still produces a signed dmg and tells you what is missing.
An unnotarized dmg triggers Gatekeeper, so ship notarized builds only.

## Licence

MIT. See [LICENSE](LICENSE).

Not affiliated with Anthropic. "Claude" is a trademark of Anthropic, PBC.
