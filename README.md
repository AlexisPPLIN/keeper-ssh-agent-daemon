# 🔐 Keeper SSH-agent daemon

This repository works around a limitation in Keeper Commander CLI's `ssh-agent` implementation.
See [Keeper-Security/Commander#965](https://github.com/Keeper-Security/Commander/issues/965).

> ℹ️ **Note**
> Keeper's Desktop app does have its own built-in ssh-agent, but it's only available with a **KeeperPAM** subscription. Keeper Commander, on the other hand, is free — hence this workaround.


## ✨ Features

- 🖥️ Runs `keeper ssh-client` as a background service using `screen`.
- 🔑 Handles the login flow with `zenity`.
- 🔗 Automatically registers `SSH_AUTH_SOCK` in `~/.bashrc` so ssh-agent is available in every program.
- 📤 Automatically extracts a public key file (in `~/.ssh/keeper/`) for each SSH private key in your Keeper Vault.

## 📋 Requirements

- [Keeper Commander CLI](https://docs.keeper.io/keeperpam/commander-cli/commander-installation-setup)
- [bash](https://command-not-found.com/bash)
- [screen](https://command-not-found.com/screen)
- [zenity](https://command-not-found.com/zenity)

## 📊 Compatibility chart

| Version | Compatibility |
| ------- | :------------: |
| 16.X    | ❌ |
| 17.X    | ❌ |
| 18.X    | ✅ |

- ✅ Working and fully tested
- 🟧 Working but not fully tested
- ❔ Not tested
- ❌ Tested and does not work

## 🚀 Installation

### 📦 Download

You can get the code either by downloading a release or by cloning the repository.

**Option 1 — GitHub release:**

Grab the latest release from the [GitHub releases page](https://github.com/AlexisPPLIN/keeper-ssh-agent-daemon/releases), then extract it:

```bash
tar -xzf keeper-ssh-agent-daemon-<version>.tar.gz
cd keeper-ssh-agent-daemon-<version>
```

**Option 2 — Git clone:**

```bash
git clone https://github.com/AlexisPPLIN/keeper-ssh-agent-daemon.git
cd keeper-ssh-agent-daemon
```

### 🧍 Standalone

Use the script without a service:

```bash
./keeper-ssh.sh start   # Start daemon
./keeper-ssh.sh stop    # Stop daemon
```

### ⚙️ Systemd (service)

```bash
./keeper-ssh.sh install-service
```

### 🔍 Check if keys are loaded

Open a new terminal so the ssh-agent socket is picked up, then run:

```bash
ssh-add -l
```

You should see all your SSH keys listed. 🎉

## 🗑️ Uninstallation

```bash
./keeper-ssh.sh remove-service
```

## 🛠️ Usage

### 🤖 Unattended login

If you start the daemon while no user is logged in, it opens a login prompt.
For unattended setups, log in before starting the daemon instead:

```bash
./keeper-ssh.sh login <email> <password> <server>
```

### 🔄 Updating keys after a vault change

After adding or removing keys in your vault, restart the script/service:

- **Standalone:** `./keeper-ssh.sh stop && ./keeper-ssh.sh start`
- **Service:** `systemctl --user restart keeper-ssh`

### 📱 2FA login

Only `email-send` 2FA is supported for now.
On first login, you'll receive an email — click **Approve Device and Location**.

A workaround is to log in manually via [Unattended login](#unattended-login) first, then run the `keeper-ssh` script.

### 🔑 Using a specific key per SSH host

Say your Keeper Vault has a `main-server` and a `dev-server` SSH key. In `~/.ssh/config`:

```
Host main-server.example.com
    ForwardAgent yes
    IdentityFile ~/.ssh/keeper/main-server.pub

Host dev-server.example.com
    ForwardAgent yes
    IdentityFile ~/.ssh/keeper/dev-server.pub
```

Running `ssh user@main-server.example.com` will make ssh-agent offer only the `main-server` key, without trying `dev-server`.

### ✍️ Git commit SSH signing

Similarly, you can use your public key to sign Git commits. In `~/.gitconfig`:

```
[gpg]
	format = ssh
[user]
	signingkey = ~/.ssh/keeper/user.pub
```