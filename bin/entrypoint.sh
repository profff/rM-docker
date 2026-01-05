#!/bin/sh
set -eu

SSH_PUBKEY_FILE="/tmp/ssh_pubkey"
SSH_INJECTED_FLAG="/opt/root/.ssh_injected"

inject_ssh_key() {
    if [ ! -f "$SSH_PUBKEY_FILE" ]; then
        echo "No SSH pubkey mounted at $SSH_PUBKEY_FILE, skipping injection"
        return 0
    fi

    if [ -f "$SSH_INJECTED_FLAG" ]; then
        echo "SSH key already injected, skipping"
        return 0
    fi

    echo "Waiting for VM SSH to be ready..."
    wait_ssh

    echo "Injecting SSH public key into VM..."
    PUBKEY=$(cat "$SSH_PUBKEY_FILE")

    # Use sshpass with known password to inject the key
    sshpass -p 'remarkable' ssh -o StrictHostKeyChecking=no root@localhost "
        mkdir -p /home/root/.ssh
        echo '$PUBKEY' >> /home/root/.ssh/authorized_keys
        chmod 700 /home/root/.ssh
        chmod 600 /home/root/.ssh/authorized_keys
    "

    # Mark as done
    touch "$SSH_INJECTED_FLAG"
    echo "SSH key injected successfully!"
}

# Start the VM
run_vm -serial null -daemonize

# Inject SSH key if requested
if [ "${INJECT_SSH_KEY:-false}" = "true" ]; then
    inject_ssh_key
fi

# Connect using the FB emulator
rm2fb-emu 127.0.0.1 8888 &

# Start xochitl
in_vm LD_PRELOAD=/opt/lib/librm2fb_client.so /usr/bin/xochitl
