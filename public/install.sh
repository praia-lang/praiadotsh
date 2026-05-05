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
        *) echo "Error: unsupported OS: $OS" >&2; exit 1 ;;
    esac

    # Detect architecture
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64)  ARCH="x86_64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) echo "Error: unsupported architecture: $ARCH" >&2; exit 1 ;;
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

    # Skip if we're already on this version. `praia -v` prints "Praia Version 0.5.1".
    if [ -x "${INSTALL_DIR}/bin/praia" ]; then
        CURRENT="$("${INSTALL_DIR}/bin/praia" -v 2>/dev/null | awk '{print $NF}')"
        if [ "$CURRENT" = "$VERSION" ]; then
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
    # Anything outside lib/praia/{grains,sand,dylibs,lib,include} is left alone.
    $SUDO rm -rf "${INSTALL_DIR}/lib/praia/grains" \
                 "${INSTALL_DIR}/lib/praia/sand" \
                 "${INSTALL_DIR}/lib/praia/dylibs" \
                 "${INSTALL_DIR}/lib/praia/lib" \
                 "${INSTALL_DIR}/lib/praia/include"

    $SUDO cp "${TMPDIR}/praia" "${INSTALL_DIR}/bin/praia"
    $SUDO chmod +x "${INSTALL_DIR}/bin/praia"
    $SUDO cp -R "${TMPDIR}/lib/praia/grains" "${INSTALL_DIR}/lib/praia/"
    $SUDO cp -R "${TMPDIR}/lib/praia/sand" "${INSTALL_DIR}/lib/praia/"
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

    # Create the sand wrapper
    SAND_WRAPPER="${INSTALL_DIR}/bin/sand"
    SAND_TMP="${TMPDIR}/sand"
    cat > "$SAND_TMP" <<EOF
#!/bin/sh
exec "${INSTALL_DIR}/bin/praia" "${INSTALL_DIR}/lib/praia/sand/main.praia" "\$@"
EOF
    $SUDO mv "$SAND_TMP" "$SAND_WRAPPER"
    $SUDO chmod 755 "$SAND_WRAPPER"

    # Verify
    if command -v praia >/dev/null 2>&1; then
        echo ""
        echo "Praia ${VERSION} installed successfully!"
        echo ""
        praia -v
        echo ""
        echo "Run 'praia' to start the REPL, or 'praia file.praia' to run a script."
    else
        echo ""
        echo "Praia ${VERSION} installed to ${INSTALL_DIR}/bin/praia"
        echo ""
        echo "Make sure ${INSTALL_DIR}/bin is in your PATH:"
        echo "  export PATH=\"${INSTALL_DIR}/bin:\$PATH\""
    fi
}

main
