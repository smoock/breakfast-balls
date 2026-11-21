#!/usr/bin/env bash
# Run from any directory in a Linux Codex Cloud setup session.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo "This installer targets Linux x86_64 Codex Cloud environments." >&2
  exit 1
fi

if ! command -v node >/dev/null || [[ "$(node -p 'process.versions.node.split(".")[0]')" != 22 ]]; then
  if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
    source "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
    nvm install 22
    nvm use 22
    nvm alias default 22
  else
    echo "Install/select Node.js 22 in the cloud environment, then rerun this script." >&2
    exit 1
  fi
fi

export PATH="$HOME/.local/bin:$PATH"
python3 tools/install_cloud_godot.py
npm ci
# Cloud task users may lack root access; the base image already provides browser libraries.
if [[ "$(id -u)" == 0 ]] || { command -v sudo >/dev/null && sudo -n true 2>/dev/null; }; then
  npx playwright install --with-deps chromium
else
  npx playwright install chromium
fi
# Fail with Playwright's missing-library diagnostics if this base image isn't sufficient.
node --input-type=module -e 'import { chromium } from "playwright"; const browser = await chromium.launch({channel: "chromium", headless: true}); console.log("Chromium launch passed"); await browser.close();'

python3 tools/verify_cloud.py
echo 'Cloud tools ready. For a web build: python3 tools/verify_cloud.py --build-web'
