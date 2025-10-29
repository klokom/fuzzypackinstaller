# Fuzzy Pack Installer

Fuzzy Pack Installer is a lightweight, cross-platform package installation helper that provides a fast, interactive fzf-based TUI for installing packages on Linux systems.

It detects your OS (Arch, Debian/Ubuntu, Fedora/RHEL/Rocky/Alma) and launches the correct installer automatically — giving you a single consistent command:
```bash
./install-fuzzypackinstaller.sh
```

Once installed, you can open a fuzzy search menu and install packages directly from your system repositories (or AUR on Arch).

## Features

- Auto-detects distro: Arch, Debian/Ubuntu, Fedora/RHEL/Rocky/Alma
- Automatic setup of fzf (offers EPEL, binary, or source options)
- Installs native repo pickers
  - pkg-install for official repositories
  - pkg-aur-install (on Arch) for AUR
- Interactive fzf interface
  - Multi-select (TAB/SPACE)
  - Live search + preview
  - Install marked packages without closing menu
- Cross-shell support (works in Bash, Fish, Zsh)
- Self-contained scripts — no dependencies beyond fzf, curl, and your package manager

## Installation

Clone the repo and make the scripts executable:
```bash
git clone https://github.com/klokom/fuzzypackinstaller.git
cd fuzzypackinstaller
chmod +x *.sh
```

Then run the main dispatcher:
```bash
./install-fuzzypackinstaller.sh
```

The script will:
1. Detect your Linux distribution.
2. Automatically call the correct OS installer script.
3. Ask where to install the final picker scripts (default: /usr/local/bin).
4. Check if that directory is in your PATH.
5. Verify or install fzf (with fallback options if not in repos).
6. Install the fuzzy picker(s) and show usage instructions.

## Supported Platforms

| Distro | Installer Script | Features |
|:-------|:-----------------|:----------|
| Arch / Manjaro / CachyOS | arch-install-fuzzypackinstaller.sh | Installs both pkg-install and pkg-aur-install, optional paru/yay helper |
| Debian / Ubuntu / Pop!_OS | debian-install-fuzzypackinstaller.sh | Installs single pkg-install using apt |
| Fedora / RHEL / Rocky / Alma | fedora-install-fuzzypackinstaller.sh | Installs single pkg-install using dnf/yum, smart fzf installation logic |

## After Installation

Once installed, two new commands become available (depending on your OS):

### Arch-based systems
```bash
pkg-install        # Browse & install packages from official repos
pkg-aur-install    # Browse & install from AUR (paru/yay)
```

### Debian/Ubuntu systems
```bash
pkg-install        # Browse & install packages from apt
```

### Fedora/RHEL systems
```bash
pkg-install        # Browse & install packages from dnf/yum
```

## Keybindings in the Fuzzy Picker

| Key | Action |
|:----|:--------|
| TAB / SPACE | Mark/unmark selection |
| ENTER | Install current selection |
| CTRL-S | Install all marked packages |
| ALT-A / ALT-D / ALT-T | Select all / Deselect all / Toggle all |
| CTRL-R | Reload package list |
| ESC | Quit the picker |

Each installer prints a one-line command tip above the picker window.

## fzf Installation Logic (RHEL / Fedora)

On RHEL-based systems, fzf is often missing from default repositories.

The Fedora installer offers three fallback options:
1. Enable EPEL and install via package manager (simplest, may be older version)
2. Download the latest prebuilt binary from GitHub
3. Build from source using git + go (pure build, latest version)

## Manual Update or Uninstall

If you want to update or remove the scripts:

```bash
sudo rm -f /usr/local/bin/pkg-install /usr/local/bin/pkg-aur-install
git pull
./install-fuzzypackinstaller.sh
```

## Notes

- The scripts are self-contained — no system modifications beyond installing fzf and placing binaries in your chosen path.
- Works on minimal container or VM images (fallbacks handle missing repos or curl/go/git).
- Uses /usr/local/bin by default but lets you choose another directory.

## Example Output (Fedora/RHEL)

```
=> Using destination: /usr/local/bin
=> Trying to install fzf via dnf (native repos only)...
fzf is not available via dnf on this system.
Choose how to install fzf:
  1) Enable EPEL and install via dnf (may be older)
  2) Download prebuilt binary from GitHub (latest)
  3) Build from source via git + go (latest, pure build)
Enter choice [1/2/3]:
```

## License

MIT License © 2025 klokom

## Roadmap

- [ ] Add macOS (brew) support  
- [ ] Add openSUSE (zypper) support  
- [ ] Optional non-interactive mode for automation  
- [ ] Version check and self-update utility  
- [ ] Plugin-style architecture for other managers (flatpak, snap, pip)

> "Because searching and installing packages should be fuzzy, not frustrating."
