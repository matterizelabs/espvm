# `espvm` - ESP SDK Version Manager

Manage multiple ESP-IDF and ESP-Matter versions using git worktree.

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

## Usage

```bash
espvm idf install 5.4.1      # Install ESP-IDF v5.4.1
espvm idf use 5.4.1          # Activate in current shell
espvm idf list               # List installed versions
espvm idf list-remote        # List available tags/branches

espvm matter install 1.0     # Install ESP-Matter
espvm matter use 1.0

espvm config                 # Show configuration
```

## Commands

| Command | Description |
|---------|-------------|
| `install <ver> [-v] [--force]` | Install version |
| `use <ver> [-v]` | Activate version |
| `list` | List installed versions |
| `list-remote` | List available tags/branches |
| `remove <ver>` | Remove version |
| `update <ver>` | Update version |
| `current` | Show active version |
| `repair` | Fix broken worktree links |

## Configuration

```bash
espvm config set worktree-dir /path/to/versions
espvm config set use-ssh yes    # yes, no, auto
espvm config reset
```

Config stored at `~/.espressif/.espvm/config`

## Requirements

- git
- python3
