# Changelog

# Pluk Release Notes

## [0.0.1-beta.24] – 2025-10-21

### ✨ New Features

- **Enhanced MongoDB View Support** - Restored full functionality to MongoDB views including edit, delete, and AI-powered query assistance with seamless integration across all MongoDB data types

### 🛠️ Bug Fixes & Improvements

- **FIXED**: MySQL remote server connections now work properly with SSL authentication ([#31](https://github.com/pluk-inc/Pluk/issues/31)) - Resolved "A secure connection to the server is required for authentication" error when connecting to remote MySQL hosts on local networks and external servers
- **FIXED**: New connection dialog no longer forces window to expand to full screen ([#32](https://github.com/pluk-inc/Pluk/issues/32)) - Application window now respects previously set dimensions with proper scrolling behavior and responsive layout
- Various interface refinements and minor UI improvements for better visual consistency and user experience

## [0.0.1-beta.23] – 2025-10-21

### ✨ New Features

#### **Database Schema Viewer**

- **Read-only Schema Browser** - Explore database structure including columns, indexes, and constraints
- Quick reference for understanding your database schema without leaving Pluk
- Foundation for future schema editing capabilities

#### **Enhanced User Experience**

- **Customizable Window Size** - Set preferred width and height when opening Pluk windows
- **Improved Search Focus** - Search input now automatically focuses for faster navigation

### 🛠️ Bug Fixes & Improvements

#### **Interface Stability**

- **FIXED**: Convex component documents now load correctly without errors
- **FIXED**: Tabs are now fully clickable and responsive throughout the interface
- Improved overall interface reliability and interaction handling

---

**Note**: The Schema Viewer is currently in read-only mode. Full editing capabilities will be added in a future release.

## [0.0.1-beta.22] – 2025-10-08

### 🪄 **Convex Joins Pluk** — Real-Time. Native. Seamless.

We’re thrilled to announce **native Convex integration** — bringing real-time data synchronization and reactive backends directly into Pluk. This unlocks an entirely new way to build and explore your data with zero setup friction.

#### **Convex Integration**

- 🧠 **Full Convex Backend Support** — Native integration for queries, mutations, and subscriptions with real-time synchronization built in
- ⚡ **One-Click OAuth Connection** — Securely connect to your Convex account using OAuth, then select a project and start exploring the data
- 🧪 Live Development & Deployment Ready — View your Convex production deployments and other environments, and seamlessly switch between environments and components directly from Pluk — no manual setup required.

This is our biggest backend integration yet — transforming Pluk into a powerful companion for Convex developers.

### 🎨 **A Fresh New Look**

#### **Modern UI Redesign**

- ✨ Complete visual overhaul with a modern interface, refined typography, and a cleaner color palette
- Improved visual hierarchy makes key actions more discoverable
- Polished animations and transitions create a smoother, more responsive experience

#### **Flexible Sidebar Layout**

- 🧱 Resizable sidebar — adjust to fit your workflow
- Optimized layouts for both compact and spacious workspaces

### 🚀 **Performance & Developer Experience**

#### **Native Tab Architecture**

- 🧩 Migrated to a native tab-based system for improved stability and speed
- 🌐 Intelligent connection pooling for more efficient resource use
- More robust state management and recovery for long-running sessions

## [0.0.1-beta.21] – 2025-09-17

### 🛠️ Bug Fixes & Improvements

#### **Database Connection Reliability**

- **FIXED**: PostgreSQL connection issues caused by URL encoding of passwords containing special characters
- **FIXED**: MySQL import URLs now correctly default to PostgreSQL database connections
- Enhanced connection string parsing to handle special characters in credentials properly

### ✨ New Features

#### **Connection Testing**

- **NEW**: Test Connection button added during connection creation process
- Verify database connectivity before saving connection configurations
- Immediate feedback on connection parameters and credentials

### 🔧 Under the Hood

- Improved URL-friendly parsing for database credentials
- Better handling of special characters in connection strings

## [0.0.1-beta.20] – 2025-09-05

### 🎯 Major Features

#### **AI-Powered SQL Editor is Here** 🆕

Pluk now comes with a **dedicated SQL Editor tab** that works across **SQLite, MySQL, PostgreSQL, and MongoDB**.

- **Open in a New Tab** – Write and run queries in a focused editor view
- **AI-Powered Querying** – Hit `cmd+k` to generate queries from natural language or refine existing SQL
- **Smart Error Recovery** – Pluk automatically detects query errors and suggests fixes, so you never get stuck
- **Schema Awareness** – Browse and explore your database schema directly from the editor

This isn’t just another SQL editor — it’s a smarter, AI-assisted way to work with your databases.

---

### ✨ New Features

#### **Schema Switching**

- Seamlessly switch between database schemas
- Select and explore tables across schemas within the same connection

---

### 🛠️ Bug Fixes & Improvements

#### **Query & Data Handling**

- **FIXED**: Active filters now persist after row updates and deletes (#4)
- **FIXED**: Query error state no longer locks the UI — you can now clear, edit, and retry queries (#6)
- **FIXED**: SQLite table names with spaces (e.g., `user profiles`) are now supported (#11)

#### **Interface & UX**

- **FIXED**: Scroll indicator now consistently appears in the Databases list during scroll (#7)
- Other minor bug fixes and UI improvements for a smoother experience

---

👉 With this release, Pluk becomes more than a database explorer — it’s your **AI-powered SQL companion**. Whether you’re working with SQLite, MySQL, Postgres, or MongoDB, Pluk now gives you a smarter way to query, debug, and explore your data.

## [0.0.1-beta.19] – 2025-08-22

### 🎯 Major Features

#### **MySQL Support is Here** 🆕

Pluk now speaks **MySQL**!

- Connect to any **MySQL database** with full driver support
- Run queries, edit data with **complete CRUD operations**
- **Query with AI** - Ask questions about your MySQL data in natural language
- **Rename and delete tables** directly from the interface
- Works seamlessly with existing MySQL installations and cloud instances

This makes Pluk a powerful companion for developers working with MySQL in development, staging, and production environments. From local development databases to cloud-hosted MySQL instances, Pluk now handles it all with full AI integration.

_Note: Table creation functionality is coming in a future release._

### ✨ New Features

#### **Enhanced Database Management**

- **Table Operations** - Delete and rename tables across MySQL, SQLite, and PostgreSQL databases
- **SQLite Filter Support** - Advanced filtering capabilities now available for SQLite databases, bringing parity with other database drivers

### 🛠️ Bug Fixes & Improvements

#### **Filter Operations**

- **FIXED**: Restored filter operators that were previously removed, improving data exploration capabilities across all database types
- Enhanced filter consistency between different database drivers

#### **User Experience**

- Better error handling for database operations

---

👉 With this release, **MySQL becomes a first-class citizen in Pluk**, joining SQLite as a fully supported database driver. Whether you're prototyping with SQLite or running production workloads on MySQL, Pluk now provides a unified interface for all your database exploration needs.

## [0.0.1-beta.18] – 2025-08-16

### 🚀 Major Release

#### **SQLite Support is Here** 🆕

Pluk now speaks **SQLite**!

- Connect to any **SQLite file** (`.sqlite`, `.db`, `.sqlite3`)
- Run queries, edit data with **full read/write access**
- Works seamlessly across all SQLite file formats

This makes Pluk a powerful local-first companion for developers who rely on SQLite for prototyping, embedded apps, and production systems.

---

### 🛠️ Fixes & Improvements

#### **Interface Stability**

- ✅ Fixed homescreen selection issues when disconnecting popovers
- ✅ Resolved startup loading glitches
- ✅ Corrected layout width calculation bugs
- ✅ Loading indicators now render in the right place

#### **Data Handling**

- ✅ Updates handle `NULL` values without errors
- ✅ Removed flickering invalid columns during state changes
- ✅ Popover connection data now stays accurate

#### **User Experience**

- Smoother, more reliable popover interactions
- Cleaner data transitions
- Improved error handling for tricky cases

---

👉 With this release, **SQLite becomes a first-class citizen in Pluk**, making it easier than ever to query and explore your data.

## [0.0.1-beta.17] - 2025-08-02

### 🛡️ Privacy & Security

#### **Enhanced Password Protection**

- **Keychain Integration** - Database passwords are now securely stored in the system keychain instead of local storage
- **Privacy Protection** - Passwords are completely hidden from the home screen to prevent accidental exposure and shoulder surfing

### ✨ New Features

#### **Connection Management**

- **Improved Connection Creation** - Improved connection creation experience that replaces complex URI strings like postgresql://user:pass@host:port/db with a simple, intuitive form
- **Right-Click Context Menus** - Added right-click support on connection status headers for quick access to connection actions

#### **User Interface Enhancements**

- **Updated Floating Action Bar** - AI Search bar is now more visually prominent than other buttons, making it easier to discover and use

### 🚀 Performance & Developer Experience

#### **Database Performance**

- **Faster Table Loading** - Significantly improved performance when tables are initially loaded
- **Optimized Data Refresh** - Enhanced refresh mechanisms that properly respect active filters and user preferences

### 🛠️ Bug Fixes & Improvements

#### **Connection Reliability**

- **FIXED**: Connected databases now display correctly even when no default database is configured
- **FIXED**: Data refresh operations now properly respect applied filters, ensuring consistent view state
- Improved connection state management and database discovery

### 🔧 Under the Hood

- Enhanced connection state handling for better reliability
- Improved error handling in database connection workflows
- Better separation of connection configuration logic
- Optimized data loading patterns for improved user experience
- Minor UI improvement to align with the design system

## [0.0.1-beta.16] - 2025-07-29

### ✨ New Features

#### **Foreign Key Navigation**

- **Quick Foreign Key Filtering** - Click any record to instantly navigate to related tables with foreign key filters automatically applied, streamlining relational data exploration

## [0.0.1-beta.15] - 2025-01-17

### ✨ New Features

#### **Enhanced Table Interaction**

- **Right-click Context Menu** - Table rows now support right-click actions for quick access to row-specific operations
- **Multi-row Selection** - Select multiple rows simultaneously for batch operations and improved workflow efficiency

#### **Smart Connection Management**

- **Intelligent Tab Handling** - When opening a connection, Pluk now asks whether to create a new tab or use an existing connection tab, preventing accidental duplicate connections

### 🎨 UI Improvements

#### **Visual Polish**

- **Enhanced Light Theme** - Improved light mode with better contrast, readability, and visual consistency across all interface elements
- **Smoother Cell Selection** - More responsive and fluid cell selection animations for a polished user experience

### 🛠️ Bug Fixes & Improvements

#### **Database Operations**

- **FIXED**: Insert operations now work correctly even when tables contain no existing records
- **FIXED**: Neon database connections no longer fail due to TLS configuration errors, ensuring reliable PostgreSQL connectivity

#### **Connection Reliability**

- **FIXED**: Automatic reconnection system now properly restores connections when network interruptions occur
- **FIXED**: Tab bar display no longer gets cut off on the last tab, ensuring all tabs remain fully visible and accessible

### 🔧 Under the Hood

- Improved error handling for database connection edge cases
- Enhanced connection state management for better reliability

## [0.0.1-beta.14] - 2025-01-17

### ✨ New Features

#### **Enhanced Table Interaction**

- **Right-click Context Menu** - Table rows now support right-click actions for quick access to row-specific operations
- **Multi-row Selection** - Select multiple rows simultaneously for batch operations and improved workflow efficiency

#### **Smart Connection Management**

- **Intelligent Tab Handling** - When opening a connection, Pluk now asks whether to create a new tab or use an existing connection tab, preventing accidental duplicate connections

### 🎨 UI Improvements

#### **Visual Polish**

- **Enhanced Light Theme** - Improved light mode with better contrast, readability, and visual consistency across all interface elements
- **Smoother Cell Selection** - More responsive and fluid cell selection animations for a polished user experience

### 🛠️ Bug Fixes & Improvements

#### **Database Operations**

- **FIXED**: Insert operations now work correctly even when tables contain no existing records
- **FIXED**: Neon database connections no longer fail due to TLS configuration errors, ensuring reliable PostgreSQL connectivity

#### **Connection Reliability**

- **FIXED**: Automatic reconnection system now properly restores connections when network interruptions occur
- **FIXED**: Tab bar display no longer gets cut off on the last tab, ensuring all tabs remain fully visible and accessible

### 🔧 Under the Hood

- Improved error handling for database connection edge cases
- Enhanced connection state management for better reliability
