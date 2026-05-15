# claude-skills

A version-controlled collection of personal [Claude Code](https://claude.ai/code) skills, synced across devices via git.

Each skill is a slash command that can be invoked inside Claude Code (e.g. `/tdd`, `/grill-me`). Skills live in this repo as plain markdown files and are wired into Claude Code's plugin cache via symlinks, so edits here are reflected immediately — no reinstall needed.

---

## Setup on a new device

Clone the repo and run the setup script. That's it.

```bash
git clone <your-repo-url> ~/Documents/Projects/claude-skills
cd ~/Documents/Projects/claude-skills
./setup.sh
```

The script creates the necessary plugin cache directories and symlinks each `SKILL.md` into `~/.claude/plugins/cache/local/`. It also registers each skill in `~/.claude/plugins/installed_plugins.json` so Claude Code discovers them on next launch.

### What the setup script does

For each skill directory in this repo, it:

1. Creates `~/.claude/plugins/cache/local/<skill>/1.0.0/skills/<skill>/`
2. Symlinks `<repo>/<skill>/SKILL.md` → that path
3. Writes a minimal `.claude-plugin/plugin.json` (name + version)
4. Registers the plugin in `installed_plugins.json`

### Syncing to an existing device

```bash
git pull
./setup.sh   # safe to re-run; skips skills already linked
```

---

## Skills

| Skill | Invoke with | Purpose |
|-------|-------------|---------|
| [tdd](tdd/SKILL.md) | `/tdd` | Test-driven development — enforces red→green→refactor, one vertical slice at a time |
| [grill-me](grill-me/SKILL.md) | `/grill-me` | Relentless design interrogation — walks every branch of a decision tree until you reach shared understanding |
| [handoff](handoff/SKILL.md) | `/handoff` | Compacts the current conversation into a handoff document for the next session or agent |

---

## Adding a new skill

```bash
mkdir my-skill
cat > my-skill/SKILL.md << 'EOF'
---
name: my-skill
description: One line explaining when to invoke this skill.
---

The prompt Claude will run when /my-skill is invoked.
EOF

./setup.sh          # registers and links the new skill
git add my-skill/
git commit -m "add my-skill"
git push
```

Then on other devices: `git pull && ./setup.sh`.

---

## Repo structure

```
claude-skills/
├── README.md
├── setup.sh           # wires skills into ~/.claude on any machine
├── grill-me/
│   └── SKILL.md
├── handoff/
│   └── SKILL.md
└── tdd/
    └── SKILL.md
```

The plugin cache Claude Code reads from sits at:

```
~/.claude/plugins/cache/local/<skill>/1.0.0/skills/<skill>/SKILL.md
```

`setup.sh` bridges the gap between this repo's flat layout and that nested structure using symlinks.
