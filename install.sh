#!/usr/bin/env bash
# LearnForge one-line installer for Linux / macOS.
#   LEARNFORGE_ZIP=https://YOUR-HOST/learnforge.zip bash -c "$(curl -fsSL https://YOUR-HOST/install.sh)"
set -euo pipefail

ZIP="${LEARNFORGE_ZIP:-}"
DEST="${LEARNFORGE_DIR:-$HOME/learnforge}"
step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
die()  { printf '\033[31m%s\033[0m\n' "$1" >&2; exit 1; }
# read answers from the terminal even when the script itself was piped in
ask()  { local a=""; if [ -r /dev/tty ]; then read -r -p "$1" a </dev/tty || true; fi; printf '%s' "$a"; }

[ -n "$ZIP" ] || die 'Set LEARNFORGE_ZIP to the learnforge.zip link (or a local path).'

step 'Checking Node.js (v22+ required)'
node_ok() { command -v node >/dev/null 2>&1 && [ "$(node -p 'process.versions.node.split(".")[0]')" -ge 22 ]; }
if ! node_ok; then
  if [ -s "$HOME/.nvm/nvm.sh" ] || curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; then
    export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
    nvm install 22 && nvm use 22
  fi
  node_ok || die 'Node.js 22+ is required. Install it from https://nodejs.org and run this again.'
fi
command -v unzip >/dev/null 2>&1 || die 'Please install unzip first (e.g. sudo apt install unzip).'

step "Downloading LearnForge to $DEST"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if [ -f "$ZIP" ]; then cp "$ZIP" "$tmp/lf.zip"; else curl -fsSL "$ZIP" -o "$tmp/lf.zip"; fi
unzip -q "$tmp/lf.zip" -d "$tmp/x"
src="$tmp/x"; [ -d "$tmp/x/learnforge" ] && src="$tmp/x/learnforge"
mkdir -p "$DEST"; cp -R "$src"/. "$DEST"/
cd "$DEST"

step 'Installing and building (about a minute)'
npm run setup

if [ ! -f .env ]; then
  step 'Choose how LearnForge talks to Claude'
  echo '  1) Claude Pro/Max subscription (log in with your claude.ai account)'
  echo '  2) Anthropic API key (pay-as-you-go)'
  echo '  3) Offline mode (no AI, simple demo lessons)'
  case "$(ask 'Type 1, 2 or 3: ')" in
    1)
      if ! command -v claude >/dev/null 2>&1; then
        echo 'Installing Claude Code...'
        npm install -g @anthropic-ai/claude-code || sudo npm install -g @anthropic-ai/claude-code
      fi
      echo; echo 'A login prompt will open. Sign in with your Claude account, then type /exit to continue.'
      claude </dev/tty || true
      echo 'LF_PROVIDER=claude-code' > .env ;;
    2) key="$(ask 'Paste your Anthropic API key: ')"; echo "ANTHROPIC_API_KEY=$key" > .env ;;
    *) echo 'ANTHROPIC_API_KEY=' > .env ;;
  esac
fi

step 'Starting LearnForge at http://localhost:8787  (Ctrl+C to stop)'
(command -v xdg-open >/dev/null && xdg-open http://localhost:8787 || command -v open >/dev/null && open http://localhost:8787) >/dev/null 2>&1 || true
exec npm start
