#!/usr/bin/env bash
set -euo pipefail

KLIPPER_DIR="${KLIPPER_DIR:-$HOME/klipper}"
PATCH_BRANCH="${PATCH_BRANCH:-ratos/v2.1.x-multisample-zhome}"
RATOS_REMOTE="${RATOS_REMOTE:-ratos-fork}"
RATOS_REMOTE_URL="${RATOS_REMOTE_URL:-https://github.com/Rat-OS/klipper.git}"
RATOS_BRANCH="${RATOS_BRANCH:-ratos/v2.1.x}"
RATOS_REF="${RATOS_REMOTE}/${RATOS_BRANCH}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${PATCH_FILE:-${SCRIPT_DIR}/patches/multisample-z-home-ratos-v2.1.x.patch}"
TARGET_FILES=(klippy/extras/homing.py klippy/extras/probe.py)

die() {
    echo "error: $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

is_target_file() {
    local file="$1"
    [[ "$file" == "klippy/extras/homing.py" || "$file" == "klippy/extras/probe.py" ]]
}

need_cmd git
need_cmd python3

[[ -f "$PATCH_FILE" ]] || die "patch file not found: $PATCH_FILE"
[[ -d "$KLIPPER_DIR/.git" ]] || die "not a git checkout: $KLIPPER_DIR"

cd "$KLIPPER_DIR"

if ! git remote get-url "$RATOS_REMOTE" >/dev/null 2>&1; then
    echo "Adding RatOS Klipper remote '$RATOS_REMOTE'..."
    git remote add "$RATOS_REMOTE" "$RATOS_REMOTE_URL"
fi

echo "Fetching ${RATOS_REMOTE}/${RATOS_BRANCH}..."
git fetch "$RATOS_REMOTE" >/dev/null
git rev-parse --verify --quiet "$RATOS_REF" >/dev/null \
    || die "could not find $RATOS_REF"

unmerged="$(git diff --name-only --diff-filter=U || true)"
if [[ -n "$unmerged" ]]; then
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        is_target_file "$file" || die "unmerged non-target file exists: $file"
    done <<< "$unmerged"
    echo "Restoring conflicted Klipper target files from $RATOS_REF..."
    git restore --source="$RATOS_REF" --staged --worktree "${TARGET_FILES[@]}"
fi

if git show-ref --verify --quiet "refs/heads/$PATCH_BRANCH"; then
    echo "Checking out existing branch $PATCH_BRANCH..."
    git checkout "$PATCH_BRANCH"
else
    echo "Creating branch $PATCH_BRANCH from $RATOS_REF..."
    git checkout -b "$PATCH_BRANCH" "$RATOS_REF"
fi

dirty_non_targets="$(
    git status --porcelain --untracked-files=no \
        | awk '{print $2}' \
        | while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            if ! is_target_file "$file"; then
                echo "$file"
            fi
        done
)"
[[ -z "$dirty_non_targets" ]] \
    || die "non-target Klipper files have local changes; refusing to continue:
$dirty_non_targets"

echo "Resetting target files to $RATOS_REF before patching..."
git restore --source="$RATOS_REF" --staged --worktree "${TARGET_FILES[@]}"

echo "Checking patch..."
git apply --check "$PATCH_FILE"

echo "Applying patch..."
git apply "$PATCH_FILE"

echo "Checking Python syntax..."
python3 -m py_compile "${TARGET_FILES[@]}"

echo
echo "Patch applied on branch $PATCH_BRANCH."
echo "Restarting Klipper..."
sudo systemctl restart klipper
echo "Done."

