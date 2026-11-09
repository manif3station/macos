# macOS skill

This Developer Dashboard skill starts and controls a macOS virtual machine with Tart. It only runs on macOS hosts, and Tart requires Apple silicon.

## Install

From the directory containing the checkout, install the skill with the Dashboard CLI:

```sh
d2 skills install macos
```

The checkout directory must be named `macos` so the commands are available as `d2 macos.*`. To install from a Git repository, pass its Git URL instead.

Install the prerequisites if they are not already present:

```sh
brew install openai/tools/tart
d2 macos.setup
```

The VM runtime, Tart, and `d2` must be available on `PATH`. `macos.setup` installs the Tart provider and pulls the macOS image.

Setup creates a VM-specific SSH key pair at `~/.ssh/d2macOs` and `~/.ssh/d2macOs.pub`. The VM configuration uses `MACOS_VM_SSH_KEY` when set; otherwise it uses `~/.ssh/d2macOs.pub`. Setup also pulls `ghcr.io/cirruslabs/macos-sequoia-base:latest`.

## Commands

```sh
d2 macos.up
d2 macos.down
d2 macos.exec <command>
d2 macos.setup
```

`macos.down` halts the VM while keeping it available for the next start. `macos.exec` runs a command over SSH in the running VM, using the configured macOS account. Quote shell expressions that should be interpreted inside the VM.

Run `d2 macos.setup` before `macos.up`, `macos.down`, or `macos.exec` if the SSH public key is missing. `macos.exec` also asks you to run `d2 macos.up` first when the VM is not running.

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

This project is available under the MIT licence; see [LICENSE](LICENSE).
