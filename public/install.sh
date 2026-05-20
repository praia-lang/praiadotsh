#!/bin/sh
set -e

# Praia installer — https://praia.sh
# Usage: curl -fsSL https://praia.sh/install.sh | sh

REPO="praia-lang/praia"
INSTALL_DIR="/usr/local"

main() {
    # Detect OS
    OS="$(uname -s)"
    case "$OS" in
        Linux)  OS="linux" ;;
        Darwin) OS="macos" ;;
        *) echo "Error: unsupported OS: $OS\nPlease build from source: https://github.com/praia-lang/praia" >&2; exit 1 ;;
    esac

    # Detect architecture
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64)  ARCH="x86_64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) echo "Error: unsupported architecture: $ARCH\nPlease build from source: https://github.com/praia-lang/praia" >&2; exit 1 ;;
    esac

    PLATFORM="${OS}-${ARCH}"

    # Check for required tools
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        echo "Error: curl or wget is required" >&2
        exit 1
    fi

    # Fetch latest release tag
    echo "Fetching latest Praia release..."
    if command -v curl >/dev/null 2>&1; then
        TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')
    else
        TAG=$(wget -qO- "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')
    fi

    if [ -z "$TAG" ]; then
        echo "Error: could not determine latest release" >&2
        exit 1
    fi

    VERSION="${TAG#v}"
    FILENAME="praia-${PLATFORM}.tar.gz"
    URL="https://github.com/${REPO}/releases/download/${TAG}/${FILENAME}"

    if [ -x "${INSTALL_DIR}/bin/praia" ]; then
        CURRENT="$("${INSTALL_DIR}/bin/praia" -v 2>/dev/null | awk '{print $NF}')"
        if [ "$CURRENT" = "v$VERSION" ]; then
            echo "Praia ${VERSION} is already installed at ${INSTALL_DIR}/bin/praia."
            exit 0
        fi
        if [ -n "$CURRENT" ]; then
            echo "Upgrading Praia ${CURRENT} -> ${VERSION}..."
        else
            echo "Reinstalling Praia ${VERSION}..."
        fi
    else
        echo "Installing Praia ${VERSION} for ${PLATFORM}..."
    fi

    # Download to temp directory
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$URL" -o "${TMPDIR}/${FILENAME}"
    else
        wget -q "$URL" -O "${TMPDIR}/${FILENAME}"
    fi

    # Extract
    tar xzf "${TMPDIR}/${FILENAME}" -C "$TMPDIR"

    # Install — may need sudo
    if [ -w "${INSTALL_DIR}/bin" ] 2>/dev/null; then
        SUDO=""
    else
        echo "Installing to ${INSTALL_DIR} (requires sudo)..."
        SUDO="sudo"
    fi

    $SUDO mkdir -p "${INSTALL_DIR}/bin"
    $SUDO mkdir -p "${INSTALL_DIR}/lib/praia"

    # Remove the directories we manage so the install is a clean replacement
    # — files removed in the new version don't linger from the old install.
    # Anything outside lib/praia/{grains,ext_grains/sand,dylibs,lib,include}
    # is left alone (third-party grains in lib/praia/ext_grains/* survive).
    #
    # lib/praia/sand is the PRE-0.6 sand location; it lingers from older
    # installs but the binary no longer looks there. One-release migration.
    $SUDO rm -rf "${INSTALL_DIR}/lib/praia/grains" \
                 "${INSTALL_DIR}/lib/praia/sand" \
                 "${INSTALL_DIR}/lib/praia/ext_grains/sand" \
                 "${INSTALL_DIR}/lib/praia/dylibs" \
                 "${INSTALL_DIR}/lib/praia/lib" \
                 "${INSTALL_DIR}/lib/praia/include"

    $SUDO cp "${TMPDIR}/praia" "${INSTALL_DIR}/bin/praia"
    $SUDO chmod +x "${INSTALL_DIR}/bin/praia"
    $SUDO cp -R "${TMPDIR}/lib/praia/grains" "${INSTALL_DIR}/lib/praia/"
    # Sand is now a regular global grain under lib/praia/ext_grains/sand/
    # (so `sand install -g sand@<ver>` can self-update via the same code
    # path that installs any other grain). The release tarball stages it
    # at lib/praia/ext_grains/sand; we copy only that subdir to avoid
    # clobbering any third-party grains the user already installed.
    $SUDO mkdir -p "${INSTALL_DIR}/lib/praia/ext_grains"
    $SUDO cp -R "${TMPDIR}/lib/praia/ext_grains/sand" "${INSTALL_DIR}/lib/praia/ext_grains/"
    # Plugin headers — installed alongside the binary so users can build
    # native plugins (`praia --include-path` resolves here) without a Praia
    # source checkout.
    if [ -d "${TMPDIR}/lib/praia/include" ]; then
        $SUDO cp -R "${TMPDIR}/lib/praia/include" "${INSTALL_DIR}/lib/praia/"
    fi
    # Bundled runtime libraries (macOS dylibs / Linux .so files)
    if [ -d "${TMPDIR}/lib/praia/dylibs" ]; then
        $SUDO cp -R "${TMPDIR}/lib/praia/dylibs" "${INSTALL_DIR}/lib/praia/"
    fi
    if [ -d "${TMPDIR}/lib/praia/lib" ]; then
        $SUDO cp -R "${TMPDIR}/lib/praia/lib" "${INSTALL_DIR}/lib/praia/"
    fi

    # Create the sand wrapper. Byte format MUST match
    # sand/grains/bin.praia::wrapperContent (a Praia test enforces this)
    # so `sand install -g sand@<ver>` self-updates produce a wrapper
    # byte-identical to what install.sh / `make install` wrote.
    # Paths are POSIX single-quoted so a future bin: grain can't break
    # out of the exec line with shell metacharacters.
    # The sentinel comment on line 2 is what lets sand recognize this
    # wrapper as its own on later operations (overwrite vs refuse).
    SAND_WRAPPER="${INSTALL_DIR}/bin/sand"
    SAND_TMP="${TMPDIR}/sand-wrapper"
    cat > "$SAND_TMP" <<EOF
#!/bin/sh
# sand-managed wrapper for sand
exec '${INSTALL_DIR}/bin/praia' '${INSTALL_DIR}/lib/praia/ext_grains/sand/main.praia' "\$@"
EOF
    $SUDO mv "$SAND_TMP" "$SAND_WRAPPER"
    $SUDO chmod 755 "$SAND_WRAPPER"

    # Verify
    if command -v praia >/dev/null 2>&1; then
        echo ""
        echo "Praia ${VERSION} installed successfully!"
        echo ""
        echo "Run 'praia' to start the REPL, or 'praia file.praia' to run a script."
    else
        echo ""
        echo "Praia ${VERSION} installed to ${INSTALL_DIR}/bin/praia"
        echo ""
        echo "Make sure ${INSTALL_DIR}/bin is in your PATH:"
        echo "  export PATH=\"${INSTALL_DIR}/bin:\$PATH\""
    fi

    # Heads-up for sand's user-scope global installs. Non-root
    # `sand install -g <grain>` writes grain CLIs to ~/.praia/bin/,
    # which isn't on PATH on most setups. Print a one-liner here so
    # users know to add it ahead of their first `sand install -g`
    # rather than discovering the missing wrapper at run time.
    case ":$PATH:" in
        *":$HOME/.praia/bin:"*) ;;
        *)
            echo ""
            echo "Note: 'sand install -g <grain>' as a non-root user writes CLIs"
            echo "to ~/.praia/bin/. Add it to your PATH if you plan to use them:"
            echo "  export PATH=\"\$HOME/.praia/bin:\$PATH\""
            ;;
    esac
}

main
