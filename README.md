# ZIGMAN — Zig Version Manager

ZIGMAN is a lightweight, high-performance Zig version manager written entirely in Zig. It allows you to seamlessly switch between different compiler versions, ensuring your projects always build with the correct toolchain.
## 🚀 Features

    Version Switching: Quickly toggle between stable and nightly Zig releases.

    Zero Dependencies: Built using only the Zig Standard Library.

    Lightweight: Minimal overhead and lightning-fast command execution.

## 🛠 Installation
### Prerequisites

    Zig Compiler (to build from source)

### Building from Source

    Clone the repository:
    Bash

    git clone https://github.com/mohalem/zigman.git
    cd zigman

    Build the project:
    Bash

    zig build-exe main.zig -O ReleaseSafe --name zigman

    Move the binary to your PATH (optional):
    Bash

    mv ./zigman /usr/local/bin/

## 📖 Usage

The basic syntax for ZIGMAN is:
Bash

zigman [command] [arguments]

Available Commands
Command	Description	Example
install	Download and install a specific version	zigman install 0.11.0
uninstall	Remove a previously installed version	zigman uninstall 0.10.1
use	Switch the active Zig version	zigman use 0.11.0
list	Show all installed versions	zigman list
fetch	See what versions are available online	zigman fetch
help	Display usage information	zigman help
version	Display the current ZIGMAN version	zigman version

##🏗 Project Architecture

ZIGMAN is designed with simplicity in mind. The current implementation handles CLI routing via a tagged union (Enum) and the Zig std.meta library.
Code Structure

    main.zig: The entry point. Handles memory allocation (GPA), argument parsing, and command dispatching.

    Command Enum: Defines the internal API for supported actions.

## 🤝 Contributing

Contributions are welcome! If you'd like to help implement the file system logic for version switching or the HTTP fetching for fetch, feel free to fork the repo and submit a PR.

    Fork the Project

    Create your Feature Branch (git checkout -b feature/AmazingFeature)

    Commit your Changes (git commit -m 'Add some AmazingFeature')

    Push to the Branch (git push origin feature/AmazingFeature)

    Open a Pull Request

## 👤 Author

Mohammad Alamsyah (mohalem)

    Email: mohalem.public@gmail.com
