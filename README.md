# Release Keeper (Bash CI/CD Pet Project)

Release Keeper is a small Bash-based deployment tool that demonstrates a real-world deployment pattern:

- versioned **releases/** directories
- a **current** symlink pointing to the active release
- **atomic switch** to a new version
- **automatic rollback** on failure
- **manual rollback** command
- cleanup of old releases
- deploy from a **directory** or from a **tar.gz artifact**

This repo is a learning project focused on DevOps / CI/CD fundamentals and safe Bash scripting.

---

## Project Structure


release-keeper/
deploy/
deploy.sh # main CLI tool
lib.sh # reserved for future helpers
src/
index.html # demo app content
deploy_root/ # LOCAL artifact directory (DO NOT COMMIT)
tests/
(removed) # we test via GitHub Actions steps


**Important:** `deploy_root/` is runtime data (deployment artifacts). In real projects it lives on a server, not in Git. It should be ignored by git.

---

## Core Idea: releases + current symlink

A deployment creates a new directory:


deploy_root/releases/<release_id>/


Then the tool switches:


deploy_root/current -> deploy_root/releases/<release_id>


This is powerful because switching the symlink is fast and (for practical purposes) atomic.
Rollback is also fast: just point `current` to the previous release.

---

## Commands

Run commands from inside `release-keeper/`:

### 1) Create a release from a directory


./deploy/deploy.sh release src deploy_root


Creates a new release directory and points `deploy_root/current` to it.

### 2) Create a release from an artifact (.tar.gz/.tgz)

This simulates a real CI pipeline where you build an artifact and deploy it.

Create artifact:


tar -czf /tmp/site.tar.gz -C src .


Deploy artifact:


./deploy/deploy.sh release /tmp/site.tar.gz deploy_root


The archive should contain `index.html` at the root level.  
Example archive listing should look like:


./
./index.html


### 3) List releases


./deploy/deploy.sh list deploy_root


### 4) Manual rollback


./deploy/deploy.sh rollback deploy_root


Switches `current` to the most recent release that is NOT the current one.

### 5) Cleanup old releases

Keep last N releases and remove older ones, without deleting the active release:


./deploy/deploy.sh cleanup deploy_root 3


If the active release is among “old” releases, it will be skipped (safety first).
That may result in keeping more than N releases, which is intended.

---

## Automatic rollback behavior (trap)

During `release`, the script remembers where `current` pointed before the switch.

If a failure happens after switching, it restores the previous `current` value automatically.
This is implemented with a Bash `trap` to catch non-zero exits and rollback.

You can simulate a failure:


FAIL_AFTER_SWITCH=1 ./deploy/deploy.sh release src deploy_root


Expected result:
- command exits with non-zero code
- `current` returns back to the previous release

---

## CI Pipeline (GitHub Actions)

The GitHub Actions workflow validates this project on each push:

- Bash syntax check (`bash -n`)
- ShellCheck lint
- Smoke deploy test (happy path)
- Manual rollback test
- Failure + auto-rollback test (expected failure, then verification that rollback restored previous current)

All deployment tests run against temporary directories under `/tmp/` on the GitHub runner.

---

## Git hygiene: ignore deploy_root artifacts

`deploy_root/` is not source code. It is generated state.

Add to `.gitignore`:


release-keeper/deploy_root/


If you already created deploy_root locally, keep it on your machine, but do not commit it.

---

## What this project teaches

- safe Bash scripting with `set -Eeuo pipefail`
- atomic deployments with symlinks
- rollback patterns (automatic + manual)
- cleaning old releases safely
- CI checks and failure scenarios
- artifact-based deployment (tar.gz)

---

## Author

Alexander Sivkov