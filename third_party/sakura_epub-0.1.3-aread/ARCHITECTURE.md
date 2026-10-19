# 📚 Sakura EPUB - Architecture Documentation

## 🏗️ Folder Structure Overview

This document explains the architecture and organization of the Sakura EPUB Flutter package.

## 📁 Directory Structure

```
lib/
├── sakura_epub.dart              # Main entry point & public API
├── core/                         # Core functionality
│   ├── constants/               # App-wide constants
│   ├── config/                  # Configuration classes
│   └── utils/                   # Utility functions
├── models/                       # Data models
├── services/                     # Business logic
│   ├── storage/                 # Database & storage
│   ├── epub/                    # EPUB parsing
│   └── progress/                # Progress tracking
├── controllers/                  # State management (GetX)
├── ui/                          # User interface
│   ├── screens/                 # Full-page views
│   ├── widgets/                 # Reusable components
│   └── themes/                  # Visual styling
├── helpers/                      # Helper utilities
│   ├── pagination/              # Page calculation
│   ├── rendering/               # Content rendering
│   └── gestures/                # Touch interactions
├── localization/                 # Internationalization
│   └── languages/               # Translation files
└── exports/                      # Public API exports
```

## 🎯 Module Descriptions

### **Core Module** (`lib/core/`)
Foundation layer containing:
- **constants/**: Application-wide constants (themes, storage keys, UI values)
- **config/**: Configuration classes for reader behavior
- **utils/**: Reusable utility functions (text, file, color manipulation)

**Key Files:**
- `app_constants.dart` - General app constants
- `theme_constants.dart` - Theme and font definitions
- `storage_keys.dart` - Storage key constants
- `epub_config.dart` - Reader configuration
- `text_utils.dart` - Text manipulation utilities
- `file_utils.dart` - File handling utilities

### **Models Module** (`lib/models/`)
Pure data structures with no business logic:
- `book_progress_model.dart` - Reading progress data
- `chapter_model.dart` - Chapter information
- `bookmark_model.dart` - Bookmark data
- `highlight_model.dart` - Text highlights
- `note_model.dart` - Reader notes
- `reader_settings_model.dart` - User preferences

### **Services Module** (`lib/services/`)
Business logic and data operations:

**Storage** (`services/storage/`):
- `isar_service.dart` - Isar database operations
- `cache_service.dart` - Caching logic
- `storage_service.dart` - General storage

**EPUB** (`services/epub/`):
- `epub_parser_service.dart` - EPUB parsing
- `epub_loader_service.dart` - Book loading
- `chapter_service.dart` - Chapter management

**Progress** (`services/progress/`):
- `progress_service.dart` - Progress tracking
- `progress_singleton.dart` - Singleton instance

### **Controllers Module** (`lib/controllers/`)
State management using GetX:
- `reader_controller.dart` - Main reader state
- `theme_controller.dart` - Theme management
- `chapter_controller.dart` - Chapter navigation
- `settings_controller.dart` - Settings management
- `bookmark_controller.dart` - Bookmark operations

### **UI Module** (`lib/ui/`)
Presentation layer:

**Screens** (`ui/screens/`):
- `reader_screen.dart` - Main reading interface
- `loading_screen.dart` - Book loading screen

**Widgets** (`ui/widgets/`):
- `reader/` - Reading-related widgets
- `navigation/` - Navigation components
- `settings/` - Settings UI
- `common/` - Shared widgets

**Themes** (`ui/themes/`):
- `app_theme.dart` - Theme definitions
- `color_schemes.dart` - Color palettes
- `text_styles.dart` - Typography

### **Helpers Module** (`lib/helpers/`)
Utility functions:
- `pagination/` - Page calculation logic
- `rendering/` - HTML rendering
- `gestures/` - Touch gesture handling

### **Localization Module** (`lib/localization/`)
Multi-language support:
- `app_translations.dart` - Translation keys
- `languages/` - Language files (en_us.dart, tr_tr.dart, etc.)
- `localization_service.dart` - Locale management

### **Exports Module** (`lib/exports/`)
Public API surface:
- `sakura_epub_exports.dart` - Consolidated exports

## 🔄 Data Flow Architecture

```
┌─────────────────┐
│   User Action   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   UI Widget     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Controller    │ (GetX State Management)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Service      │ (Business Logic)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Model/Storage  │ (Data Layer)
└─────────────────┘
```

## 📝 Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Models | `*_model.dart` | `book_progress_model.dart` |
| Services | `*_service.dart` | `epub_parser_service.dart` |
| Controllers | `*_controller.dart` | `reader_controller.dart` |
| Screens | `*_screen.dart` | `reader_screen.dart` |
| Widgets | Descriptive | `chapter_drawer.dart` |
| Constants | `*_constants.dart` | `theme_constants.dart` |
| Utils | `*_utils.dart` | `text_utils.dart` |

## 🎨 Best Practices

### 1. **Separation of Concerns**
- Keep UI logic in widgets
- Keep business logic in services
- Keep state in controllers
- Keep data structures in models

### 2. **File Organization**
- One primary class per file
- Group related files in directories
- Use barrel files for exports
- Keep files under 500 lines

### 3. **Import Organization**
```dart
// 1. Dart imports
import 'dart:io';

// 2. Flutter imports
import 'package:flutter/material.dart';

// 3. Package imports
import 'package:get/get.dart';

// 4. Local imports
import 'package:sakura_epub/core/constants/app_constants.dart';
```

### 4. **Code Documentation**
- Use dartdoc comments for public APIs
- Document complex logic
- Add examples for public methods

### 5. **Testing Strategy**
- Unit tests for services and utilities
- Widget tests for UI components
- Integration tests for user flows

## 🚀 Getting Started

### Adding a New Feature

1. **Create Model** (if needed)
   ```
   lib/models/new_feature_model.dart
   ```

2. **Create Service**
   ```
   lib/services/new_feature_service.dart
   ```

3. **Create Controller**
   ```
   lib/controllers/new_feature_controller.dart
   ```

4. **Create UI**
   ```
   lib/ui/widgets/new_feature/
   ```

5. **Export Public APIs**
   ```
   lib/exports/sakura_epub_exports.dart
   ```

### Migration Guide

If you're migrating from the old single-file structure:

1. Move constants to `core/constants/`
2. Move models to `models/`
3. Move services to `services/`
4. Move UI components to `ui/`
5. Update imports in `sakura_epub.dart`
6. Update exports in `exports/sakura_epub_exports.dart`

## 📦 Public API Surface

The main `sakura_epub.dart` file exposes:

### Initialization
```dart
SakuraEpub.initialize()
```

### Opening Books
```dart
SakuraEpub.openLocalBook()
SakuraEpub.openURLBook()
SakuraEpub.openAssetBook()
SakuraEpub.openParsedBook()
```

### Progress Management
```dart
SakuraEpub.getBookProgress()
SakuraEpub.setCurrentPageIndex()
SakuraEpub.setCurrentChapterIndex()
```

### Configuration
```dart
SakuraEpub.updateLocale()
SakuraEpub.registerAddNoteHandler()
SakuraEpub.registerAddToShelfHandler()
```

## 🔐 Internal vs Public

**Public** (exported via `exports/`):
- Main API methods
- Essential models
- Configuration classes

**Internal** (not exported):
- Implementation details
- Helper functions
- Internal widgets
- Service implementations

## 📊 Dependencies

### Core Dependencies
- `flutter` - UI framework
- `get` - State management
- `epubx` - EPUB parsing
- `isar_community` - Database

### Utility Dependencies
- `get_storage` - Key-value storage
- `path_provider` - File paths
- `http` - Network requests
- `cached_network_image` - Image caching

## 🎯 Future Enhancements

- [ ] Add comprehensive unit tests
- [ ] Implement widget tests
- [ ] Add integration tests
- [ ] Create example app
- [ ] Add API documentation
- [ ] Performance profiling
- [ ] Accessibility improvements

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [GetX Documentation](https://pub.dev/packages/get)
- [Isar Documentation](https://isar.dev)
- [EPUB Specification](https://www.w3.org/publishing/epub3/)

---

**Last Updated:** February 2026  
**Version:** 0.0.1  
**Maintainer:** Sakura EPUB Team
