#!/bin/sh
set -eu

usage() {
  cat <<'HELP'
Usage: d2 macos.setup [--help]

Prepare the VM SSH key, trust the Cirrus Labs tap, patch its Homebrew formula
dependencies, install Tart and its provider, and pull the macOS image.

Options:
  -h, --help  Show this help
HELP
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "macos.setup: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  echo "macos.setup only runs on macOS." >&2
  exit 1
fi

ssh_dir="$HOME/.ssh"
private_key="$ssh_dir/d2macOs"
public_key="$private_key.pub"
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"

if [ -f "$private_key" ] && [ -f "$public_key" ]; then
  echo "Using existing SSH key pair at $private_key."
elif [ -e "$private_key" ] || [ -e "$public_key" ]; then
  echo "macos.setup: only part of the SSH key pair exists at $private_key." >&2
  echo "Restore both files or remove the incomplete pair, then run d2 macos.setup again." >&2
  exit 1
else
  ssh-keygen -q -t ed25519 -N "" -C "d2-macos-vm" -f "$private_key"
  chmod 600 "$private_key"
  chmod 644 "$public_key"
  echo "Created SSH key pair at $private_key."
fi

brew tap cirruslabs/cli
brew trust cirruslabs/cli

patch_formula() {
  formula_path="$1"
  temp_file="${formula_path}.d2tmp.$$"
  formula_mode=$(stat -f '%Lp' "$formula_path")

  awk '
    BEGIN {
      on_macos_indent = -1
    }
    function indentation(line) {
      match(line, /^[ \t]*/)
      return RLENGTH
    }
    function is_macos_dependency(line) {
      return line ~ /^[ \t]*depends_on[ \t]+(:macos|macos:)([ \t,]|$)/
    }
    /^[ \t]*on_macos[ \t]+do([ \t]*#.*)?$/ {
      on_macos_indent = indentation($0)
      print
      next
    }
    {
      if (is_macos_dependency($0)) {
        dependency_indent = indentation($0)
        if (on_macos_indent >= 0 && dependency_indent > on_macos_indent) {
          print
        } else {
          indent = substr($0, 1, dependency_indent)
          dependency = substr($0, dependency_indent + 1)
          print indent "on_macos do"
          print indent "  " dependency
          print indent "end"
        }
        next
      }
      print
      if (on_macos_indent >= 0 && $0 ~ /^[ \t]*end[ \t]*$/ && indentation($0) == on_macos_indent) {
        on_macos_indent = -1
      }
    }
  ' "$formula_path" > "$temp_file"

  if cmp -s "$formula_path" "$temp_file"; then
    rm "$temp_file"
    echo "Homebrew dependency in $formula_path is already compatible."
  else
    chmod "$formula_mode" "$temp_file"
    mv "$temp_file" "$formula_path"
    echo "Patched Homebrew dependency in $formula_path."
  fi
}

brew_prefix=$(brew --prefix)
tap_repo=$(brew --repo cirruslabs/cli 2>/dev/null || true)
for formula_name in softnet.rb tart.rb; do
  formula_path=""
  for tap_root in \
    "$tap_repo" \
    "$brew_prefix/Library/Taps/cirruslabs/homebrew-cli" \
    "/opt/homebrew/Library/Taps/cirruslabs/homebrew-cli" \
    "$HOME/homebrew/Library/Taps/cirruslabs/homebrew-cli" \
    "$HOME/.homebrew/Library/Taps/cirruslabs/homebrew-cli"; do
    [ -d "$tap_root" ] || continue
    formula_path=$(find "$tap_root" -type f -name "$formula_name" -print -quit)
    [ -n "$formula_path" ] && break
  done

  if [ -z "$formula_path" ]; then
    echo "macos.setup: could not find $formula_name under the Homebrew tap. Tart was not installed because its formula could not be patched." >&2
    exit 1
  fi
  patch_formula "$formula_path"
done

brew install cirruslabs/cli/tart
vagrant plugin install vagrant-tart
tart pull ghcr.io/cirruslabs/macos-sequoia-base:latest
