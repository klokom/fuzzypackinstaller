#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ARCH_INSTALL="$SCRIPT_DIR/arch-install-fuzzypackinstaller.sh"
DEBIAN_INSTALL="$SCRIPT_DIR/debian-install-fuzzypackinstaller.sh"
FEDORA_INSTALL="$SCRIPT_DIR/fedora-install-fuzzypackinstaller.sh"

case "${1-}" in
  --arch)   [ -x "$ARCH_INSTALL" ]   || { echo "Missing: $ARCH_INSTALL"; exit 1; }
            exec "$ARCH_INSTALL" ;;
  --debian) [ -x "$DEBIAN_INSTALL" ] || { echo "Missing: $DEBIAN_INSTALL"; exit 1; }
            exec "$DEBIAN_INSTALL" ;;
  --fedora) [ -x "$FEDORA_INSTALL" ] || { echo "Missing: $FEDORA_INSTALL"; exit 1; }
            exec "$FEDORA_INSTALL" ;;
  --help|-h)
            echo "Usage: $0 [--arch|--debian|--fedora]"
            echo "Without flags, OS is auto-detected."
            exit 0 ;;
esac

if [ -r /etc/os-release ]; then
  . /etc/os-release
  ID_LIKE_LOWER="$(echo "${ID_LIKE-}" | tr '[:upper:]' '[:lower:]')"
  ID_LOWER="$(echo "${ID-}" | tr '[:upper:]' '[:lower:]')"

  case "$ID_LOWER" in
    arch|artix|endeavouros|manjaro|cachyos)
      [ -x "$ARCH_INSTALL" ] || { echo "Missing: $ARCH_INSTALL"; exit 1; }
      exec "$ARCH_INSTALL"
      ;;
    debian|ubuntu|linuxmint|pop|neon|elementary)
      [ -x "$DEBIAN_INSTALL" ] || { echo "Missing: $DEBIAN_INSTALL"; exit 1; }
      exec "$DEBIAN_INSTALL"
      ;;
    fedora|rhel|rocky|almalinux|centos|ol)
      [ -x "$FEDORA_INSTALL" ] || { echo "Missing: $FEDORA_INSTALL"; exit 1; }
      exec "$FEDORA_INSTALL"
      ;;
  esac

  case "$ID_LIKE_LOWER" in
    *arch*)
      [ -x "$ARCH_INSTALL" ] || { echo "Missing: $ARCH_INSTALL"; exit 1; }
      exec "$ARCH_INSTALL"
      ;;
    *debian*|*ubuntu*)
      [ -x "$DEBIAN_INSTALL" ] || { echo "Missing: $DEBIAN_INSTALL"; exit 1; }
      exec "$DEBIAN_INSTALL"
      ;;
    *fedora*|*rhel*)
      [ -x "$FEDORA_INSTALL" ] || { echo "Missing: $FEDORA_INSTALL"; exit 1; }
      exec "$FEDORA_INSTALL"
      ;;
  esac
fi

if command -v pacman >/dev/null 2>&1; then
  [ -x "$ARCH_INSTALL" ] || { echo "Missing: $ARCH_INSTALL"; exit 1; }
  exec "$ARCH_INSTALL"
elif command -v apt-get >/dev/null 2>&1; then
  [ -x "$DEBIAN_INSTALL" ] || { echo "Missing: $DEBIAN_INSTALL"; exit 1; }
  exec "$DEBIAN_INSTALL"
elif command -v dnf >/dev/null 2>&1; then
  [ -x "$FEDORA_INSTALL" ] || { echo "Missing: $FEDORA_INSTALL"; exit 1; }
  exec "$FEDORA_INSTALL"
fi

echo "Your operating system is not supported by this installer."
echo "Supported families: Arch (pacman), Debian/Ubuntu (apt), Fedora/RHEL (dnf)."
echo "You can also force a target manually, e.g.:"
echo "  $0 --arch    or    $0 --debian    or    $0 --fedora"
exit 1
