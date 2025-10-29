#!/usr/bin/env bash
set -Eeuo pipefail


DEFAULT_DEST="/usr/local/bin"
read -r -p "Install scripts to which directory? [${DEFAULT_DEST}] " DEST
DEST="${DEST:-$DEFAULT_DEST}"
echo "=> Using destination: $DEST"

if [[ ! -d "$DEST" ]]; then
  echo "=> Creating $DEST (sudo may be required)"
  sudo mkdir -p "$DEST"
fi

IN_PATH="no"
IFS=':' read -r -a PATH_ARR <<< "$PATH"
for p in "${PATH_ARR[@]}"; do
  [[ "$p" == "$DEST" ]] && IN_PATH="yes" && break
done
if [[ "$IN_PATH" != "yes" ]]; then
  echo "⚠️  $DEST is not in your PATH."
  echo "   Bash:  echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
  echo "   Fish:  set -Ux fish_user_paths $DEST \$fish_user_paths"
fi

echo "=> Checking dependencies (fzf)..."
if ! command -v fzf >/dev/null 2>&1; then
  echo "=> Installing fzf via apt"
  sudo apt update -qq
  sudo apt install -y fzf
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/pkg-install" <<'PKG_INSTALL_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

BASH_BIN="$(command -v bash)"
: "${BASH_BIN:?bash not found}"
sudo -v || true

# Build package index (apt list)
build_index() {
  apt list 2>/dev/null | awk -F'/' 'NR>1 {print $1}' | sort -u
}

# Allow direct installs if args provided
if [[ $# -gt 0 ]]; then
  sudo apt install -y "$@"
fi

mapfile -t ALL_PKGS < <(build_index || true)
[[ ${#ALL_PKGS[@]} -gt 0 ]] || ALL_PKGS=("")

TIPS="TAB/SPACE=mark • ENTER=install current • CTRL-S=install marked • ALT-A/D/T=all/dsel/toggle • CTRL-R=reload • ESC=quit"
printf '%s\n' "$TIPS" > /dev/tty

printf '%s\n' "${ALL_PKGS[@]}" | \
  SHELL="$BASH_BIN" fzf --multi \
    --prompt='Install (apt)> ' \
    --height=90% --border \
    --preview "
      $BASH_BIN -lc '
        set +u
        name=\"{}\"
        [[ -n \"\${name-}\" ]] || { echo \"Type to search; TAB to multi-select\"; exit 0; }
        apt-cache show \"\$name\" 2>/dev/null | grep -E \"^(Package|Version|Description)\" | head -20 || echo \"No info\"
      '
    " \
    --preview-window=right:70%:wrap \
    --bind "tab:toggle+down,space:toggle" \
    --bind "alt-a:select-all,alt-d:deselect-all,alt-t:toggle-all" \
    --bind "ctrl-r:reload($(declare -f build_index); build_index)" \
    --bind "enter:execute(
      $BASH_BIN -lc '
      set +u
      cur_raw=\"{}\"
      [[ -n \"\${cur_raw-}\" ]] || exit 0
      cur=\"\${cur_raw%% *}\"
      sudo apt install -y \"\$cur\" < /dev/tty
      echo; echo \"✔ Installed: \$cur\"; echo \"(Press any key to continue)\"; read -n1 < /dev/tty
      # hard repaint: clear screen + scrollback, move cursor home
      printf \"\033[2J\033[3J\033[H\" > /dev/tty
    '
)" \
    --bind "ctrl-s:execute(
      $BASH_BIN -lc '
      set +u
      sel=( {+} )
      [[ \${#sel[@]} -gt 0 ]] || exit 0
      sudo apt install -y \"\${sel[@]}\" < /dev/tty
      echo; echo \"✔ Installed: \${sel[*]}\"; echo \"(Press any key to continue)\"; read -n1 < /dev/tty
      # hard repaint before returning to fzf
      printf \"\033[2J\033[3J\033[H\" > /dev/tty
  '
)+clear-selection"
PKG_INSTALL_EOF

echo "=> Installing pkg-install to $DEST"
sudo install -Dm755 "$TMP_DIR/pkg-install" "$DEST/pkg-install"

echo
echo "✅ Done (Debian/Ubuntu)."
echo "   Installed: $DEST/pkg-install"
echo
echo "Usage:"
echo "   pkg-install          # fuzzy package browser for apt"
echo
echo "Tips (also shown above the picker):"
echo "   TAB/SPACE=mark • ENTER=install current • CTRL-S=install marked • ALT-A/D/T=all/dsel/toggle • CTRL-R=reload • ESC=quit"
