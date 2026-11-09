# macOS Vagrant skill

This Developer Dashboard skill starts and controls a macOS virtual machine using Vagrant and Tart. It only runs on macOS hosts, and Tart requires Apple silicon.

## Install

From the directory containing the checkout, install the skill with the Dashboard CLI:

```sh
d2 skills install macos
```

The checkout directory must be named `macos` so the commands are available as `d2 macos.*`. To install from a Git repository, pass its Git URL instead.

Install the prerequisites if they are not already present:

```sh
brew tap hashicorp/tap
brew install hashicorp/tap/hashicorp-vagrant
brew install openai/tools/tart
d2 macos.setup
```

`macos.setup` installs the Vagrant Tart provider plugin.

The Vagrant configuration reads `MACOS_VM_SSH_KEY` from the environment or from `d2 env`. The macOS image is pulled from `ghcr.io/cirruslabs/macos-sequoia-base` when needed.

## Commands

```sh
d2 macos.up
d2 macos.down
d2 macos.exec <command>
d2 macos.setup
```

`macos.down` halts the VM while keeping it available for the next start. `macos.exec` runs a command over SSH in the running VM, using the configured macOS account. Quote shell expressions that should be interpreted inside the VM.

Examples:

```sh
d2 macos.exec uname -a
d2 macos.exec 'sw_vers'
d2 macos.exec 'ls -la /Users/admin'
```

Each command provides its own usage information:

```sh
d2 macos.up --help
d2 macos.down --help
d2 macos.exec --help
d2 macos.setup --help
```
