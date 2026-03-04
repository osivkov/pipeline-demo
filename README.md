# Release Keeper (Bash CI/CD Pet Project)

[![CI](https://github.com/osivkov/release-keeper/actions/workflows/pipeline.yml/badge.svg)](https://github.com/osivkov/release-keeper/actions/workflows/pipeline.yml)

**Release Keeper** is a small Bash deployment tool that demonstrates a widely used real-world deployment pattern:

- versioned **releases/** directories  
- a **current** symlink pointing to the active release  
- an **atomic switch** to a new version (symlink update)  
- **automatic rollback** on failure (via `trap`)  
- **manual rollback** command  
- safe cleanup of old releases  
- deploy from a **directory** or from a **.tar.gz / .tgz artifact** (CI-style)

This is a learning project focused on **DevOps / CI/CD fundamentals**: safe Bash scripting, deployment patterns, safety guards, and CI verification.

---

## Why this pattern?

This layout is popular because it makes deployments and rollbacks fast and safe:

- the new version is prepared in a separate folder  
- once ready, `current` is repointed to the new release (**atomic in practice**)  
- rollback is just another symlink update  

It’s a common building block behind many deployment systems.

---

## Requirements

- Linux/macOS:
  - `bash`
  - `tar`, `cp`, `ln`, `readlink`, `sort`, `grep`, `head`, `tail`
- Optional (recommended):
  - `shellcheck`

---

## Repository Layout

From the repo root:

```text
.
├── .github/workflows/pipeline.yml      # CI workflow (GitHub Actions)
├── .gitignore
├── README.md
└── release-keeper
    ├── deploy
    │   ├── deploy.sh                   # main CLI tool
    │   └── lib.sh                      # reserved for future helpers
    ├── src
    │   └── index.html                  # demo app content
    └── deploy_root/                    # runtime state (DO NOT COMMIT)
        ├── current -> releases/<id>
        └── releases/<id>/...
```

> **Important:** `release-keeper/deploy_root/` is deployment runtime state.  
> In real projects it lives on a server, not in Git. Keep it ignored.

Add to `.gitignore`:

```gitignore
release-keeper/deploy_root/
```

---

## Core idea: releases + current symlink

A deployment creates a new directory:

```text
deploy_root/releases/<release_id>/
```

Then it switches the active version by updating a symlink:

```text
deploy_root/current -> deploy_root/releases/<release_id>
```

Example after a few deployments:

```text
deploy_root/
  releases/
    20260304-153613-...
    20260304-153618-...
  current -> releases/20260304-153618-...
```

---

## Quick Start (local)

From the repo root:

```bash
# start clean
rm -rf release-keeper/deploy_root
mkdir -p release-keeper/deploy_root

# deploy from directory
./release-keeper/deploy/deploy.sh release release-keeper/src release-keeper/deploy_root

# inspect current
readlink release-keeper/deploy_root/current
cat release-keeper/deploy_root/current/index.html
```

---

## Commands

Run commands from the repo root.

### 1) Release (deploy) from a directory

```bash
./release-keeper/deploy/deploy.sh release release-keeper/src release-keeper/deploy_root
```

Creates a new release directory and points `deploy_root/current` to it.

---

### 2) Release (deploy) from an artifact (.tar.gz / .tgz)

This simulates a real CI pipeline: build an artifact → deploy it.

Create an artifact:

```bash
tar -czf /tmp/site.tar.gz -C release-keeper/src .
```

Deploy the artifact:

```bash
./release-keeper/deploy/deploy.sh release /tmp/site.tar.gz release-keeper/deploy_root
```

**Artifact format expectation:** archive should contain `index.html` at the root level:

```text
./
./index.html
```

---

### 3) List releases

```bash
./release-keeper/deploy/deploy.sh list release-keeper/deploy_root
```

---

### 4) Manual rollback

```bash
./release-keeper/deploy/deploy.sh rollback release-keeper/deploy_root
```

Switches `current` to the most recent release that is **not** the current one.

---

### 5) Cleanup old releases

Keep the last **N** releases and remove older ones without deleting the active release:

```bash
./release-keeper/deploy/deploy.sh cleanup release-keeper/deploy_root 3
```

If the active release is among the “old” ones, it will be skipped (safety first).  
That may result in keeping more than N releases, which is intended.

---

## Automatic rollback (trap)

During `release`, the script:

1. remembers where `current` pointed before the switch  
2. switches `current` to the new release  
3. if a failure happens after switching, it restores the previous `current` value automatically  

This is implemented via a Bash `trap` on `EXIT`:
if exit code ≠ 0 → rollback.

Simulate a failure after switching:

```bash
FAIL_AFTER_SWITCH=1 ./release-keeper/deploy/deploy.sh release release-keeper/src release-keeper/deploy_root
```

Expected:
- command exits with a non-zero code  
- `current` returns to the previous release  

---

## Safety notes (why some Bash looks “weird”)

You’ll see patterns like:

```bash
: "${RELEASES_DIR:?RELEASES_DIR is empty}"
rm -rf -- "$TARGET"
```

They prevent catastrophic mistakes (e.g. `rm -rf /`) when a variable is empty or a path is malformed.  
This is a standard production safety habit in Bash scripting.

---

## Design decisions (short)

- **Symlink switch = atomic in practice**  
  The new release is fully prepared before switching `current`.

- **Rollback via `trap`**  
  If the script exits with a non-zero status after switching, it restores the previous `current`.

- **Safety guards**  
  Explicit checks are used to prevent dangerous filesystem operations when variables are empty.

---

## CI Pipeline (GitHub Actions)

Workflow: `.github/workflows/pipeline.yml`

On each push / PR it runs:

- Bash syntax check (`bash -n`)
- ShellCheck lint
- smoke deploy test (happy path)
- deploy-from-artifact test (`tar.gz`)
- manual rollback test
- fail + auto-rollback test (expected failure, then verification)

All deployment tests run under `/tmp/` on the GitHub runner.

---

## What this project teaches

- safe Bash scripting with `set -Eeuo pipefail`
- atomic deployments using symlinks
- rollback patterns (automatic + manual)
- safe cleanup of old releases
- CI checks and failure scenarios
- artifact-based deployment (tar.gz), like real pipelines

---

## Roadmap (ideas)

- `status` command (show current + last N releases)
- more reliable “previous release” selection (metadata file, explicit ordering)
- `rsync` instead of `cp` for faster incremental deploys
- health-check before switching `current`
- structured logs for CI

---

## Author

**Alexander Sivkov**