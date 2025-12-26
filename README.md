<h1 align="center">
  <img src="assets/pipex.png" alt="pipex" width="400">
</h1>

<p align="center">
  <b><i>Comprehensive testing framework for pipex 🔍</i></b><br>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Compatible-macOS%20%26%20Linux-lightblue?style=for-the-badge" alt="compatibility">
  <img src="https://img.shields.io/badge/Category-Unit%20Testing-pink?style=for-the-badge" alt="category">
</p>

<p align="center">
  <img src="https://img.shields.io/github/last-commit/Jarnomer/pipex-error-tester/main?style=for-the-badge&color=red" alt="GitHub last commit">
</p>

<div align="center">

## Table of Contents

[📝 Overview](#-overview)  
[🛠️ Installation](#️-installation)  
[⚡ Usage](#-usage)  
[🔍 Tests](#-tests)  
[📊 Results](#-results)

</div>

## 📝 Overview

A comprehensive testing framework designed to thoroughly validate your pipex implementation:

- **Error handling**: Validates responses to invalid inputs, permissions and command errors
- **Functionality**: Tests core pipeline and redirection capabilities
- **Memory management**: Checks for leaks and file descriptor management
- **Bonus features**: Tests heredoc support and multiple command pipelines
- **Special cases**: Verifies handling of empty commands, special characters, and more

The tester systematically compares your pipex output with the expected `bash` behavior.

## 🛠️ Installation

GNU `bash` is required to use the tester. `Valgrind` support is detected. Also some tests need `gcc`.

Clone the repository into your pipex directory:

```bash
git clone https://github.com/Jarnomer/pipex-error-tester.git
```

## ⚡ Usage

Run the tester with shell or optionally give execution permissions:

```bash
bash pipex-error-tester/tester.sh [OPTIONS]
```

```bash
chmod +x pipex-error-tester/tester.sh
```

```bash
pipex-error-tester/tester.sh [OPTIONS]
```

The tester provides several options to target specific test categories:

```
  -t, --test ID    Run specific error test by ID
  -v, --valid      Run tests with valid commands
  -e, --extra      Run extra checks and logical tests
  -b, --bonus      Run heredoc and multi pipeline tests
  -s, --special    Run tests with special characters
  -a, --all        Run all tests except special tests
  -l, --list       List all available tests
  -h, --help       Show this help message
```

### Examples

Run default error handling tests:

```bash
./tester.sh
```

Run all tests, excluding quotes and backslahes:

```bash
./tester.sh -a
```

Run a specific error test:

```bash
./tester.sh -t 5
```

Run bonus tests:

```bash
./tester.sh -b
```

⚠️ You can also add/replace test commands at `utils.sh`. ⚠️

## 🔍 Tests

### 1. Error Tests 🚨

Tests proper error handling for:

- Non-existent input files
- Permission issues (read/write/execute)
- Invalid commands (with and without path)
- Unsupported command arguments
- Directory as command or output file
- Path environment issues
- Null and empty commands

### 2. Valid Tests ✅

Tests operation with valid commands:

- Basic pipelines (`ls | wc`)
- Text processing (`grep`, `sort`)
- Standard utilities (`cut -d: -f1`)

### 3. Extra Tests 🔰

Advanced checks for:

- Norminette, Makefile and forbidden functions
- Parallel execution of commands
- Signal handling (interrupt, segfault)
- Execution logic with various inputs
- Output message consistency
- Zombie processes
- File descriptor management (bonus)

### 4. Bonus Tests 🍪

Tests for bonus features:

- Multiple pipes (`cmd1 | cmd2 | cmd3 | ...`)
- Heredoc functionality (`<<`)
- Proper appending with heredoc (`>>`)
- Proper truncation with regular input (`>`)

### 5. Special Tests 🎯

Complex tests with meta characters and advanced commands:

- Quote handling (`cut -d' '`)
- Special characters (`sed -E 's/\t/ /g'`)
- Advanced text processing (`awk '/^#/ {next} {print}'`)

## 📊 Results

Test results are displayed in a clean, color-coded format:

- 🟢 **Green [OK]**: Test passed
- 🔴 **Red [KO]**: Test failed  
- 🟡 **Yellow**: Test skipped or warning

For failed tests, detailed error information is saved to `pipex_error.log` including:

- Exit codes comparison
- Output differences
- Valgrind memory leak reports

⚠️ Extra tests do not create log entries ⚠️

## 4️⃣2️⃣ Footer

For my other 42 projects and general information, please refer to the [Hive42](https://github.com/Jarnomer/Hive42) page.

I have also created error handling [unit testers](https://github.com/Jarnomer/42Testers) for other projects like `so_long` and `cub3D`.

### Cheers and good luck with your testing! 🚀
