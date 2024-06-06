# Keeper SSH-agent daemon

> ⚠️ Warning :  
> This script is not tested enough to be considered as stable, use with precaution.  
> I'm not responsible if my code breaks your machine.

This repository is a workaround of Keeper Commander CLI limitation with his implementation of `ssh-agent`.  
See : https://github.com/Keeper-Security/Commander/issues/965

## Features

- Runs `keeper ssh-client` as a background service using `screen`.
- Handles login flow with `zenity`.
- Auto register `SSH_AUTH_SOCK` into `~/.bashrc` to use ssh-agent in every programs.
- Auto extract public keys files (in `~/.ssh/keeper/`) for each ssh private keys in your Keeper Vault.
- Stores keeper config file into Gnome Keyring (libsecret).

## Requirements

- Keeper Commander CLI : [How to install](https://docs.keeper.io/secrets-manager/commander-cli/commander-installation-setup/installation-on-linux)
- bash (GNU) : [How to install](https://command-not-found.com/bash)
- screen (GNU) : [How to install](https://command-not-found.com/screen)
- expect (sgolovan@debian.org) : [How to install](https://command-not-found.com/expect)
- Gnome Keyring / libsecret : Should already be installed on your distro

## Compatibility chart

| OS  | Commander 16.X |
| ------------- | ------------- |
| Fedora 39 (GNOME) | ✅ |
| Fedora 40 (GNOME) | ✅ |

- ✅ : Working and fully tested.
- 🟧 : Working but not fully tested.
- ❔ : Not tested.
- ❌ : Tested and does not work.

# How to install

## Standalone

You can use this script without a service :
- `./keeper-ssh.sh start` : Start daemon
- `./keeper-ssh.sh stop` : stop daemon

## Systemd (service)

Install service with the following command :  
`./keeper-ssh.sh install-service`

## Check if keys are loaded
You should open a new terminal for ssh-agent socket to be used.  
Then run `ssh-add -l` and you should see all your ssh keys.

# How to uninstall

Remove service with the following command :  
`./keeper-ssh.sh remove-service`

# Usage

## Unattended login

If you start the deamon and no user is logged, it will open a prompt.  
But if you love unattended install like me, you can use the login command before starting the deamon.

`./keeper-ssh.sh login <email> <password> <server>`

## Update keys on vault update

When you add or remove keys from your vault, you need to re-run the script / restart the service.

- Standalone : `./keeper-ssh.sh stop && ./keeper-ssh.sh start`
- Service : `systemctl --user restart keeper-ssh`

## 2FA login

For now this script only support `email-send` 2FA.  
On first login you should recieve an email, click `Approve Device and Location`.

One workaround, is to login manually using `Unattended login (see above)` and then run the `keeper-ssh` script.

## Use specific key for ssh host

In Keeper you have a `main-server` and `dev-server` ssh keys

```
~/.ssh/config :

Host main-server.example.com
    ForwardAgent yes
    IdentityFile ~/.ssh/keeper/main-server.pub

Host dev-server.example.com
    ForwardAgent yes
    IdentityFile ~/.ssh/keeper/dev-server.pub
```

Then when you do : `ssh user@main-server.example.com`  
ssh-agent will only return main-server private key and not try `dev-server` key.

## Git commit ssh signing

In the same way of `~/.ssh/config`, you can use your public key to sign commit on git :

```
~/.gitconfig :

[gpg]
	format = ssh
[user]
	signingkey = ~/.ssh/keeper/user.pub
```