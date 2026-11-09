Vagrant.configure("2") do |config|
  # Configure Tart Provider Settings
  config.vm.provider :tart do |tart|
    tart.image = "ghcr.io/cirruslabs/macos-sequoia-base:latest"
    tart.name = "d2-macos-skill-vm"
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
  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    exec /bin/bash -s <<'BASH'
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

    # 4. Install Homebrew for the Vagrant SSH user and install development tools
    BREW_BIN="/opt/homebrew/bin/brew"
    if [ ! -x "$BREW_BIN" ]; then
      echo "Installing Homebrew..."
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    eval "$("$BREW_BIN" shellenv)"
    echo "Installing development tools..."
    "$BREW_BIN" tap sdkman/tap
    "$BREW_BIN" trust sdkman/tap
    "$BREW_BIN" install perl cpanminus git vim tmux openssh openssl@3 htop curl go rust python gcc make sdkman-cli nvm

    if ! perl -I "$HOME/perl5/lib/perl5" -Mlocal::lib -e 'exit 0' >/dev/null 2>&1; then
      echo "Installing local::lib for the admin user..."
      cpanm --local-lib "$HOME/perl5" local::lib Dist::Zilla Devel::Cover Devel::NYTProf Perl::Tidy
    fi

    SDKMAN_DIR="$("$BREW_BIN" --prefix sdkman-cli)/libexec"
    export SDKMAN_DIR
    mkdir -p "$SDKMAN_DIR/etc"
    SDKMAN_CONFIG="$SDKMAN_DIR/etc/config"
    touch "$SDKMAN_CONFIG"
    if grep -q '^sdkman_auto_answer=' "$SDKMAN_CONFIG"; then
      sed -i '' 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "$SDKMAN_CONFIG"
    else
      echo 'sdkman_auto_answer=true' >> "$SDKMAN_CONFIG"
    fi
    source "$SDKMAN_DIR/bin/sdkman-init.sh"

    JAVA_VERSIONS=$(curl -fsSL 'https://api.sdkman.io/2/candidates/java/darwinarm64/versions/list?installed=')
    JAVA_21_VERSION=$(printf '%s\n' "$JAVA_VERSIONS" | awk -F '|' '$4 ~ /^[[:space:]]*21[.]/ && $4 ~ /-tem[[:space:]]*$/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4; exit }')
    JAVA_25_VERSION=$(printf '%s\n' "$JAVA_VERSIONS" | awk -F '|' '$4 ~ /^[[:space:]]*25[.]/ && $4 ~ /-tem[[:space:]]*$/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4; exit }')
    if [ -z "$JAVA_21_VERSION" ] || [ -z "$JAVA_25_VERSION" ]; then
      echo "Could not find Java 21 and Java 25 Temurin releases in SDKMAN." >&2
      exit 1
    fi

    if [ ! -d "$SDKMAN_DIR/candidates/maven/current" ]; then
      sdk install maven
    fi
    if [ ! -d "$SDKMAN_DIR/candidates/java/$JAVA_21_VERSION" ]; then
      sdk install java "$JAVA_21_VERSION"
    fi
    if [ ! -d "$SDKMAN_DIR/candidates/java/$JAVA_25_VERSION" ]; then
      sdk install java "$JAVA_25_VERSION"
    fi
    sdk default java "$JAVA_25_VERSION"

    NVM_DIR="$HOME/.nvm"
    export NVM_DIR
    NVM_ONLY="alpha,lts,non-lts,iojs"
    export NVM_ONLY
    mkdir -p "$NVM_DIR"
    source /opt/homebrew/opt/nvm/nvm.sh
    for NODE_MAJOR in 26 27; do
      NODE_INSTALLED=false
      for NODE_DIR in "$NVM_DIR"/versions/node/v"$NODE_MAJOR".*; do
        if [ -d "$NODE_DIR" ]; then
          NODE_INSTALLED=true
          break
        fi
      done
      if [ "$NODE_INSTALLED" = false ]; then
        if ! nvm install "$NODE_MAJOR"; then
          nvm install --only=alpha "$NODE_MAJOR"
        fi
      fi
    done
    nvm alias default 27

    for PROFILE in "$HOME/.zprofile" "$HOME/.bash_profile"; do
      touch "$PROFILE"
      if grep -Fq '/opt/homebrew/opt/openjdk@25/bin' "$PROFILE"; then
        sed -i '' '/\/opt\/homebrew\/opt\/openjdk@25\/bin/d' "$PROFILE"
      fi
      if ! grep -Fq '/opt/homebrew/bin/brew shellenv' "$PROFILE"; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$PROFILE"
      fi
      if ! grep -Fq 'sdkman-cli)/libexec' "$PROFILE"; then
        cat >> "$PROFILE" <<'PROFILE_BLOCK'
export SDKMAN_DIR="$(/opt/homebrew/bin/brew --prefix sdkman-cli)/libexec"
[[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR}/bin/sdkman-init.sh"
PROFILE_BLOCK
      fi
      if ! grep -Fq 'NVM_DIR="$HOME/.nvm"' "$PROFILE"; then
        cat >> "$PROFILE" <<'PROFILE_BLOCK'
export NVM_DIR="$HOME/.nvm"
export NVM_ONLY=alpha,lts,non-lts,iojs
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && source "/opt/homebrew/opt/nvm/nvm.sh"
nvm use --silent default >/dev/null 2>&1
export PATH="$NVM_DIR/versions/node/$(nvm version default)/bin:$PATH"
PROFILE_BLOCK
      fi
      if ! grep -Fq 'export NVM_ONLY=alpha,lts,non-lts,iojs' "$PROFILE"; then
        PROFILE_TMP=$(mktemp)
        awk '{ print; if (index($0, "export NVM_DIR=") == 1) print "export NVM_ONLY=alpha,lts,non-lts,iojs" }' "$PROFILE" > "$PROFILE_TMP"
        cat "$PROFILE_TMP" > "$PROFILE"
        rm -f "$PROFILE_TMP"
      fi
      if ! grep -Fq 'nvm use --silent default' "$PROFILE"; then
        echo 'nvm use --silent default >/dev/null 2>&1' >> "$PROFILE"
      fi
      if ! grep -Fq 'nvm version default)/bin:$PATH' "$PROFILE"; then
        echo 'export PATH="$NVM_DIR/versions/node/$(nvm version default)/bin:$PATH"' >> "$PROFILE"
      fi
    done

    BASH_PROFILE="$HOME/.bash_profile"
    if ! grep -Fq '# d2-macos shell settings' "$BASH_PROFILE"; then
      cat >> "$BASH_PROFILE" <<'BASH_PROFILE_BLOCK'
# d2-macos shell settings
if [ -f /etc/bashrc_Apple_Terminal ]; then
  source /etc/bashrc_Apple_Terminal
fi
export EDITOR=vim
eval "$(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)"
export PAGER=less
export TERM=xterm-256color
bind 'set enable-bracketed-paste off'
BASH_PROFILE_BLOCK
    fi

    INPUTRC="$HOME/.inputrc"
    touch "$INPUTRC"
    if ! grep -Fq 'set enable-bracketed-paste off' "$INPUTRC"; then
      echo 'set enable-bracketed-paste off' >> "$INPUTRC"
    fi

    echo "=== Provisioning Complete! ==="
BASH
  SHELL
end
