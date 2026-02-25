# ZIGMAN — Zig Version Manager

ZIGMAN is a lightweight, high-performance Zig version manager written entirely in Zig. It allows you to seamlessly switch between different compiler versions, ensuring your projects always build with the correct toolchain.
## 🚀 Features

    **Version Switching:** Quickly toggle between stable and nightly Zig releases using symlinks.

    **Zero Dependencies:** Built using only the Zig Standard Library. No system tar, curl, or unzip required.

    **Native Extraction:** Downloads and decompresses .tar.xz archives natively in memory.

    **Custom Mirrors:** Configurable via ~/.zigman/config.json to support community mirrors and alternative download sources.

    **Smart Uninstalls:** Easily remove old versions using a dynamically numbered list.

## ☕ Donate

If you find this tool helpful, consider buying me a coffee!
[PayPal](paypal.me/MohammadAlamsyah)

## 🛠 Installation

### Option 1: Quick Install (Recommended)

You can install Zigman and automatically configure your PATH by running our setup script:
Bash

`curl -sL https://raw.githubusercontent.com/mohalem/zigman/main/install.sh | bash`

### Option 2: Building from Source

If you already have Zig installed and want to compile ZIGMAN yourself:

    Clone the repository:
    Bash

    git clone https://github.com/mohalem/zigman.git
    cd zigman

    Build the optimized binary:
    Bash

    zig build -Doptimize=ReleaseFast

    Run the manual setup:
    Copy the resulting binary from ./zig-out/bin/zigman to a directory in your PATH (e.g., ~/.local/bin/ or /usr/local/bin/).

## 📖 Usage

The basic syntax for ZIGMAN is:
Bash

zigman [command] [arguments]

### Available Commands
| Command | Description | Example |
| :------ | :------ | :------ |
|install|Download and install a specific version. Use -f to force reinstall.	|zigman install 0.14.0|
|uninstall|	Remove a version by name or by its list index number.	|zigman uninstall 1 OR zigman uninstall 0.14.0|
|use	|Switch the active globally linked Zig version.	|zigman use 0.14.0|
|list	|Show all installed versions locally.	|zigman list|
|fetch	|See what versions are available online.	|zigman fetch|
|help	|Display usage information.	|zigman help|
|version	|Display the current ZIGMAN version.	|zigman version|


## 🏗 Project Architecture

ZIGMAN is designed with modularity and simplicity in mind, taking full advantage of Zig 0.15's robust standard library.

    src/main.zig: The entry point. Handles CLI routing and argument parsing.

    src/commands/: Individual modules for each CLI action (install.zig, use.zig, etc.).

    src/core/: Shared logic, including the HTTP downloader and the native .tar.xz extractor.

    ~/.zigman/: The local environment where configurations (config.json), downloaded versions, and the active bin/zig symlink are managed.

## 🤝 Contributing

Contributions are welcome! Whether it is adding Windows .zip support, optimizing the extraction process, or fixing bugs, feel free to fork the repo and submit a PR.

    Fork the Project

    Create your Feature Branch (git checkout -b feature/AmazingFeature)

    Commit your Changes (git commit -m 'Add some AmazingFeature')

    Push to the Branch (git push origin feature/AmazingFeature)

    Open a Pull Request

## 📄 License

Distributed under the MIT License. See LICENSE for more information.
👤 Author

Mohammad Alamsyah (moohalem)

    Email: mohalem.public@gmail.com

    GitHub: @mohalem
