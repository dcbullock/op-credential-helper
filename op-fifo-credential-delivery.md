# 1Password FIFO Credential Delivery

## Problem Statement

Many applications expect credentials to be provided via file paths (e.g., OpenVPN's `--auth-user-pass`, `--askpass`). Storing credentials in files creates risk of:

- Orphaned credentials after crashes
- Credentials captured by backup systems
- Credentials found by scanning tools
- Forgotten cleanup leaving breadcrumbs

## Solution: FIFO + 1Password CLI

Use named pipes (FIFOs) as the delivery mechanism, with 1Password as the authentication gate. Credentials never exist on disk—they materialize only at the moment of use, gated by 1Password's session authentication (biometric/password via polkit).

## Architecture

```
Application                FIFO                 Feeder              1Password
    │                        │                     │                     │
    │ open(fifo_path)        │                     │                     │
    │───────────────────────>│                     │                     │
    │                        │ (blocks)            │                     │
    │                        │                     │                     │
    │                        │  write unblocks     │                     │
    │                        │<────────────────────│                     │
    │                        │                     │                     │
    │                        │                     │ op read 'op://...'  │
    │                        │                     │────────────────────>│
    │                        │                     │                     │
    │                        │                     │   [if locked]       │
    │                        │                     │   polkit prompt     │
    │                        │                     │   biometric/passwd  │
    │                        │                     │                     │
    │                        │                     │<────────────────────│
    │                        │                     │   credential        │
    │                        │<────────────────────│                     │
    │                        │   write to fifo     │                     │
    │<───────────────────────│                     │                     │
    │   read credential      │                     │                     │
    │                        │                     │                     │
    │   (consumed)           │   (empty)           │   (loops/waits)     │
```

## Key Properties

### Security Model

| Layer | Protection |
|-------|------------|
| 1Password session | Primary gate - biometric/password required when locked |
| Unix permissions | FIFO created mode 600, owned by user |
| Ephemeral delivery | Credential in kernel buffer only during transfer |
| No persistence | Nothing on disk to leak, backup, or forget |

### FIFO vs Temp File

| Aspect | Temp File | FIFO |
|--------|-----------|------|
| Data at rest | Yes, until deleted | Never |
| Survives crash | Yes (orphaned) | No |
| Backup/copy risk | Yes | No |
| Credential scanners | Will find it | Nothing to find |
| Cleanup required | Yes | No |
| Re-read on TLS renegotiation | Works | Requires feeder loop |

### Threat Model

**In scope (solved by this approach):**
- Accidental credential persistence on disk
- Orphaned credentials after crash/kill
- Credentials in backups
- Forgotten cleanup

**Out of scope (accepted risks):**
- Local attacker with root timing a FIFO read race
- Attacker who can impersonate the application to open FIFO first
- Compromised 1Password session

## Implementation

### Minimal Feeder Script

```bash
#!/bin/bash
# op-fifo: serve a 1Password item field as a FIFO

OP_URI="$1"
FIFO_PATH="$2"

[[ -z "$OP_URI" || -z "$FIFO_PATH" ]] && {
    echo "Usage: op-fifo <op://uri> <fifo-path>" >&2
    exit 1
}

cleanup() { rm -f "$FIFO_PATH"; }
trap cleanup EXIT

mkfifo -m 600 "$FIFO_PATH"

while true; do
    # Blocks until reader opens FIFO
    # Then fetches from 1Password (may prompt for auth)
    op read "$OP_URI" > "$FIFO_PATH" 2>/dev/null || {
        echo "op read failed" >&2
        sleep 1
    }
done
```

### OpenVPN Example

```bash
#!/bin/bash
set -e

FIFO_USER=/tmp/vpn_user_$$.fifo
FIFO_KEY=/tmp/vpn_key_$$.fifo

cleanup() {
    kill $FEEDER_USER_PID $FEEDER_KEY_PID 2>/dev/null || true
    rm -f "$FIFO_USER" "$FIFO_KEY"
}
trap cleanup EXIT

mkfifo -m 600 "$FIFO_USER" "$FIFO_KEY"

# Feeder for username + password (two lines)
(
    while true; do
        {
            op read 'op://Vault/CineCert VPN/username'
            op read 'op://Vault/CineCert VPN/password'
        } > "$FIFO_USER"
    done
) &
FEEDER_USER_PID=$!

# Feeder for key passphrase
(
    while true; do
        op read 'op://Vault/CineCert VPN/keypass' > "$FIFO_KEY"
    done
) &
FEEDER_KEY_PID=$!

sleep 0.1  # Let feeders initialize

sudo openvpn --config config.conf \
    --auth-user-pass "$FIFO_USER" \
    --askpass "$FIFO_KEY"
```

### Process Substitution Alternative (Simple Cases)

For applications that only read credentials once (no re-read on renegotiation):

```bash
sudo openvpn --config config.conf \
    --auth-user-pass <(printf '%s\n%s\n' \
        "$(op read 'op://Vault/CineCert VPN/username')" \
        "$(op read 'op://Vault/CineCert VPN/password')") \
    --askpass <(op read 'op://Vault/CineCert VPN/keypass')
```

Note: This breaks with `auth-nocache` since the FIFO disappears after first read.

## Integration with op_creds

Existing `op_creds` script handles formatting (shell, json, human). FIFO delivery is orthogonal—a new output mode:

```bash
# Proposed interface
op_creds --format fifo --item 'CineCert VPN' --field password --path /tmp/cc-pass.fifo

# Or as subcommand
op_creds serve 'CineCert VPN' password /tmp/cc-pass.fifo
```

## Related Work

### KeywhizFS (Square, deprecated)

FUSE filesystem that presented secrets from Keywhiz server as files. Each service got a mounted directory with its secrets as read-only files.

Key features:
- `mlockall()` to keep secrets out of swap
- Unix permissions for local access control
- Caching with TTL
- Control files (`.clear_cache`)

Deprecated in favor of Kubernetes sidecar patterns.

### SecretFS (obormot)

FUSE filesystem with **process-based ACLs**:

```ini
[app-foo-secret1]
path = secret1.txt
process = /usr/bin/foo    # Only this binary can read
user = ubuntu
ttl = 60                  # Only accessible 60s after process start
```

Intercepts `open()` and checks *who* is asking before allowing read.

### HashiCorp Vault Agent

No FUSE. Instead:
1. Agent authenticates to Vault
2. Renders templates with secrets interpolated
3. Writes to files ("sinks") that applications read
4. Re-renders on secret rotation

```hcl
template {
  source      = "/etc/app/config.tmpl"
  destination = "/etc/app/config.yaml"
}
```

## Future Considerations

### Enhanced Access Control

The FIFO approach could be extended with:

- **Caller validation**: Check `/proc/<pid>/exe` before feeding
- **One-shot mode**: Only serve credential once, then exit
- **Audit logging**: Log each credential access with timestamp and requestor

### Systemd Integration

```ini
[Unit]
Description=1Password FIFO for CineCert VPN

[Service]
ExecStart=/usr/local/bin/op-fifo 'op://Vault/CineCert/password' /run/op/cinecert-pass.fifo
RuntimeDirectory=op
```

### Socket Activation

Let systemd create the FIFO and start the feeder on first access:

```ini
[Socket]
ListenFIFO=/run/op/cinecert-pass.fifo
```

## Summary

Named pipes provide a simple, crash-safe mechanism for just-in-time credential delivery. Combined with 1Password's session authentication, credentials materialize only when:

1. An application actually requests them
2. The user authenticates to 1Password (if session locked)

No FUSE complexity, no kernel modules, no capabilities required. Just Unix pipes doing what they've done since the 1970s, with 1Password as the security gate.
