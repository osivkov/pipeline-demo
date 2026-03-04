#!/usr/bin/env bash

set -Eeuo pipefail
PREV_CURRENT=""
DEPLOY_ROOT_FOR_TRAP=""


rollback_on_error()
{
	if [ -n "$PREV_CURRENT" ]; then
		echo "ERROR: rollback current -> $PREV_CURRENT"
		ln -sfn "$PREV_CURRENT" "$DEPLOY_ROOT_FOR_TRAP/current"
	else
		echo "ERROR: rollback skipped ( no previous current)"
	fi
}


usage()
{
	echo "Usage:"
	echo "	deploy.sh release <src_dir>  <deploy_root>"
	echo "	deploy.sh list <deploy_root>"
	echo "	deploy.sh rollback <deploy_root>"
}


on_exit()
{
	RC=$?
	if [[ $RC -ne 0 ]]; then
		rollback_on_error
	fi
}

release()
{
	SRC_DIR="$1"
	DEPLOY_ROOT="$2"

	if [[ ! -d "$SRC_DIR" ]]; then
		echo "Source directory not found: $SRC_DIR"
		exit 1
	fi

	RELEASE_DIR="$DEPLOY_ROOT/releases"

	mkdir -p "$RELEASE_DIR"

	RELEASE_ID=$(date +%Y%m%d-%H%M%S-%N)
	NEW_RELEASE="$RELEASE_DIR/$RELEASE_ID"

	echo "Creating release: $NEW_RELEASE"

	mkdir "$NEW_RELEASE"

	echo "Copying files..."

	cp -r "$SRC_DIR/"* "$NEW_RELEASE/"

	DEPLOY_ROOT_FOR_TRAP="$DEPLOY_ROOT"
	PREV_CURRENT="$(readlink "$DEPLOY_ROOT/current" 2>/dev/null || true)"

	echo "Previous current: ${PREV_CURRENT:-<none>}"

	trap on_exit EXIT

	echo "Switching current -> $NEW_RELEASE"
	ln -sfn "$NEW_RELEASE" "$DEPLOY_ROOT/current"

	if [[ "${FAIL_AFTER_SWITCH:-0}" == "1" ]]; then
		echo "FAIL_AFTER_SWITCH=1 -> failing on purpose"
		exit 42
	fi
	trap - EXIT
}

list_releases()
{
	DEPLOY_ROOT="$1"
	RELEASES_DIR="$DEPLOY_ROOT/releases"
	if [[ ! -d "$RELEASES_DIR" ]]; then
		echo "No releases directory: $RELEASES_DIR"
		exit 0
	fi

	echo "Releases in: $RELEASES_DIR"
	ls -1 "$RELEASES_DIR" | sort
}

cleanup()
{
	DEPLOY_ROOT="$1"
	KEEP="$2"
	RELEASES_DIR="$DEPLOY_ROOT/releases"

	if [[ ! -d "$RELEASES_DIR" ]]; then
		echo "No releases directory"
		exit 0
	fi
	
	: "${RELEASES_DIR:?RELEASES_DIR is empty}"

	CURRENT_TARGET="$(readlink "$DEPLOY_ROOT/current" 2>/dev/null || true )"
	CURRENT_RELEASE="$(basename "$CURRENT_TARGET")"

	if [[ -n "$CURRENT_TARGET" ]]; then
		echo "Active release (current): $CURRENT_RELEASE"
	else
		echo "No current symlink set"
	fi

	echo "Keeping last $KEEP releases"

	TOTAL=$(ls -1 "$RELEASES_DIR" | wc -l | tr -d ' ')
	echo "Total releases: $TOTAL"

	if [[ "$TOTAL" -le "$KEEP" ]]; then
		echo "Nothing to clean"
		exit 0
	fi

	REMOVE_COUNT=$((TOTAL - KEEP))
	echo "Removing $REMOVE_COUNT old releases"

	ls -1 "$RELEASES_DIR" | sort | head -n "$REMOVE_COUNT" | while IFS= read -r r; do
		if [[ -n "$CURRENT_RELEASE" && "$r" == "$CURRENT_RELEASE" ]]; then
			echo "Skipping active release: $r"
			continue
		fi
		TARGET="$RELEASES_DIR/$r"
		echo "Removing $TARGET"
		rm -rf -- "$TARGET"
	done
}

rollback()
{
	DEPLOY_ROOT="$1"
	RELEASES_DIR="$DEPLOY_ROOT/releases"

	if [[ ! -d "$RELEASES_DIR" ]]; then
		echo "No release directory $RELEASES_DIR"
		exit 1
	fi

	:"${RELEASES_DIR:?RELEASES_DIR is empty}"

	CURRENT_TARGET="$(readlink "$DEPLOY_ROOT/current" 2>/dev/null || true )"
	CURRENT_RELEASE="$(basename "$CURRENT_TARGET")"
	if [[ -z "$CURRENT_RELEASE" ]]; then
		echo "No current release set"
		exit 1
	fi

	echo "Current release $CURRENT_RELEASE"
	PREV_RELEASE="$(ls -1 "$RELEASES_DIR" | sort | grep -v "^$CURRENT_RELEASE$" | tail -n 1)"

	if [[ -z "$PREV_RELEASE" ]]; then
		echo "No previous release available"
		exit 1
	fi

	echo "Rolling back to: $PREV_RELEASE"
	ABS_RELEASES_DIR="$(cd "$RELEASES_DIR" && pwd)"
	ln -sfn "$ABS_RELEASES_DIR/$PREV_RELEASE" "$DEPLOY_ROOT/current"

}

main()
{
	if [[ $# -lt 1 ]]; then
		usage
		exit 1
	fi

	CMD="$1"
	shift

	if [[ "$CMD" == "release" ]]; then
		if [[ $# -lt 2 ]]; then
			echo "release requires src_dir deploy_root"
			exit 1
		fi
		release "$1" "$2"
		exit 0
	fi

	if [[ "$CMD" == "list" ]]; then
		if [[ $# -lt 1 ]]; then
			echo "list requires deploy_root"
			exit 1
		fi
		list_releases "$1"
		exit 0
	fi

	if [[ "$CMD" == "cleanup" ]]; then
		if [[ $# -lt 2 ]]; then
			echo "cleanup required deploy_root and keep count"
			exit 1
		fi
		cleanup "$1" "$2"
		exit 0
	fi

	if [[ "$CMD" == "rollback" ]]; then
		if [[ $# -lt 1 ]]; then
			echo "rollback required deploy_root"
			exit 1
		fi
		rollback "$1"
		exit 0
	fi
		
	echo "Unknown command: $CMD"
	usage
	exit 1
}

main "$@"
