#!/usr/bin/env sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

ARCH_INSTALL="$SCRIPT_DIR/arch-install-fuzzypackinstaller.sh"
DEBIAN_INSTALL="$SCRIPT_DIR/debian-install-fuzzypackinstaller.sh"
FEDORA_INSTALL="$SCRIPT_DIR/fedora-install-fuzzypackinstaller.sh"
EXTRAS_INSTALL="$SCRIPT_DIR/extras-fuzzypackinstaller.sh"

run_arch()   { [ -x "$ARCH_INSTALL" ]   || { echo "Missing: $ARCH_INSTALL";   exit 1; }; "$ARCH_INSTALL"; }
run_debian() { [ -x "$DEBIAN_INSTALL" ] || { echo "Missing: $DEBIAN_INSTALL"; exit 1; }; "$DEBIAN_INSTALL"; }
run_fedora() { [ -x "$FEDORA_INSTALL" ] || { echo "Missing: $FEDORA_INSTALL"; exit 1; }; "$FEDORA_INSTALL"; }

case "${1-}" in
  --arch)   run_arch;   shift || true ;;
  --debian) run_debian; shift || true ;;
  --fedora) run_fedora; shift || true ;;
  --help|-h)
    echo "Usage: $0 [--arch|--debian|--fedora]"
    echo "Without flags, OS is auto-detected."
    exit 0 ;;
esac

picked=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  id_l=$(printf %s "${ID-}" | tr '[:upper:]' '[:lower:]')
  like_l=$(printf %s "${ID_LIKE-}" | tr '[:upper:]' '[:lower:]')

  case "$id_l" in
    arch|artix|endeavouros|manjaro|cachyos) picked="arch" ;;
    debian|ubuntu|linuxmint|pop|neon|elementary) picked="debian" ;;
    fedora|rhel|rocky|almalinux|centos|ol) picked="fedora" ;;
  esac

  if [ -z "$picked" ] && [ -n "${like_l:-}" ]; then
    case "$like_l" in
      *arch*) picked="arch" ;;
      *debian*|*ubuntu*) picked="debian" ;;
      *fedora*|*rhel*) picked="fedora" ;;
    esac
  fi
fi

if [ -z "$picked" ]; then
  if command -v pacman >/dev/null 2>&1; then picked="arch"
  elif command -v apt-get >/dev/null 2>&1; then picked="debian"
  elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then picked="fedora"
  fi
fi

case "$picked" in
  arch)   run_arch ;;
  debian) run_debian ;;
  fedora) run_fedora ;;
  *) echo "Your operating system is not supported by this installer."; exit 1 ;;
esac

echo
if [ -x "$EXTRAS_INSTALL" ]; then
  printf "Install extra pickers (Flatpak/Snap)? [y/N] "
  # shellcheck disable=SC2039
  read -r ans || ans=""
  case "${ans:-}" in
    y|Y|yes|YES) echo "=> Running extras installer..."; "$EXTRAS_INSTALL" ;;
    *)           echo "=> Skipping extras. You can run: $EXTRAS_INSTALL later." ;;
  esac
else
  echo "Note: Extras installer not found at: $EXTRAS_INSTALL"
fi
