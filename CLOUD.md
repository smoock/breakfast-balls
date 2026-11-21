# Breakfast Balls in Codex Cloud

Use the GitHub repository [smoock/breakfast-balls](https://github.com/smoock/breakfast-balls). The root `project.godot` is the active project. Cloud tasks use committed GitHub files; uncommitted work on your Mac is not automatically uploaded.

## Create the reusable environment

In ChatGPT/Codex on web or desktop, open **Settings → Codex Cloud → Environments → Create environment**. Select `smoock/breakfast-balls`, then **Get started**. Name the environment **Breakfast Balls** and keep it private to you. Use this setup request:

> Prepare this repository for mobile Codex development. Use Node.js 22 and Python 3. Run `bash tools/setup_cloud.sh`, then `python3 tools/verify_cloud.py --build-web`. Record `bash tools/setup_cloud.sh` as the install script. Put `$HOME/.local/bin` on PATH for task shells and set BROWSER_CHANNEL=chromium. The Godot version is pinned to 4.7.2 with matching web export templates. Do not deploy production services. Report the test results and any remaining failures before publishing.

The setup script installs the official Linux x86_64 Godot editor and matching single-threaded web templates, verifies the upstream SHA-512 checksums, runs `npm ci`, installs Playwright Chromium and its system libraries, and checks the project. It also creates `/private/tmp` for existing test fixtures that use that macOS path. It needs an environment with root or sudo access for system packages.

For restricted networking, enable **Package managers** and allow Playwright's download hosts `cdn.playwright.dev` and `playwright.download.prss.microsoft.com`. GitHub release downloads and npm are covered by the package-manager preset. If a download redirects to another host, add only the host identified by the failed request. Development tests use local services and do not need production payment, Redis, or Vercel credentials.

After the checks finish, review the setup report and select **Publish**. Saving a draft alone does not make it available to mobile tasks. If setup changes later, edit and republish; existing tasks retain their own state. See the [official cloud environment guide](https://learn.chatgpt.com/docs/environments/cloud-environments).

## Work from your phone

1. Open **Codex**, choose **Cloud**, and select **Breakfast Balls**.
2. Describe the change. For example: “Create a `codex/clubhouse-help` branch from the latest main. Improve the clubhouse help text, run relevant checks, then commit and push the branch and open a pull request. Do not deploy.”
3. Review the diff and test results. Merge the pull request when ready.
4. Back on the Mac, finish or commit any local work before pulling. Use `git pull --ff-only` from a clean `main` checkout; resolve divergence deliberately instead of overwriting local work.

Cloud tasks can run while the Mac is asleep. The desktop Godot/Blender MCP servers are local integrations and are not required for code changes, headless tests, or web exports. Keep local playtesting for graphics, input feel, authored Blender changes, and hardware performance.

## Commands

```bash
# One-time setup or refresh after tool/dependency changes (Linux only).
bash tools/setup_cloud.sh

# Headless Godot suites plus Node server tests.
python3 tools/verify_cloud.py

# Also produce the portable website in builds/web.
python3 tools/verify_cloud.py --build-web

# Start the local browser/API preview in a separate terminal.
node tools/serve_online.mjs --port 8060

# Actual browser journeys against that preview.
BROWSER_CHANNEL=chromium npm run test:web
BROWSER_CHANNEL=chromium npm run test:online:browser
```

The verifier discovers the cloud Godot installation without relying on shell PATH changes. Set `GODOT` to a full executable path to use an existing local installation. Browser journeys use software rendering in typical cloud environments and can be slow; their results are functional checks, not GPU benchmarks. Generated builds, `node_modules`, `.godot`, and test output stay outside Git.

Pushing code does not publish a game release. Browser production releases remain a separate, explicitly requested workflow described in `WEB.md` and `ONLINE.md`.
