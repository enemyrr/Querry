# Changelog

# Pluk Release Notes

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

*Note: Table creation functionality is coming in a future release.*

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
