<h1 align="center">
  <img src="assets/pipex-tester.png" alt="pipex-tester" width="400">
</h1>

<p align="center">
  <b><i>Comprehensive testing framework for pipex 🔍</i></b><br>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Tests-60%2B-lightgreen?style=for-the-badge" alt="tests">
  <img src="https://img.shields.io/badge/Compatible-macOS%20%26%20Linux-lightblue?style=for-the-badge" alt="compatibility">
  <img src="https://img.shields.io/badge/Category-Error%20Handling-pink?style=for-the-badge" alt="category">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Type-Unit%20Testing-violet?style=for-the-badge" alt="type">
  <img src="https://img.shields.io/github/last-commit/Jarnomer/pipex-error-tester/main?style=for-the-badge&color=red" alt="GitHub last commit">
</p>

<div align="center">

## Table of Contents

[📝 Overview](#-overview)  
[🛠️ Installation](#️-installation)  
[⚡ Usage](#-usage)  
[🔍 Test Categories](#-test-categories)  
[📊 Test Results](#-test-results)  
[🚀 Advanced Features](#-advanced-features)  
[📋 Requirements](#-requirements)  
[🌟 Contributing](#-contributing)

</div>

## 📝 Overview

The pipex tester is a comprehensive testing framework designed to thoroughly validate your pipex implementation. It focuses on error handling:

- **Error handling**: Validates proper responses to invalid inputs, file permissions, and command errors
- **Functionality**: Tests the core pipeline and redirection capabilities
- **Edge cases**: Verifies handling of empty commands, quotes, special characters, and more
- **Memory management**: Checks for leaks and file descriptor management (with valgrind support)
- **Bonus features**: Tests heredoc support and multiple command pipelines

This tester systematically compares your pipex output with the expected bash behavior to ensure complete compatibility.

## 🛠️ Installation

Clone the repository into your pipex directory or adjacent to it:

```bash
git clone https://github.com/Jarnomer/pipex-error-tester.git
cd pipex-error-tester
```

Ensure that the tester scripts have execution permissions:

```bash
chmod +x tester.sh
```

## ⚡ Usage

The tester provides several options to target specific test categories:

```bash
./tester.sh [OPTIONS]
```

Available options:

```
  -t, --test ID    Run specific error test by ID
  -v, --valid      Run tests with valid commands
  -e, --extra      Run extra checks and logical tests
  -b, --bonus      Run heredoc and multi pipeline tests
  -s, --special    Run tests with meta characters
  -a, --all        Run all tests except special tests
  -l, --list       List all available tests
  -h, --help       Show this help message
```

### Examples

Run all tests:

```bash
./tester.sh -a
```

Run only error handling tests:

```bash
./tester.sh
```

Run a specific test (e.g., test #5):

```bash
./tester.sh -t 5
```

Run bonus tests (heredoc and multiple pipelines):

```bash
./tester.sh -b
```

## 🔍 Test Categories

### 1. Error Tests

Tests proper error handling for:

- Non-existent input files
- Permission issues (read/write/execute)
- Invalid commands
- Directory as command
- Path environment issues
- Empty/null commands

### 2. Valid Tests

Tests correct operation with valid commands, including:

- Basic pipelines (`ls | wc`)
- Text processing (`grep`, `sort`, `head`, `tail`)
- Complex commands with arguments
- Standard utilities

### 3. Extra Tests

Advanced checks for:

- Parallel execution of commands
- Signal handling (interrupt, segfault)
- Memory leaks (using valgrind)
- File descriptor management
- Zombie processes

### 4. Bonus Tests

Tests for bonus features:

- Multiple pipes (`cmd1 | cmd2 | cmd3 | ...`)
- Heredoc functionality (`<<`)
- Proper appending with heredoc
- Proper truncation with regular input

### 5. Special Tests

Complex tests with meta characters and advanced shell features:

- Quote handling
- Special characters
- Complex pipelines
- Advanced text processing commands

## 📊 Test Results

Test results are displayed in a clean, color-coded format:

- **Green (OK)**: Test passed
- **Red (KO)**: Test failed
- **Yellow**: Test skipped or warning

For failed tests, detailed error information is saved to `pipex_error.log` including:

- Exit codes comparison
- Output differences
- Valgrind memory leak reports

## 🚀 Advanced Features

### Memory Leak Detection

If valgrind is installed, the tester automatically checks for memory leaks:

```bash
# Install valgrind if needed
sudo apt-get install valgrind   # Debian/Ubuntu
brew install valgrind           # macOS with Homebrew
```

### Command Timeout

Tests automatically timeout after 2 seconds to prevent hanging on infinite loops.

### Norminette Integration

If norminette is available, the tester will check code style compliance.

## 📋 Requirements

- Bash shell environment
- gcc compiler for some test components
- Optional: valgrind for memory leak detection
- Optional: norminette for code style checking

## 🌟 Contributing

Contributions are welcome! If you find any issues or have improvements to suggest:

1. Fork the repository
2. Create a new branch
3. Submit a pull request

### Reporting Issues

If you encounter a problem with the tester, please file an issue with:

- Test command that failed
- Expected vs. actual behavior
- Your system information

## 4️⃣2️⃣ Footer

For my other 42 projects and general information, please refer to the [Hive42](https://github.com/Jarnomer/Hive42) page.

I have also created error handling [unit testers](https://github.com/Jarnomer/42Testers) for other projects like `so_long` and `cub3D`.

### Cheers and good luck with your testing! 🚀
