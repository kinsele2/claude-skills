#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_CACHE="$HOME/.claude/plugins/cache/local"
INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

# Ensure installed_plugins.json exists with the right shape
if [[ ! -f "$INSTALLED_PLUGINS" ]]; then
  echo '{"version": 2, "plugins": {}}' > "$INSTALLED_PLUGINS"
fi

for skill_dir in "$REPO_DIR"/*/; do
  skill="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"

  [[ -f "$skill_md" ]] || continue

  target_dir="$PLUGIN_CACHE/$skill/1.0.0/skills/$skill"
  plugin_meta="$PLUGIN_CACHE/$skill/1.0.0/.claude-plugin"
  plugin_json="$plugin_meta/plugin.json"
  target_link="$target_dir/SKILL.md"

  mkdir -p "$target_dir" "$plugin_meta"

  # Write plugin.json if missing
  if [[ ! -f "$plugin_json" ]]; then
    cat > "$plugin_json" << JSON
{
  "name": "$skill",
  "version": "1.0.0",
  "description": "$(grep -m1 '^description:' "$skill_md" | sed 's/^description: *//' || echo "$skill skill")"
}
JSON
  fi

  # Symlink SKILL.md (skip if already correct)
  if [[ -L "$target_link" && "$(readlink "$target_link")" == "$skill_md" ]]; then
    echo "  already linked: $skill"
  else
    ln -sf "$skill_md" "$target_link"
    echo "  linked: $skill"
  fi

  # Register in installed_plugins.json if not present
  if ! python3 -c "
import json, sys
data = json.load(open('$INSTALLED_PLUGINS'))
key = '${skill}@local'
sys.exit(0 if key in data.get('plugins', {}) else 1)
" 2>/dev/null; then
    python3 << PYEOF
import json
path = '$INSTALLED_PLUGINS'
data = json.load(open(path))
data.setdefault('plugins', {})
data['plugins']['${skill}@local'] = [{
    'scope': 'user',
    'installPath': '$PLUGIN_CACHE/$skill/1.0.0',
    'version': '1.0.0',
    'installedAt': '$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")',
    'lastUpdated': '$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")'
}]
json.dump(data, open(path, 'w'), indent=2)
print('  registered: $skill')
PYEOF
  fi
done

echo ""
echo "Done. Restart Claude Code to pick up any new skills."
