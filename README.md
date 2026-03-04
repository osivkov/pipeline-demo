# Release Keeper (Bash CI/CD Pet Project)

[![CI](https://github.com/osivkov/pipeline-demo/actions/workflows/pipeline.yml/badge.svg?branch=main)](https://github.com/osivkov/pipeline-demo/actions/workflows/pipeline.yml)

**Release Keeper** is a small Bash deployment tool that demonstrates a
widely used real‑world deployment pattern.

Key features:

-   versioned **releases/** directories\
-   a **current** symlink pointing to the active release\
-   **atomic deployment switch** (symlink update)\
-   **automatic rollback** on failure using `trap`\
-   **manual rollback** command\
-   safe cleanup of old releases\
-   deployment from **directory or artifact (.tar.gz / .tgz)**

This repository is designed as a **DevOps learning project**
demonstrating safe Bash scripting, CI validation, and a classic
deployment strategy.

------------------------------------------------------------------------

# Why this pattern?

This deployment layout is widely used because it makes deployments
**fast, reversible, and safe**.

The idea:

1.  Prepare the new version in a separate directory.
2.  When everything is ready --- update a single pointer (`current`).
3.  If something fails --- point it back.

Advantages:

-   deployments are very fast
-   rollback takes milliseconds
-   multiple versions stay on disk for debugging

This pattern appears in many real deployment systems.

------------------------------------------------------------------------

# Deployment Architecture

                  CI Pipeline
                       │
                       ▼
               Build Artifact (.tar.gz)
                       │
                       ▼
                 deploy.sh release
                       │
                       ▼
         deploy_root/releases/<release_id>/
                       │
                       ▼
            current -> releases/<release_id>
                       │
                       ▼
                  Running Version

The **symlink switch** acts as a practical atomic deployment step.

------------------------------------------------------------------------

# Requirements

Linux or macOS with:

-   `bash`
-   `tar`
-   `cp`
-   `ln`
-   `readlink`
-   `sort`
-   `grep`
-   `head`
-   `tail`

Optional but recommended:

-   `shellcheck`

------------------------------------------------------------------------

# Repository Layout

    .
    ├── .github/workflows/pipeline.yml
    ├── .gitignore
    ├── README.md
    └── release-keeper
        ├── deploy
        │   ├── deploy.sh
        │   └── lib.sh
        ├── src
        │   └── index.html
        └── deploy_root/
            ├── current -> releases/<id>
            └── releases/<id>/

Important:

`release-keeper/deploy_root/` is **runtime deployment state**.

In production this directory would live on a **server**, not in Git.

Add to `.gitignore`:

    release-keeper/deploy_root/

------------------------------------------------------------------------

# Quick Start

Clean deployment directory:

    rm -rf release-keeper/deploy_root
    mkdir -p release-keeper/deploy_root

Deploy from source directory:

    ./release-keeper/deploy/deploy.sh release release-keeper/src release-keeper/deploy_root

Inspect the active version:

    readlink release-keeper/deploy_root/current
    cat release-keeper/deploy_root/current/index.html

------------------------------------------------------------------------

# Commands

Run commands from repository root.

### Deploy from directory

    ./release-keeper/deploy/deploy.sh release release-keeper/src release-keeper/deploy_root

------------------------------------------------------------------------

### Deploy from artifact

Create artifact:

    tar -czf /tmp/site.tar.gz -C release-keeper/src .

Deploy artifact:

    ./release-keeper/deploy/deploy.sh release /tmp/site.tar.gz release-keeper/deploy_root

Artifact structure expected:

    ./
    ./index.html

------------------------------------------------------------------------

### List releases

    ./release-keeper/deploy/deploy.sh list release-keeper/deploy_root

------------------------------------------------------------------------

### Manual rollback

    ./release-keeper/deploy/deploy.sh rollback release-keeper/deploy_root

Switches `current` to the most recent release that is **not the current
one**.

------------------------------------------------------------------------

### Cleanup old releases

Keep the last N releases:

    ./release-keeper/deploy/deploy.sh cleanup release-keeper/deploy_root 3

The active release is **never deleted**.

------------------------------------------------------------------------

# Automatic Rollback

During deployment the script:

1.  remembers previous `current`
2.  switches `current` to new release
3.  if an error occurs --- rollback restores the previous version

Implemented via:

    trap on_exit EXIT

Simulate failure:

    FAIL_AFTER_SWITCH=1 ./release-keeper/deploy/deploy.sh release release-keeper/src release-keeper/deploy_root

Expected result:

-   command exits with non‑zero status
-   `current` returns to previous version

------------------------------------------------------------------------

# Safety Practices

Some Bash constructs may look unusual:

    : "${RELEASES_DIR:?RELEASES_DIR is empty}"
    rm -rf -- "$TARGET"

They protect against catastrophic mistakes such as:

    rm -rf /

This is a common **production safety pattern** in Bash scripts.

------------------------------------------------------------------------

# Design Decisions

### Atomic deploy switch

The release is fully prepared **before** switching `current`.

### Rollback using trap

If the script exits with a failure code, the previous release is
restored.

### Safety guards

Explicit checks prevent dangerous filesystem operations.

------------------------------------------------------------------------

# CI Pipeline

Workflow file:

    .github/workflows/pipeline.yml

Each push / pull request runs:

-   Bash syntax check (`bash -n`)
-   ShellCheck lint
-   smoke deploy test
-   artifact deployment test
-   manual rollback test
-   failure simulation with automatic rollback

All tests run inside temporary directories under `/tmp/`.

------------------------------------------------------------------------

# Example CI Output

Example pipeline run:

    Run bash -n deploy.sh
    ✔ syntax OK

    Run shellcheck
    ✔ no critical issues

    Run smoke deploy
    ✔ deployment succeeded

    Run rollback test
    ✔ rollback restored previous release

    Run failure simulation
    ✔ automatic rollback triggered

------------------------------------------------------------------------

# Where This Pattern Is Used

This deployment strategy is similar to approaches used by:

-   Capistrano deployments
-   Ansible-based release systems
-   internal CI/CD pipelines
-   some Kubernetes rollout strategies
-   many traditional Linux deployments

The core idea:

**prepare new version → switch pointer → rollback instantly if needed**

------------------------------------------------------------------------

# What This Project Demonstrates

-   safe Bash scripting (`set -Eeuo pipefail`)
-   deployment automation
-   atomic deploy strategy using symlinks
-   automatic rollback logic
-   CI validation
-   artifact-based deployment

------------------------------------------------------------------------

# Roadmap

Possible future improvements:

-   `status` command
-   release metadata tracking
-   `rsync` deploy for faster updates
-   health-check before switching versions
-   structured logging
-   containerized demo environment

------------------------------------------------------------------------

# Author

**Alexander Sivkov**