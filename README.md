# macOS skill

Version 1.28

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

If Vagrant is installed in `/usr/local/bin` or `/opt/vagrant/bin`, the commands add that location when it is missing from `PATH`.

The VM runtime, Homebrew, and `d2` must be available on `PATH`. `macos.setup` trusts the Cirrus Labs tap, patches the Homebrew formula dependencies before installing Tart, sets the host Internet Sharing DHCP lease time to 600 seconds, installs the provider, and pulls the macOS image. `macos.up` runs headlessly by default and returns while the VM is provisioning in the background; pass `--gui` to open a VM window. Vagrant runs the plain Bash script without sharing its input with package installers; if Vagrant SSH fails but the Tart Guest Agent is ready, `macos.up` stages and runs the same script through the agent. Follow this work with `d2 macos.ps` and `d2 macos.logs -t -f`; wait for the provisioning-complete message before relying on the pre-installed tools. Headless mode suppresses Tart's UI window; macOS still manages its guest `WindowServer`.

Setup creates a VM-specific SSH key pair at `~/.ssh/d2macOs` and `~/.ssh/d2macOs.pub`. Vagrant uses this pair for key-based SSH and file transfers; setup provisions the public key into the VM's `admin` account. The `dev` account uses `MACOS_VM_SSH_KEY` when set, otherwise `~/.ssh/d2macOs.pub`. Setup also pulls `ghcr.io/cirruslabs/macos-sequoia-base:latest`.

## Commands

```sh
d2 macos.up
d2 macos.up --gui
d2 macos.up -v "$PWD":project
d2 macos.up -v ./foobar:foobar
d2 macos.stop
d2 macos.start
d2 macos.down
d2 macos.exec <command>
d2 macos.cp <host-path> vm:<vm-path>
d2 macos.cp vm:<vm-path> <host-path>
d2 macos.rsync [rsync-options...] <host-path> vm:<vm-path>
d2 macos.rsync [rsync-options...] vm:<vm-path> <host-path>
d2 macos.setup
d2 macos.ps
d2 macos.logs
d2 macos.skill
```

`macos.skill` prints [SKILLS.md](SKILLS.md), which gives agents the workflow for checking, starting, monitoring, using, and stopping the VM.

`macos.stop` pauses the VM and preserves its running state. Resume it with `macos.start`. `macos.up` does not restart an existing stopped or paused VM; it reports the appropriate command instead. `macos.down` destroys the VM and removes its local state, including a Tart VM left behind if Vagrant metadata is missing. `macos.exec` runs a command through the Tart Guest Agent in the running VM and supports interactive commands when attached to a terminal. Quote shell expressions that should be interpreted inside the VM.

`macos.up -v HOST_PATH:NAME` shares a host directory with the guest at `/Volumes/My Shared Files/NAME`. Relative paths are resolved to an absolute host path, and multiple `-v` options are supported.

`macos.cp` copies files and directories recursively in either direction and returns the copy command's exit status. Mark the VM side with `vm:`, for example `d2 macos.cp ./notes.txt vm:/Users/admin/notes.txt` or `d2 macos.cp vm:/Users/admin/output.log ./output.log`.

`macos.rsync` synchronises files in either direction and accepts rsync options before the two paths. It uses archive mode by default, preserves standard trailing-slash behaviour, and returns rsync's exit status. For example, `d2 macos.rsync -av ./project/ vm:/Users/admin/project/`. The `-e` and `--rsh` options are reserved for the VM connection.

`macos.ps` reports the configured VM name, Tart process ID, IP address, macOS version, start time, and elapsed runtime. During startup it explains the current step, shows the last log line and how long ago it changed, and reports whether SSH is reachable. It also shows startup elapsed time and, after a successful start, the previous startup duration with a rough remaining-time estimate. The first run has no estimate until a successful startup duration is recorded. It lists the guest processes with the highest CPU and memory use when the VM is ready.

`macos.logs` prints startup and guest provisioning output, then exits by default. Provisioning commands are traced into `/tmp/provision.log` in the guest and streamed into the host-side startup log. Use `-f` to follow it, `--tail N` or `--tail=N` to select the last N lines, and `-t` to read the timestamped log. These options can be combined. After SSH is ready, read the guest copy with `d2 macos.exec cat /tmp/provision.log`.

Each checkout uses a dedicated VM name so separate checkouts can run without colliding.

When provisioning is complete, Homebrew is installed with Perl, cpanminus, htop, Git, Vim, tmux, OpenSSH, OpenSSL 3, curl, Go, Rust, Python 3, GCC, make, SDKMAN, and NVM. Perl `local::lib`, Dist::Zilla, Devel::Cover, Devel::NYTProf, and Perl::Tidy are installed for the admin user. Failures in optional Perl modules are logged as warnings so setup can continue. SDKMAN installs Maven and Java 21 and 25. NVM installs Node.js 26 and the available Node.js 27 alpha release, including `npm` and `npx`. Python includes `venv`, and GCC provides C and C++ compilers. The admin user's Bash profile configures the editor, pager, terminal type, Apple Terminal integration, Perl local library path, and `OPENSSL_PREFIX=/opt/homebrew/opt/openssl@3`; Readline disables bracketed paste. `d2 macos.exec` waits for an active startup job; after startup fails, it can still run guest-agent commands for diagnosis, though development tools may not be ready.

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
d2 macos.stop --help
d2 macos.start --help
d2 macos.down --help
d2 macos.exec --help
d2 macos.cp --help
d2 macos.rsync --help
d2 macos.setup --help
d2 macos.ps --help
d2 macos.logs --help
d2 macos.skill --help
```

This project is available under the MIT licence; see [LICENSE](LICENSE).
