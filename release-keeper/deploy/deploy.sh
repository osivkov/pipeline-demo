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

	RELEASE_ID=$(date +%Y%m%d-%H%M%S)
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
	echo "Unknown command: $CMD"
	usage
	exit 1
}

main "$@"
