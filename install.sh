#!/bin/bash
set -e

# ==========================================
# CONFIGURATION
# Update this to match your actual GitHub username and repository!
# ==========================================
GITHUB_REPO="mohalem/zigman"

echo "🚀 Setting up Zigman..."

# ==========================================
# STEP 1: Detect OS and Architecture
# ==========================================
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Normalize architecture names
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH="aarch64"
elif [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    ARCH="x86_64"
else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi

# Normalize OS names
if [ "$OS" = "darwin" ]; then
    OS="macos"
elif [ "$OS" = "linux" ]; then
    OS="linux"
else
    echo "❌ Unsupported operating system: $OS"
    exit 1
fi

echo "🔍 Detected System: $OS ($ARCH)"

# ==========================================
# STEP 2: Create directories
# ==========================================
ZIGMAN_DIR="$HOME/.zigman"
ZIGMAN_APP_DIR="$ZIGMAN_DIR/app"
ZIGMAN_BIN_DIR="$ZIGMAN_DIR/bin"

echo "📂 Creating directories at $ZIGMAN_DIR..."
mkdir -p "$ZIGMAN_APP_DIR"
mkdir -p "$ZIGMAN_BIN_DIR"

# ==========================================
# STEP 3: Fetch latest release version
# ==========================================
echo "🌐 Fetching latest release info from GitHub..."
# Queries the GitHub API and extracts the "tag_name" (e.g., "v0.1.0")
LATEST_VERSION=$(curl -sL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo "❌ Failed to fetch latest version. Check your repository name or internet connection."
    exit 1
fi

echo "✨ Found latest version: $LATEST_VERSION"

# ==========================================
# STEP 4: Download the binary
# ==========================================
# This assumes your uploaded assets are named like: zigman-linux-x86_64
ASSET_NAME="zigman-${OS}-${ARCH}"
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/${LATEST_VERSION}/${ASSET_NAME}"
DEST_BINARY="$ZIGMAN_APP_DIR/zigman"

echo "⬇️  Downloading $ASSET_NAME..."
# curl -f fails silently on HTTP errors (like 404), -L follows redirects, -o outputs to file
if curl -fL -o "$DEST_BINARY" "$DOWNLOAD_URL"; then
    chmod +x "$DEST_BINARY"
    echo "✅ Download complete and made executable."
else
    echo "❌ Download failed."
    echo "   Ensure the release asset exists at: $DOWNLOAD_URL"
    exit 1
fi

# ==========================================
# STEP 5: Create config.json
# ==========================================
echo "📝 Writing default config.json..."
cat << 'EOF' > "$ZIGMAN_DIR/config.json"
{
    "mirrorListUrl": "https://ziglang.org/download/community-mirrors.txt",
    "minisignPubKey": "RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U",
    "versionMapUrl": "https://ziglang.org/download/index.json",
    "zlsVersionMapUrl": "https://releases.zigtools.org/",
    "useColor": true,
    "alwaysForceInstall": false
}
EOF

# ==========================================
# STEP 6: Append to shell profile
# ==========================================
echo "🔗 Configuring PATH..."
PATH_EXPORT='export PATH="$HOME/.zigman/app:$HOME/.zigman/bin:$PATH"'

append_path() {
    local rc_file="$HOME/$1"
    if [ -f "$rc_file" ]; then
        if grep -q "$HOME/.zigman/app" "$rc_file"; then
            echo "   -> PATH already configured in ~/$1"
        else
            echo "" >> "$rc_file"
            echo "# Zigman binary paths" >> "$rc_file"
            echo "$PATH_EXPORT" >> "$rc_file"
            echo "   -> Added PATH to ~/$1"
        fi
    }
}

append_path ".bashrc"
append_path ".zshrc"
append_path ".bash_profile"

echo ""
echo "🎉 Setup complete! Zigman is installed."
echo "👉 Run 'source ~/.bashrc' (or ~/.zshrc) to reload your terminal, then type 'zigman help'."
