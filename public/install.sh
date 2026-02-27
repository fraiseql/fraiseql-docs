#!/usr/bin/env sh
# FraiseQL installer
# Usage: curl -fsSL https://fraiseql.dev/install.sh | sh
#
# Environment variables (all optional):
#   FRAISEQL_VERSION   — install a specific version tag, e.g. "v2.0.0-alpha"
#                        defaults to the latest GitHub release
#   FRAISEQL_INSTALL_DIR — directory to install the binary into
#                          defaults to /usr/local/bin (falls back to ~/.local/bin)
#   FRAISEQL_NO_MODIFY_PATH — set to any value to skip the PATH hint

set -eu

REPO="fraiseql/fraiseql"
BINARY="fraiseql"
RELEASES_URL="https://github.com/${REPO}/releases"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

# ── Colours (disabled when not a tty) ─────────────────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

info()    { printf "${GREEN}info${RESET}  %s\n" "$*"; }
warn()    { printf "${YELLOW}warn${RESET}  %s\n" "$*"; }
error()   { printf "${RED}error${RESET} %s\n" "$*" >&2; }
bold()    { printf "${BOLD}%s${RESET}\n" "$*"; }

die() {
  error "$*"
  exit 1
}

# ── Dependency checks ──────────────────────────────────────────────────────────
need() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

need curl
need tar
need uname

# ── Platform detection ─────────────────────────────────────────────────────────
detect_target() {
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux)
      case "$arch" in
        x86_64)  echo "x86_64-unknown-linux-gnu" ;;
        aarch64) echo "aarch64-unknown-linux-gnu" ;;
        arm64)   echo "aarch64-unknown-linux-gnu" ;;
        *)       die "unsupported Linux architecture: $arch" ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        x86_64)  echo "x86_64-apple-darwin" ;;
        arm64)   echo "aarch64-apple-darwin" ;;
        *)       die "unsupported macOS architecture: $arch" ;;
      esac
      ;;
    MINGW*|MSYS*|CYGWIN*)
      die "Windows is not supported by this script. Download the .zip from: ${RELEASES_URL}"
      ;;
    *)
      die "unsupported operating system: $os"
      ;;
  esac
}

# ── Version resolution ─────────────────────────────────────────────────────────
resolve_version() {
  if [ -n "${FRAISEQL_VERSION:-}" ]; then
    # Strip leading 'v' if provided, then re-add it for consistency
    version="${FRAISEQL_VERSION#v}"
    echo "v${version}"
    return
  fi

  # Fetch latest release tag from GitHub API
  response="$(curl -fsSL "$API_URL" 2>/dev/null)" || \
    die "failed to fetch latest release info from GitHub. Check your internet connection or set FRAISEQL_VERSION manually."

  tag="$(printf '%s' "$response" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"

  [ -n "$tag" ] || die "could not parse latest release tag from GitHub API response"
  echo "$tag"
}

# ── Install directory ──────────────────────────────────────────────────────────
resolve_install_dir() {
  if [ -n "${FRAISEQL_INSTALL_DIR:-}" ]; then
    echo "$FRAISEQL_INSTALL_DIR"
    return
  fi

  # Prefer /usr/local/bin if writable, fall back to ~/.local/bin
  if [ -w "/usr/local/bin" ]; then
    echo "/usr/local/bin"
  elif mkdir -p "$HOME/.local/bin" 2>/dev/null; then
    echo "$HOME/.local/bin"
  else
    die "cannot find a writable install directory. Set FRAISEQL_INSTALL_DIR to override."
  fi
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  bold "FraiseQL Installer"
  printf "\n"

  target="$(detect_target)"
  info "detected platform: $target"

  version="$(resolve_version)"
  info "installing version: $version"

  install_dir="$(resolve_install_dir)"
  info "install directory: $install_dir"

  printf "\n"

  archive="fraiseql-${target}.tar.gz"
  download_url="${RELEASES_URL}/download/${version}/${archive}"

  # ── Download ─────────────────────────────────────────────────────────────────
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  info "downloading $archive ..."
  if ! curl -fL --progress-bar "$download_url" -o "${tmp_dir}/${archive}"; then
    error "download failed: $download_url"
    die "check that version ${version} exists at: ${RELEASES_URL}"
  fi

  # ── Extract ───────────────────────────────────────────────────────────────────
  info "extracting ..."
  tar -xzf "${tmp_dir}/${archive}" -C "$tmp_dir"

  binary_path="${tmp_dir}/${BINARY}"
  [ -f "$binary_path" ] || die "archive did not contain expected binary '${BINARY}'"
  chmod +x "$binary_path"

  # ── Install ───────────────────────────────────────────────────────────────────
  dest="${install_dir}/${BINARY}"

  if [ -f "$dest" ] && ! [ -w "$dest" ]; then
    info "existing binary at $dest is not writable, trying with sudo ..."
    sudo mv "$binary_path" "$dest"
  else
    mv "$binary_path" "$dest"
  fi

  # ── Verify ────────────────────────────────────────────────────────────────────
  if command -v "$BINARY" >/dev/null 2>&1; then
    installed_version="$("$BINARY" --version 2>/dev/null || echo "unknown")"
    printf "\n"
    info "${GREEN}installed:${RESET} $installed_version"
  else
    printf "\n"
    warn "binary installed to $dest but '${BINARY}' is not in PATH"
  fi

  # ── PATH hint ─────────────────────────────────────────────────────────────────
  if [ -z "${FRAISEQL_NO_MODIFY_PATH:-}" ] && ! command -v "$BINARY" >/dev/null 2>&1; then
    printf "\n"
    warn "add the install directory to your PATH:"
    printf "  ${BOLD}export PATH=\"%s:\$PATH\"${RESET}\n" "$install_dir"
    printf "\n"
    warn "to make it permanent, add the above line to ~/.bashrc, ~/.zshrc, or equivalent."
  fi

  printf "\n"
  bold "done. run 'fraiseql --version' to verify."
  printf "\n"
  info "docs:      https://fraiseql.dev/getting-started/quickstart"
  info "changelog: https://fraiseql.dev/changelog"
  info "releases:  ${RELEASES_URL}"
}

main "$@"
