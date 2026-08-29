#!/usr/bin/env bash
#
# Install Popperpig Raid Call into a WoW AddOns folder.
#
#   scripts/install.sh                    auto-detect, copy
#   scripts/install.sh --link             auto-detect, symlink (edit in place)
#   scripts/install.sh /path/to/AddOns    explicit target
#
# WOW_ADDONS_DIR is honoured if set.
#
# The repository directory is popperpigs-raid-call but the in-game folder has
# to be PopperpigRaidCall, matching the .toc. Getting that wrong is the most
# common reason an addon silently fails to appear, which is the whole reason
# this script exists.
#
# --link is the one to use while developing: edit in the repo, /reload in game.

set -euo pipefail

ADDON_NAME="PopperpigRaidCall"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Exactly what the game loads. Tests, scripts and CI stay out, matching .pkgmeta.
SHIPPED=("PopperpigRaidCall.toc" "Core" "Data" "UI")

LINK=0
TARGET="${WOW_ADDONS_DIR:-}"

for arg in "$@"; do
  case "$arg" in
    --link) LINK=1 ;;
    --help|-h)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) TARGET="$arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# Find the AddOns folder
#
# TBC Anniversary runs out of the _classic_ flavour directory. _classic_era_ is
# Classic Era, which is a different client -- installing there means the addon
# never shows up and nothing explains why.
# ---------------------------------------------------------------------------

if [ -z "$TARGET" ]; then
  CANDIDATES=(
    "/Applications/World of Warcraft/_classic_/Interface/AddOns"
    "$HOME/Applications/World of Warcraft/_classic_/Interface/AddOns"
    "/c/Program Files (x86)/World of Warcraft/_classic_/Interface/AddOns"
    "/mnt/c/Program Files (x86)/World of Warcraft/_classic_/Interface/AddOns"
    "$HOME/.wine/drive_c/Program Files (x86)/World of Warcraft/_classic_/Interface/AddOns"
  )
  for candidate in "${CANDIDATES[@]}"; do
    if [ -d "$candidate" ]; then
      TARGET="$candidate"
      echo "Found AddOns folder: $TARGET"
      break
    fi
  done
fi

if [ -z "$TARGET" ]; then
  cat >&2 <<'MSG'
Could not find your AddOns folder.

Pass it explicitly:
    scripts/install.sh "/path/to/World of Warcraft/_classic_/Interface/AddOns"

or set WOW_ADDONS_DIR.

TBC Anniversary lives under the _classic_ flavour directory. If your launcher
shows a different one for Anniversary, use whichever it actually launches --
_classic_era_ is Classic Era and is the wrong client.
MSG
  exit 1
fi

if [ ! -d "$TARGET" ]; then
  echo "Not a directory: $TARGET" >&2
  exit 1
fi

DEST="$TARGET/$ADDON_NAME"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

if [ $LINK -eq 1 ]; then
  # Refuse to delete a real directory on the way to making a symlink. Someone
  # with a copied install and uncommitted local edits should not lose them to
  # a flag they passed once.
  if [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
    echo "Refusing to replace the existing directory at:" >&2
    echo "  $DEST" >&2
    echo "Remove it yourself first if you are sure." >&2
    exit 1
  fi
  rm -f "$DEST"
  ln -s "$REPO_ROOT" "$DEST"
  echo "Linked $DEST -> $REPO_ROOT"
  echo "Edit files in the repo and /reload in game to pick them up."
else
  rm -rf "$DEST"
  mkdir -p "$DEST"
  for item in "${SHIPPED[@]}"; do
    cp -R "$REPO_ROOT/$item" "$DEST/"
  done
  echo "Installed to $DEST"
fi

cat <<'MSG'

Next:
  1. Restart the client, or /reload if it is already running.
  2. Enable "Popperpig Raid Call" at character select. Tick "Load out of date
     AddOns" if the client flags the interface version.
  3. /pprc debug   -> prints the capability table. Zero Lua errors here is the
                      bar; it also names which detection tier went active.
  4. /pprc test hyjal_winterchill
                   -> walks all 8 waves solo. No raid or instance needed.
  5. /pprc echo    -> local echo. Run the first live night this way so a bug
                      cannot spam 24 people.
MSG
