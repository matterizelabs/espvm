# espvm — ESP SDK Version Manager

Manage multiple ESP-IDF and ESP-Matter versions.

- **ESP-IDF**: git worktree per version (efficient disk & network usage)
- **ESP-Matter**: shallow clones (worktree incompatible with its submodules)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/matterizelabs/espvm/main/install.sh | bash
```

Or pinned to a release:

```bash
curl -fsSL https://raw.githubusercontent.com/matterizelabs/espvm/main/install.sh | ESPVM_RELEASE_TAG=v0.0.4 bash
```

Or manually:

```bash
curl -o ~/.local/bin/espvm https://raw.githubusercontent.com/matterizelabs/espvm/main/espvm
chmod +x ~/.local/bin/espvm
echo 'source ~/.local/bin/espvm' >> ~/.bashrc
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/matterizelabs/espvm/main/uninstall.sh | bash
```

Remove espvm tool only (keeps installed SDKs and config). To wipe everything:

```bash
curl -fsSL https://raw.githubusercontent.com/matterizelabs/espvm/main/uninstall.sh | bash -s -- --purge
```

## Quick Start

```bash
espvm i 5.4.1           # Install IDF
espvm 5.4.1             # Activate (or install if needed)

espvm -m i 1.4          # Install Matter (requires IDF active)
espvm -m 1.4             # Activate Matter
```

## Commands

| Short | Full | Description |
|-------|------|-------------|
| `i` | `install` | Install version |
| | `use` | Activate version |
| `ls` | `list` | List installed |
| `remote` | `list-remote` | List available |
| `rm` | `remove` | Remove version |
| | `update` | Update version |
| | `current` | Show active version |
| | `status` | Show active SDKs |
| | `repair` | Fix worktree links (IDF) |
| | `config` | Show/set config |

SDK flags: `-i` ESP-IDF (default), `-m` ESP-Matter

## Configuration

```bash
espvm config                          # Show config
espvm config set worktree-dir /path   # Set versions directory
espvm config set use-ssh yes          # yes, no, auto
espvm config reset                    # Reset to defaults
```

Config stored at `~/.espressif/.espvm/config`

## Platform support

| Platform | Status |
|----------|--------|
| Linux | Supported |
| macOS | Supported (zsh, or bash >= 4 via `brew install bash`) |
| BSD | Supported with bash >= 4 installed |
| Windows | **WSL2 only** (native Windows unsupported — ESP-IDF uses `install.bat`/`export.ps1` there) |

Windows notes: inside WSL2 everything works as on Linux. Clone repositories
from inside the WSL filesystem, not from `/mnt/c/...` (per Espressif docs).
Flash access requires [usbipd-win](https://github.com/dorssel/usbipd-win).

Fish shell is not supported (espvm is bash/zsh only; ESP-IDF ships its own
`install.fish`/`export.fish` if you need fish).

## Requirements

- bash >= 4 or zsh
- git
- python3
- curl (for install/uninstall scripts)
- ESP-IDF prerequisites per OS (cmake, ninja, dfu-util; see
  [Espressif docs](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/linux-macos-setup.html))

## Non-interactive use

Prompts auto-decline when stdin is not a TTY. For CI/scripts:

```bash
ESPVM_YES=1 espvm i 5.4.1    # or: espvm i 5.4.1 -y
```

`ESPVM_STRICT_SIGNED_TAGS=1` makes tag signature verification mandatory
(off by default; Espressif does not GPG-sign release tags).