# Instructions for agents

Use these commands to control the macOS VM from the host. The commands only run on macOS.

## Before using the VM

Run `d2 macos.skill` to print these instructions. In a remote Bash session, source `~/.bash_profile` first if needed to initialise the Dashboard CLI environment. Use `d2 macos.setup` if the VM SSH key or runtime setup is missing. Setup creates the Vagrant SSH key, patches the tap formulae before installing Tart, sets the host Internet Sharing DHCP lease time to 600 seconds, then installs the provider and pulls the macOS image.

## Start and monitor

1. Run `d2 macos.ps` to check the VM state and any previous startup result.
2. Run `d2 macos.up` to create and start the VM headlessly. Use `--gui` to open a VM window, or `-v HOST_PATH:NAME` to share a host directory at `/Volumes/My Shared Files/NAME`. Vagrant runs the plain Bash script without sharing its input with package installers. If Vagrant SSH fails but Tart Guest Agent is ready, startup stages the same script in the guest and runs it through the agent. Headless mode suppresses Tart's UI window; macOS still manages its guest `WindowServer`.
   Startup and provisioning continue in the background.
3. While startup is in progress, use `d2 macos.ps` to see the current step, elapsed time, last log output time, VM address, and SSH reachability. After a successful start, it also shows the previous startup duration and a rough estimate for the current run. The first run has no estimate until a successful duration is recorded.
4. Use `d2 macos.logs -t -f --tail=30` to follow timestamped startup and provisioning output. The guest provisioning script also writes command traces to `/tmp/provision.log`; NVM's internal shell trace is suppressed to keep the log readable. After SSH is ready, retrieve the guest log with `d2 macos.exec cat /tmp/provision.log`.
5. Wait for the provisioning-complete message before relying on the pre-installed tools. A failure to install optional Perl modules is logged as a warning and does not stop Java and Node setup.

If startup times out, read the timeout result in `d2 macos.ps` and inspect `d2 macos.logs -t --tail=50`. If the VM is running but SSH is unreachable, report that state rather than repeatedly starting it.

## Run guest commands

Use `d2 macos.exec <command>` to run a command in the VM through the Tart Guest Agent. Quote shell expressions that must be interpreted inside the VM, for example:

The admin user's Bash profile exports `OPENSSL_PREFIX=/opt/homebrew/opt/openssl@3`.

```sh
d2 macos.exec 'sw_vers -productVersion'
d2 macos.exec 'ps -A -o %cpu,%mem,pid,command'
```

If `macos.exec` says the VM is not running, check `d2 macos.ps`. Use `d2 macos.up` only when creating a new VM. A paused VM must be resumed with `d2 macos.start`; `macos.up` will warn and refuse to restart an existing stopped or paused VM. A running Tart process alone does not mean the guest agent is ready.

The guest includes `htop`, Perl `local::lib`, and the other tools listed in the README. Use `d2 macos.exec htop` to inspect processes interactively.

## Copy files

Use the `vm:` prefix to identify a guest path. The other path is on the host. The VM must be running and ready.

```sh
d2 macos.cp ./notes.txt vm:/Users/admin/notes.txt
d2 macos.cp vm:/Users/admin/output.log ./output.log
d2 macos.rsync -av ./project/ vm:/Users/admin/project/
d2 macos.rsync -av vm:/Users/admin/results/ ./results/
```

`macos.cp` copies directories recursively. `macos.rsync` accepts rsync options before the paths and uses archive mode by default. Both commands return the wrapped copy command's exit status. Keep trailing slashes when their standard rsync meaning is needed. Its `-e` and `--rsh` options are reserved for the VM connection.

## Stop the VM

Run `d2 macos.stop` to pause the VM while preserving its current state, then `d2 macos.start` to resume it. Run `d2 macos.down` to destroy the VM and remove its local state. If Vagrant metadata is missing, `macos.down` removes the matching orphaned Tart VM too.
