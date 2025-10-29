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
  echo "❌ Neither dnf nor yum found. Exiting."
  exit 1
fi

choose_fzf_fallback() {
  echo
  echo "fzf is not available via $PKG_MGR on this system."
  echo "Choose how to install fzf:"
  echo "  1) Enable EPEL and install via $PKG_MGR (easy, may be older)"
  echo "  2) Download prebuilt binary from GitHub (latest stable)"
  echo "  3) Build from source via git + go (latest, pure build)"
  read -r -p "Enter choice [1/2/3]: " CHOICE
  CHOICE="${CHOICE:-1}"
  echo "$CHOICE"
}

install_fzf_via_native() {
  echo "=> Trying to install fzf via $PKG_MGR (native repos only)..."
  sudo "$PKG_MGR" -y install fzf && return 0
  return 1
}

install_fzf_via_epel() {
  echo "=> Enabling EPEL and installing fzf..."
  if [[ "$PKG_MGR" == "dnf" ]]; then
    sudo dnf -y install epel-release || return 1
    sudo dnf -y --enablerepo=epel install fzf || return 1
  else
    sudo yum -y install epel-release || return 1
    sudo yum -y --enablerepo=epel install fzf || return 1
  fi
  return 0
}

install_fzf_from_github() {
  echo "=> Downloading fzf prebuilt binary from GitHub Releases"
  command -v curl >/dev/null 2>&1 || sudo "$PKG_MGR" -y install curl || true

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  ARCH_TAG="amd64" ;;
    aarch64) ARCH_TAG="arm64" ;;
    armv7l)  ARCH_TAG="armv7" ;;
    *)       echo "⚠️  Unknown arch '$ARCH'. Using amd64 as fallback."; ARCH_TAG="amd64" ;;
  esac

  API_URL="https://api.github.com/repos/junegunn/fzf/releases/latest"
  ASSET_URL="$(curl -fsSL "$API_URL" | grep -Eo '"browser_download_url": *"[^"]+"' | grep "linux_${ARCH_TAG}" | head -n1 | cut -d'"' -f4 || true)"
  [[ -n "$ASSET_URL" ]] || { echo "❌ No matching binary found for linux_${ARCH_TAG}"; return 1; }

  TMP_DIR="$(mktemp -d)"; trap 'rm -rf "$TMP_DIR"' RETURN
  echo "=> Downloading: $ASSET_URL"
  curl -fL "$ASSET_URL" -o "$TMP_DIR/fzf.tar.gz" || { echo "❌ Download failed"; return 1; }
  tar -xf "$TMP_DIR/fzf.tar.gz" -C "$TMP_DIR" || { echo "❌ Extract failed"; return 1; }

  BIN_PATH=""
  [[ -f "$TMP_DIR/fzf" ]] && BIN_PATH="$TMP_DIR/fzf"
  [[ -z "$BIN_PATH" && -f "$TMP_DIR/bin/fzf" ]] && BIN_PATH="$TMP_DIR/bin/fzf"
  [[ -z "$BIN_PATH" ]] && { echo "❌ fzf binary not found"; return 1; }

  sudo install -Dm755 "$BIN_PATH" "$DEST/fzf"
  echo "=> Installed $( "$DEST/fzf" --version 2>/dev/null || echo 'fzf' ) to $DEST/fzf"
  return 0
}

install_fzf_from_source() {
  echo "=> Building fzf from source"
  command -v git >/dev/null 2>&1 || sudo "$PKG_MGR" -y install git || true
  command -v go  >/dev/null 2>&1 || sudo "$PKG_MGR" -y install golang || true
  command -v git >/dev/null 2>&1 && command -v go >/dev/null 2>&1 || { echo "❌ Need git and go"; return 1; }

  TMP_DIR="$(mktemp -d)"; trap 'rm -rf "$TMP_DIR"' RETURN
  git clone --depth 1 https://github.com/junegunn/fzf.git "$TMP_DIR/fzf"
  pushd "$TMP_DIR/fzf" >/dev/null
  make || go build -o ./bin/fzf ./ || { echo "❌ Build failed"; popd >/dev/null; return 1; }
  sudo install -Dm755 "./bin/fzf" "$DEST/fzf"
  popd >/dev/null
  echo "=> Installed $( "$DEST/fzf" --version 2>/dev/null || echo 'fzf' ) to $DEST/fzf"
  return 0
}

if ! command -v fzf >/dev/null 2>&1; then
  if install_fzf_via_native; then
    echo "✅ fzf installed via native $PKG_MGR repos"
  else
    CHOICE="$(choose_fzf_fallback)"
    case "$CHOICE" in
      1) install_fzf_via_epel       || { echo "❌ EPEL install failed"; exit 1; } ;;
      2) install_fzf_from_github    || { echo "❌ GitHub binary install failed"; exit 1; } ;;
      3) install_fzf_from_source    || { echo "❌ Source build failed"; exit 1; } ;;
      *) echo "❌ Invalid choice"; exit 1 ;;
    esac
  fi
else
  echo "=> fzf already present: $(fzf --version 2>/dev/null || echo 'found')"
fi

HAVE_REPOQUERY="no"
if command -v repoquery >/dev/null 2>&1; then
  HAVE_REPOQUERY="yes"
else
  if [[ "$PKG_MGR" == "dnf" ]]; then
    echo "=> Installing dnf-plugins-core for repoquery (optional)"
    sudo dnf -y install dnf-plugins-core || true
    command -v repoquery >/dev/null 2>&1 && HAVE_REPOQUERY="yes"
  fi
fi

TMP_DIR_SCRIPTS="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR_SCRIPTS"' EXIT

cat > "$TMP_DIR_SCRIPTS/pkg-install" <<'PKG_INSTALL_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if command -v dnf >/dev/null 2>&1; then
  MGR="dnf"
else
  MGR="yum"
fi

BASH_BIN="$(command -v bash)"
: "${BASH_BIN:?bash not found}"
sudo -v || true

if command -v repoquery >/dev/null 2>&1; then
  HAVE_REPOQUERY="yes"
else
  HAVE_REPOQUERY="no"
fi

build_index() {
  if [[ "$HAVE_REPOQUERY" == "yes" ]]; then
    repoquery --qf '%{name}' | sort -u
  else
    "$MGR" -q list available 2>/dev/null | awk '{print $1}' | sed -E 's/\.[^.]+$//' | sort -u
  fi
}

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

sudo install -Dm755 "$TMP_DIR_SCRIPTS/pkg-install" "$DEST/pkg-install"

echo
echo "✅ Done (Fedora/RHEL/Rocky/Alma)."
echo "   Installed: $DEST/pkg-install"
echo
echo "Usage:"
echo "   pkg-install          # fuzzy package browser for dnf/yum"
echo
echo "Tips (also shown above the picker):"
echo "   TAB/SPACE=mark • ENTER=install current • CTRL-S=install marked • ALT-A/D/T=all/dsel/toggle • CTRL-R=reload • ESC=quit"
