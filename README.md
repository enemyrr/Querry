<div align="center">
  <img src="./assets/logo.png" alt="Pluk Logo" width="120" height="120">
  
  # Pluk
  
  **Native macOS database client for MongoDB, Postgres, MySQL, & SQLite**  
  *AI does the querying, you explore your data* ✨
  
  [![Website](https://img.shields.io/badge/Website-pluk.sh-blue)](https://www.pluk.sh/)
  [![Waitlist](https://img.shields.io/badge/Join-Waitlist-orange)](https://www.pluk.sh)
  [![Issues](https://img.shields.io/github/issues/pluk-inc/pluk)](https://github.com/pluk-inc/pluk/issues)
  
  <img src="./assets/hero-screenshot.png" alt="Pluk Hero Screenshot" width="800">
</div>

---

## 🚀 About Pluk

Pluk is a powerful, native macOS database client that revolutionizes how you interact with your databases. With AI-powered querying capabilities, Pluk makes database exploration intuitive and efficient for developers, data analysts, and database administrators.

Pluk is open source under the [GNU Affero General Public License v3.0](./LICENSE). The Pluk name, logo, icon, and visual identity remain covered by the separate [trademark policy](./TRADEMARKS.md).

### ✨ Key Features

- **🤖 AI-Powered Querying** - Natural language to SQL/NoSQL conversion
- **🔗 Multi-Database Support** - MongoDB, PostgreSQL, MySQL, SQLite
- **🎨 Native macOS Design** - Beautiful, responsive interface built for Mac
- **⚡ Lightning Fast** - Optimized performance for large datasets
- **🔒 Secure Connections** - SSL/TLS support with credential management
- **📊 Data Visualization** - Built-in charts and graphs *(coming soon)*
- **💾 Query History** - Save and organize your favorite queries *(coming soon)*
- **🔄 Real-time Updates** - Live data refresh capabilities *(coming soon)*
- **🔌 Cloud Integrations** - Supabase, Convex, Neon support *(coming soon)*

## 📸 Screenshots

<div align="center">
  <img src="./assets/connection-manager.png" alt="Connection Manager" width="100%">
  <br><br>

  <img src="./assets/query-interface.png" alt="Query Interface" width="100%">
  <br><br>
  
  <img src="./assets/ai-assistant.png" alt="AI Assistant" width="100%">
</div>

## 🔧 Supported Databases

| Database | Version | Features |
|----------|---------|----------|
| **MongoDB** | 3.6+ | Collections |
| **PostgreSQL** | 9.6+ | Full SQL, JSON |
| **MySQL** | 5.7+ | Full SQL |
| **SQLite** | 3.8+ | Local files |

## 🛠 Build from source

Requirements:

- macOS 15 or later
- Xcode 26 or later with Swift 6 support

Clone the repository, open `Pluk.xcodeproj`, select the shared `Collection` scheme, and run the app target. Xcode resolves the Swift package dependencies from the checked-in `Package.resolved` file.

Community builds work without Pluk's hosted service configuration. PostHog, Sentry, WorkOS sign-in, and funded Bedrock AI are disabled when their values are absent. Maintainers can copy `pluk/Secrets.xcconfig.example` to the ignored `pluk/Secrets.xcconfig` for official builds. Values placed there are embedded in the app binary and must not be treated as server-side secrets.

If code signing fails, choose your own development team in Xcode or build locally with code signing disabled. Do not commit personal signing configuration.

## 📋 Issue Tracking

This repository is dedicated to tracking bugs, feature requests, and feedback for Pluk. We welcome your contributions to make Pluk even better!

### 🐛 Reporting Bugs

Before submitting a bug report, please:

1. **Search existing issues** to avoid duplicates
<!-- 2. **Check our [FAQ](https://www.pluk.sh/faq)** for common solutions -->
2. **Provide detailed information** using our bug report template

[**🐛 Report a Bug**](https://github.com/pluk-inc/pluk/issues/new?template=bug_report.md)

### 💡 Feature Requests

Have an idea to improve Pluk? We'd love to hear it!

[**💡 Request a Feature**](https://github.com/pluk-inc/pluk/issues/new?template=feature_request.md)

### 📝 Issue Templates

- [🐛 Bug Report](/.github/ISSUE_TEMPLATE/bug_report.md)
- [💡 Feature Request](/.github/ISSUE_TEMPLATE/feature_request.md)
- [📚 Documentation](/.github/ISSUE_TEMPLATE/documentation.md)
- [❓ Question](/.github/ISSUE_TEMPLATE/question.md)

## 🏷️ Labels

We use labels to categorize and prioritize issues:

| Label | Description |
|-------|-------------|
| `bug` | Something isn't working |
| `enhancement` | New feature or request |
| `documentation` | Improvements to documentation |
| `good first issue` | Good for newcomers |
| `help wanted` | Extra attention is needed |
| `priority: high` | High priority issues |
| `status: in progress` | Currently being worked on |

## 📊 Project Status

- **Status**: Open source beta
- **Platform**: macOS 15.0
- **Architecture**: Apple Silicon & Intel
- **Development**: Active

## 🔗 Quick Links

- 🌐 **Website**: [pluk.sh](https://www.pluk.sh/)
- 📝 **Join Waitlist**: [pluk.sh](https://www.pluk.sh)
- 🐦 **Twitter**: [@pluk_sh](https://x.com/pluk_sh)

## 🤝 Contributing

Source contributions are welcome. Read [CONTRIBUTING.md](./CONTRIBUTING.md) before opening a pull request. For security vulnerabilities, follow [SECURITY.md](./SECURITY.md) instead of opening a public issue.

We welcome:

- **Bug reports** with detailed reproduction steps
- **Feature suggestions** with clear use cases
- **Code contributions** with focused tests and validation
- **Documentation improvements**
- **Community feedback** and discussions

---

<div align="center">
  <p>Made with ❤️ for the developer community</p>
  <p>
    <a href="https://www.pluk.sh/">Website</a> •
    <a href="https://github.com/pluk-inc/pluk/issues">Issues</a>
  </p>
</div>
