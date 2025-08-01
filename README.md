# op-credential-helper

**Unofficial third-party tool** - A command-line utility for retrieving credentials from 1Password in multiple output formats.

> ⚠️ **Disclaimer**: This is an unofficial tool and is not affiliated with, endorsed by, or sponsored by AgileBits Inc. (makers of 1Password). It works with the official 1Password CLI.

## Description

- Retrieve useful fields from 1Password using the offical 1Password CLI, "op".
- An attempt will be made to copy the password field to the X selection and clipboard when DISPLAY env variable is found.


## Installation

### Prerequisites

- [1Password CLI](https://developer.1password.com/docs/cli/get-started/) (`op`) - See official installation guide
- `jq` for JSON parsing

### Install Dependencies

**macOS:**

_untested_

```bash
sudo port install jq
```

 - or -
```bash
brew install jq
```

**Ubuntu/Debian:**
```bash
sudo apt install jq xclip
```


## Usage

### 1Password CLI
Make sure that 1Password ClI, "op", is installed and able to connect to
your 1Password instance.

```bash
op whoami
```


### Basic Usage

```bash
# Show all credentials (text format)
./op_creds.sh "My VPN Item"

# Get only username
./op_creds.sh --user "My VPN Item"

# Get username and OTP
./op_creds.sh --user --otp "My VPN Item"
```

### Output Formats

**Text format (default):**
```bash
$ ./op_creds.sh "My VPN Item"
Connecting to 1Password...
✓ Password copied to clipboard and primary selection

# === Credentials for: My VPN Item ===
# Username: myuser
# Password: mypass123
# OTP:      561420
```

**JSON format:**
```bash
$ ./op_creds.sh --format json "My VPN Item"
{"username":"myuser","password":"mypass123","otp":"561420"}
```

**Shell format:**
```bash
./op_creds.sh --format sh "My VPN Item"
USERNAME=myuser
PASSWORD=mypass123
OTP=561420

# Use in sh style scripts:
eval "$(./op_creds.sh --format sh "My VPN Item")"
echo "Connecting with user: $USERNAME"
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `--user` | Output only the username |
| `--pass` | Output only the password |
| `--otp` | Output only the OTP code |
| `--format {format}` | format: text, json, or sh (defaul: text) |
| `-h, --help` | Show help message |

**Note:** Format options are case-insensitive.

## ToDo
 - add option to retrieve a set of specific labels
 - understand how duplicates are handled in op
 - start a process with a timer thread to clear the selection and clipboard
 - test on MacOS including using pbcopy to copy to clipboard


## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
