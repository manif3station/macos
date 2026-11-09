Vagrant.configure("2") do |config|
  # Configure Tart Provider Settings
  config.vm.provider :tart do |tart|
    tart.image = "ghcr.io/cirruslabs/macos-sequoia-base:latest"
    tart.name = "my-custom-mac-vm"
    tart.cpus = 4
    tart.memory = 6144
    tart.disk = 50
    tart.gui = true
  end

  config.ssh.username = "admin"
  config.ssh.password = "admin"

  # Prefer an explicit public key; otherwise use the key created by macos.setup.
  MY_SSH_PUB_KEY = if ENV['MACOS_VM_SSH_KEY'] && !ENV['MACOS_VM_SSH_KEY'].strip.empty?
    ENV['MACOS_VM_SSH_KEY']
  else
    default_key_path = File.expand_path('~/.ssh/d2macOs.pub')
    File.read(default_key_path).strip if File.file?(default_key_path)
  end

  # Safety Check: Halt deployment if the environment variable is missing
  if MY_SSH_PUB_KEY.nil? || MY_SSH_PUB_KEY.strip.empty?
    raise Vagrant::Errors::VagrantError, "SSH public key is unavailable. Set MACOS_VM_SSH_KEY or run d2 macos.setup to create ~/.ssh/d2macOs.pub."
  end

  # Shell provisioning script to set up user, SSH keys, and Homebrew
  config.vm.provision "shell", inline: <<-SHELL
    echo "=== Starting custom VM Provisioning ==="

    # 1. Create the 'dev' user if it doesn't exist
    if ! id "dev" &>/dev/null; then
      echo "Creating 'dev' user..."
      sudo sysadminctl -addUser dev -fullName "Developer" -password "password" -admin
    fi

    # 2. Configure the .ssh directory and authorized_keys for the 'dev' user
    DEV_HOME="/Users/dev"
    echo "Configuring SSH authorized_keys for dev user..."
    sudo mkdir -p "$DEV_HOME/.ssh"
    echo "#{MY_SSH_PUB_KEY}" | sudo tee "$DEV_HOME/.ssh/authorized_keys" > /dev/null

    # Set strict ownership and permissions required by SSH daemon
    sudo chown -R dev:staff "$DEV_HOME/.ssh"
    sudo chmod 700 "$DEV_HOME/.ssh"
    sudo chmod 600 "$DEV_HOME/.ssh/authorized_keys"

    # 3. Ensure Remote Login (SSH) is enabled on the system
    echo "Enabling System SSH Remote Login..."
    sudo systemsetup -setremotelogin on

    # 4. Install Homebrew non-interactively as the 'dev' user
    if ! command -v brew &>/dev/null; then
      echo "Installing Homebrew..."
      sudo -u dev -i bash -c '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)' < /dev/null

      # Inject Homebrew evaluation paths into the dev user's shell profile
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$DEV_HOME/.zprofile"
    else
      echo "Homebrew is already installed."
    fi

    echo "=== Provisioning Complete! ==="
  SHELL
end
