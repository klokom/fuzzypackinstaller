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

PKG_MGR=""
if command -v dnf >/dev/null 2>&1; then
  PKG_MGR="dnf"
elif command -v yum >/dev/null 2>&1; then
  PKG_MGR="yum"
else
  echo "❌ Neither dnf nor yum found. This installer targets Fedora/RHEL-family systems."
  exit 1
fi

echo "=> Checking dependencies (fzf)..."
if ! command -v fzf >/dev/null 2>&1; then
  echo "=> Installing fzf via $PKG_MGR"
  sudo "$PKG_MGR" install -y fzf
fi

HAVE_REPOQUERY="no"
if command -v repoquery >/dev/null 2>&1; then
  HAVE_REPOQUERY="yes"
else
  if [[ "$PKG_MGR" == "dnf" ]]; then
    echo "=> (Optional) Installing dnf-plugins-core for repoquery (faster search/previews)"
    sudo dnf install -y dnf-plugins-core || true
    command -v repoquery >/dev/null 2>&1 && HAVE_REPOQUERY="yes"
  fi
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/pkg-install" <<'PKG_INSTALL_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

# Use dnf if present, else yum
if command -v dnf >/dev/null 2>&1; then
  MGR="dnf"
else
  MGR="yum"
fi

BASH_BIN="$(command -v bash)"
: "${BASH_BIN:?bash not found}"
sudo -v || true

# Detect repoquery availability
if command -v repoquery >/dev/null 2>&1; then
  HAVE_REPOQUERY="yes"
else
  HAVE_REPOQUERY="no"
fi

# Build package index
build_index() {
  if [[ "$HAVE_REPOQUERY" == "yes" ]]; then
    # Unique package names
    repoquery --qf '%{name}' | sort -u
  else
    # Fallback: parse from list available
    # dnf/yum output includes name.arch; strip the final ".arch"
    "$MGR" -q list available 2>/dev/null | awk '{print $1}' | sed -E 's/\.[^.]+$//' | sort -u
  fi
}

# Allow direct installs if args provided
if [[ $# -gt 0 ]]; then
  sudo "$MGR" install -y "$@" < /dev/tty
fi

mapfile -t ALL_PKGS < <(build_index || true)
[[ ${#ALL_PKGS[@]} -gt 0 ]] || ALL_PKGS=("")

TIPS="TAB/SPACE=mark • ENTER=install current • CTRL-S=install marked • ALT-A/D/T=all/dsel/toggle • CTRL-R=reload • ESC=quit"
printf '%s\n' "$TIPS" > /dev/tty

printf '%s\n' "${ALL_PKGS[@]}" | \
  SHELL="$BASH_BIN" fzf --multi \
    --prompt="Install ($MGR)> " \
    --height=90% --border \
    --preview "
      $BASH_BIN -lc '
        set +u
        name=\"{}\"
        [[ -n \"\${name-}\" ]] || { echo \"Type to search; TAB to multi-select\"; exit 0; }
        if [[ \"$HAVE_REPOQUERY\" == \"yes\" ]]; then
          repoquery -i \"\$name\" 2>/dev/null | sed -n \"1,80p\"
        else
          $MGR info \"\$name\" 2>/dev/null | sed -n \"1,80p\"
        fi
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
        sudo $MGR install -y \"\$cur\" < /dev/tty
        echo; echo \"✔ Installed: \$cur\"; echo \"(Press any key to continue)\"; read -n1 < /dev/tty
      '
    )" \
    --bind "ctrl-s:execute(
      $BASH_BIN -lc '
        set +u
        sel=( {+} )
        [[ \${#sel[@]} -gt 0 ]] || exit 0
        sudo $MGR install -y \"\${sel[@]}\" < /dev/tty
        echo; echo \"✔ Installed: \${sel[*]}\"; echo \"(Press any key to continue)\"; read -n1 < /dev/tty
      '
    )+clear-selection"
PKG_INSTALL_EOF

echo "=> Installing pkg-install to $DEST"
sudo install -Dm755 "$TMP_DIR/pkg-install" "$DEST/pkg-install"

echo
echo "✅ Done (Fedora/RHEL)."
echo "   Installed: $DEST/pkg-install"
echo
echo "Usage:"
echo "   pkg-install          # fuzzy package browser for dnf/yum"
echo
echo "Tips (also shown above the picker):"
echo "   TAB/SPACE=mark • ENTER=install current • CTRL-S=install marked • ALT-A/D/T=all/dsel/toggle • CTRL-R=reload • ESC=quit"
