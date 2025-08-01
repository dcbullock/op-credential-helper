# 1Password CLI Tools

A secure command-line utility for retrieving credentials from 1Password in multiple output formats.

## Features

- **Single API call** - Retrieves username, password, and OTP efficiently
- **Multiple output formats** - Human-readable, JSON, or shell variables
- **Selective field output** - Get only the fields you need
- **Clipboard integration** - Automatic password copying in X11 environments
- **Security focused** - No shell injection vulnerabilities
- **Case-insensitive options** - Flexible command-line interface

## Installation

### Prerequisites

- [1Password CLI](https://developer.1password.com/docs/cli/get-started/) (`op`)
- `jq` for JSON parsing
- `xclip` or `xsel` for clipboard support (optional, Linux only)

### Install Dependencies

**macOS:**
```bash
brew install --cask 1password-cli
brew install jq
```

**Ubuntu/Debian:**
```bash
# Install 1Password CLI
curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli

# Install jq and clipboard tools
sudo apt install jq xclip
```

### Download Script

```bash
# Download the script
curl -O https://raw.githubusercontent.com/yourusername/1password-cli-tools/main/op_creds.sh

# Make it executable
chmod +x op_creds.sh

# Optionally, move to PATH
sudo mv op_creds.sh /usr/local/bin/op_creds
```

## Usage

### Authentication

First, authenticate with 1Password CLI:
```bash
op signin
```

### Basic Usage

```bash
# Show all credentials (human format)
./op_creds.sh "My VPN Item"

# Get only username
./op_creds.sh --user "My VPN Item"

# Get username and OTP
./op_creds.sh --user --otp "My VPN Item"
```

### Output Formats

**Human format (default):**
```bash
./op_creds.sh "My VPN Item"
# === Credentials for: My VPN Item ===
# Username: myuser
# Password: mypass123
# OTP:      561420
```

**JSON format:**
```bash
./op_creds.sh --format json "My VPN Item"
# {"username":"myuser","password":"mypass123","otp":"561420"}
```

**Shell format:**
```bash
./op_creds.sh --format sh "My VPN Item"
# USERNAME='myuser'
# PASSWORD='mypass123'
# OTP='561420'

# Use in scripts:
eval "$(./op_creds.sh --format sh "My VPN Item")"
echo "Connecting with user: $USERNAME"
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `--user` | Output only the username |
| `--pass` | Output only the password |
| `--otp` | Output only the OTP code |
| `--format FMT` | Output format: `human`, `json`, or `sh` |
| `-h, --help` | Show help message |

**Note:** All options are case-insensitive (`--USER`, `--FORMAT JSON`, etc.)

### Examples

```bash
# Automation with JSON
CREDS=$(./op_creds.sh --format json "API Keys")
API_KEY=$(echo "$CREDS" | jq -r '.password')

# Shell integration
eval "$(./op_creds.sh --format sh --user --pass "Database")"
mysql -u "$USERNAME" -p"$PASSWORD" mydb

# Get just the OTP for 2FA
./op_creds.sh --otp "Google Account"

# Case insensitive usage
./op_creds.sh --USER --FORMAT SH "My Item"
```

## Security

- **No shell injection vulnerabilities** - Uses safe variable assignment
- **Secure clipboard handling** - Only copies when explicitly retrieving password
- **Proper shell escaping** - Shell format output is safely quoted
- **Single authentication** - Efficient API usage

## Requirements

- 1Password CLI v2.0 or later
- jq 1.6 or later
- Bash 4.0 or later

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## ToDo

 - add option to retrieve a set of specific labels
 - understand how duplicates are handled in op
 - start a process with a timer thread to clear the selection and clipboard

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

### v1.0.0
- Initial release
- Support for human, JSON, and shell output formats
- Selective field output
- Case-insensitive options
- Clipboard integration for X11 environments

---

**Repository Structure:**
```
1password-cli-tools/
├── README.md          # This file
├── LICENSE            # MIT License
├── op_creds.sh        # Main script
├── .gitignore         # Git ignore file
└── examples/          # Usage examples
    ├── automation.sh  # Automation examples
    └── integration.sh # Integration examples
```
