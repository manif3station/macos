# macOS skill

This Developer Dashboard skill starts and controls a macOS virtual machine with Tart. It only runs on macOS hosts, and Tart requires Apple silicon.

## Install

From the directory containing the checkout, install the skill with the Dashboard CLI:

```sh
d2 skills install macos
```

The checkout directory must be named `macos` so the commands are available as `d2 macos.*`. To install from a Git repository, pass its Git URL instead.

To refresh the installed skill after changing this checkout, run this from the checkout directory:

```sh
d2 skills install "$PWD"
```

Check that the installer reports an update before using the refreshed `d2 macos.*` commands.

Install the prerequisites if they are not already present:

```sh
d2 macos.setup
```

The VM runtime, Homebrew, and `d2` must be available on `PATH`. `macos.setup` trusts the Cirrus Labs tap, installs Tart, patches its Homebrew formula dependencies, installs the provider, and pulls the macOS image. `macos.up` returns while the VM is provisioning in the background; check progress with `d2 macos.ps`.

Setup creates a VM-specific SSH key pair at `~/.ssh/d2macOs` and `~/.ssh/d2macOs.pub`. The VM configuration uses `MACOS_VM_SSH_KEY` when set; otherwise it uses `~/.ssh/d2macOs.pub`. Setup also pulls `ghcr.io/cirruslabs/macos-sequoia-base:latest`.

## Commands

```sh
d2 macos.up
d2 macos.down
d2 macos.exec <command>
d2 macos.setup
d2 macos.ps
d2 macos.logs
```

`macos.down` halts the VM while keeping it available for the next start. `macos.exec` runs a command over SSH in the running VM, using the configured macOS account. Quote shell expressions that should be interpreted inside the VM.

`macos.ps` reports the VM process ID, macOS version, start time, and elapsed runtime. It also lists the guest processes with the highest CPU and memory use. If startup is still in progress, it shows the provisioning process and log path.

`macos.logs` prints the startup log and exits by default. Use `-f` to follow it, `--tail N` or `--tail=N` to select the last N lines, and `-t` to read the timestamped log. These options can be combined.

Each checkout uses a dedicated VM name so separate checkouts can run without colliding.

When provisioning is complete, Homebrew is installed with Perl, cpanm, Git, Vim, tmux, OpenSSH, OpenSSL 3, curl, Go, Rust, Python 3, GCC, make, SDKMAN, and NVM. Perl `local::lib` is installed for the admin user. SDKMAN installs Maven and Java 21 and 25. NVM installs Node.js 26 and the available Node.js 27 alpha release, including `npm` and `npx`. Python includes `venv`, and GCC provides C and C++ compilers. The admin user's Bash profile configures the editor, pager, terminal type, Apple Terminal integration, and Perl local library path; Readline disables bracketed paste. `d2 macos.exec` waits until provisioning has finished before running commands.

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
d2 macos.ps --help
d2 macos.logs --help
```

This project is available under the MIT licence; see [LICENSE](LICENSE).
