# Contributing to TinySnapper

Thank you for your interest in contributing to TinySnapper! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Bugs

Before creating a bug report, please:

1. Check if the issue already exists in the [issue tracker](https://github.com/andrehfp/tinysnapper/issues)
2. Use the latest version of TinySnapper to verify the bug still exists

When submitting a bug report, please include:

- **macOS version** (e.g., macOS 14.2)
- **TinySnapper version**
- **Steps to reproduce** the issue
- **Expected behavior** vs **actual behavior**
- **Screenshots** if applicable
- Any **error messages** or crash logs

### Suggesting Features

Feature requests are welcome! Please:

1. Check if the feature has already been suggested
2. Provide a clear description of the feature and its use case
3. Explain why this feature would be useful to TinySnapper users

### Pull Requests

1. **Fork** the repository and create your branch from `main`
2. **Build and test** your changes locally:
   ```sh
   ./scripts/build-app.sh
   ./scripts/install-app.sh
   ```
3. Ensure your code follows the existing **style and conventions**
4. Update the **README.md** if your changes affect usage or installation
5. Add entries to **CHANGELOG.md** under the "Unreleased" section
6. Submit the pull request with a clear description of changes

## Development Setup

```sh
# Clone your fork
git clone https://github.com/your-username/tinysnapper.git
cd tinysnapper

# Build the app
./scripts/build-app.sh

# Install locally for testing
./scripts/install-app.sh
```

## Code Style

- Follow **Swift style guidelines** consistent with existing code
- Use **meaningful variable names**
- Add **comments** for complex logic
- Keep functions **focused and small**

## Commit Messages

Use clear, descriptive commit messages:

- `feat: add new capture shortcut`
- `fix: resolve clipboard paste issue`
- `docs: update installation instructions`
- `refactor: simplify capture service`

## Questions?

Feel free to open an issue for questions or join discussions in existing issues.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
