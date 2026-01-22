# `espvm` - ESP SDK Version Manager

Manage multiple ESP-IDF and ESP-Matter versions efficiently.

- ESP-IDF: Uses git worktree for disk/network efficiency
- ESP-Matter: Uses shallow clones (worktree incompatible with its submodules)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/matterizelabs/espvm/main/install.sh | bash
```

Or manually:
```bash
curl -o ~/.local/bin/espvm https://raw.githubusercontent.com/matterizelabs/espvm/main/espvm
chmod +x ~/.local/bin/espvm
echo 'source ~/.local/bin/espvm' >> ~/.bashrc
```

## Quick Start

```bash
# Install and activate ESP-IDF
espvm i 5.4.1           # Install
espvm 5.4.1             # Activate (or install if needed)

# Install and activate ESP-Matter (requires IDF active)
espvm -m i 1.4          # Install Matter
espvm -m 1.4            # Activate Matter
```

## Usage

```bash
espvm [-i|-m] <version>     # Activate version (install if needed)
espvm [-i|-m] <command>     # Run command

# SDK Flags
#   -i    ESP-IDF (default)
#   -m    ESP-Matter
```

## Commands

| Short | Full | Description |
|-------|------|-------------|
| `i` | `install` | Install version |
| `use` | `use` | Activate version |
| `ls` | `list` | List installed |
| `remote` | `list-remote` | List available tags/branches |
| `rm` | `remove` | Remove version |
| | `update` | Update version |
| | `current` | Show active version |
| | `status` | Show all active SDKs |
| | `repair` | Fix broken worktree links (IDF only) |

## Examples

```bash
# ESP-IDF
espvm 5.4.1             # Activate IDF 5.4.1
espvm i 5.5             # Install IDF 5.5
espvm ls                # List installed IDF versions
espvm remote            # List available IDF versions
espvm rm 5.3            # Remove IDF 5.3

# ESP-Matter
espvm -m i 1.4          # Install Matter 1.4
espvm -m 1.4            # Activate Matter 1.4
espvm -m ls             # List installed Matter versions

# Status
espvm status            # Show active IDF and Matter versions

# Legacy syntax still works
espvm idf install 5.4.1
espvm matter use 1.4
```

## Configuration

```bash
espvm config                          # Show config
espvm config set worktree-dir /path   # Set versions directory
espvm config set use-ssh yes          # yes, no, auto
espvm config reset                    # Reset to defaults
```

Config stored at `~/.espressif/.espvm/config`

## Requirements

- git
- python3
