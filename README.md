# AndrusOne-Config

## Environment Bootstrap for Engineers Who Ship

This repository contains cross-platform configuration scripts for Python, PowerShell, Bash, and SQL developers. It’s designed to help new engineers set up a reliable, clean environment—without wrestling with dotfile magic, cryptic tools, or wasted time.

Built for people who want to **start quickly**, **work cleanly**, and **ship with confidence**.

---

## Why This Repo Exists

Modern engineers touch many systems—Windows, Linux, cloud shells, containers. But your tooling shouldn’t fight you. This repo gives you a transparent, testable setup for:

- Terminal styling with readable prompts
- Pre-commit Git hooks and SSH signing
- Python linting, formatting, and dependency setup
- Shell plugins, fonts, and aliases that make sense
- AWS CLI integration with profile switching
- VS Code settings for syntax-aware editing

Everything here is modular. You run what you need. You read what you run.

---

## What This Configures

- PowerShell with Oh My Posh and AWS context
- Bash or Zsh with custom themes and aliases
- Git SSH key generation and signing
- Python environment setup with Poetry, Black, Ruff
- SQL dialect-aware linters and directory structure
- VS Code settings (optional but recommended)
- JetBrains Mono Nerd Font + terminal styling guide
- AWS CLI and SSO profile automation

---

## Quick Start

1. Clone this repository:

   ```bash
   git clone https://github.com/andrusone/andrusone-config.git
   cd andrusone-config
   ```

2. Choose the setup script for your system:

   - On Linux/macOS:
     ```bash
     ./setup.sh
     ```
   - On Windows (Run from PowerShell as Administrator):
     ```powershell
     .\setup.ps1
     ```

3. Follow the prompts and optional steps:

   - Install fonts
   - Apply terminal theme
   - Configure Git and AWS profiles

4. Restart your terminal and confirm everything works.

---

## Repository Structure

```
andrusone-config/
├── powershell/        # Windows environment setup (PowerShell 7+)
├── shell/             # Linux/macOS setup (Bash, Zsh)
├── fonts/             # Font install instructions (JetBrains Mono Nerd Font)
├── vscode/            # Recommended VS Code extensions and settings
├── aws/               # AWS CLI, SSO, and prompt setup
├── LICENSE
├── README.md
└── bootstrap.log      # Generated during setup to track what ran
```

---

## Configuration Philosophy

**Clarity over cleverness.**
Every command is visible, readable, and logged.

**Simplicity scales.**
The goal is repeatable setups with no hidden state.

**Testability over trust.**
Scripts run cleanly and verify their impact.

**Empathy over ego.**
This is for real engineers, not config wizards.

---

## Contribution Guidelines

Contributions are welcome if they follow the philosophy:

- Fork the repo
- Create a feature branch
- Submit a pull request with a clear rationale

Please keep changes minimal, tested, and clearly documented.

---

## AndrusOne Engineering Values

This repository embodies these core principles:

1. Clarity over Cleverness — If it's hard to read, it's hard to trust
2. Reliability over Performance — Unreliable code scales mistakes
3. Testability over Trust — Testing removes doubt
4. Observability over Assumptions — Instrument everything
5. Simplicity over Complexity — Simplicity scales, complexity fails
6. Ownership over Blame — Accountability creates progress
7. Empathy over Ego — Code is read more than written. Be human

---

## About

Created and maintained by Dave Andrus as part of the AndrusOne open tools initiative.
For updates and related projects, visit [andrusone.dev](https://andrusone.dev)

---
