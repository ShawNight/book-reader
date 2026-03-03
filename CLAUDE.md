# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation Maintenance

**IMPORTANT**: When developing new features, always update documentation following `docs/DOCUMENTATION_GUIDE.md`:

| Action | Documentation to Update |
|--------|------------------------|
| New Model/Service/Screen | Update Layer Structure below |
| New Feature | Update Implemented Features + README.md |
| New Configuration | Update config tables in this file + README.md |
| Bug fix/Found issue | Update Known Issues section |

See `docs/DOCUMENTATION_GUIDE.md` for detailed checklist and templates.

---

## Project Overview

**YueDu Flutter (YDF)** - An open-source book reader app that supports importing local JSON book sources (compatible with "阅读3.0" format). Users can import existing book source libraries for "configure once, read anywhere".

## Build and Run Commands

```bash
# Run on Linux (recommended for development)
flutter run -d linux

# Build Android APK (debug)
flutter build apk --debug

# Build Android APK (release)
flutter build apk --release

# Run tests
flutter test

# Generate code (JSON serialization, Riverpod providers)
flutter pub run build_runner build --delete-conflicting-outputs

# Clean and regenerate
flutter clean && flutter pub get && flutter pub run build_runner build --delete-conflicting-outputs
```

## Architecture

### Layer Structure

```
lib/
├── main.dart                    # App entry point, Riverpod ProviderScope
├── models/                      # Data models with JSON serialization
│   ├── book_source.dart         # BookSource, RuleSearch, RuleToc, RuleContent, Chapter
│   ├── book.dart                # Book model for bookshelf (with progress + scroll position)
│   ├── bookmark.dart            # Bookmark model for reading bookmarks
│   ├── reader_settings.dart     # Reader settings (font, theme, spacing, page turn mode, etc.)
│   ├── source_test_result.dart  # Source test status and result models
│   └── *.g.dart                 # Generated JSON serialization code
├── services/                    # Business logic layer
│   ├── book_source_service.dart # Import/parse/save book sources, batch delete
│   ├── search_service.dart      # Web scraping engine, rule parser
│   ├── search_history_service.dart   # Search history management
│   ├── bookshelf_service.dart   # Bookshelf CRUD operations
│   ├── reader_settings_service.dart  # Reader settings persistence
│   ├── chapter_cache_service.dart    # Chapter content persistent cache
│   ├── batch_download_service.dart   # Batch chapter download with progress tracking
│   ├── bookmark_service.dart    # Bookmark management (add/remove/list)
│   └── source_test_service.dart      # Source validity testing service
├── widgets/                     # Reusable UI components
│   └── simulation_page_turn.dart     # Simulation page turn animation widget
└── screens/                     # UI layer
    ├── home_screen.dart         # Tab navigation (Bookshelf, Sources, Settings)
    ├── search_screen.dart       # Multi-source search with streaming results
    ├── chapter_list_screen.dart # Chapter list with search, sort, group
    ├── reader_screen.dart       # PageView-based reader with full features
    └── source_purify_screen.dart     # Source testing and purification
```

### Key Architectural Patterns

1. **Singleton Services**: All services use factory pattern with internal constructor
2. **State Management**: Riverpod with ProviderScope at app root
3. **JSON Serialization**: `json_annotation` + `build_runner` for model serialization
4. **Rule Engine**: SearchService implements a Legado-compatible rule parser supporting:
   - CSS selectors (`.class`, `#id`, `tag`)
   - XPath-like rules (`@`, `tag.`, `class.`, `id.`)
   - JSON path (`$.data.items`)
   - Regex replacement (`##pattern##replacement`)

### Data Flow

1. **Import Book Sources**: JSON file → `BookSourceService.parseBookSources()` → stored in `~/book_sources/sources.json`
2. **Search**: Keyword → `SearchService.searchStream()` → concurrent requests to all enabled sources → parse HTML/JSON via rules → stream results
3. **Read**: Chapter URL → check `ChapterCacheService` → if not cached, fetch via `SearchService.getChapterContent()` → save to cache

### Book Source Format

Book sources must be compatible with 阅读3.0 JSON format. Key fields:
- `bookSourceName`, `bookSourceUrl`: Identity
- `searchUrl`: URL template with `{{key}}` placeholder
- `ruleSearch`: CSS/JSON selectors for search results
- `ruleToc`: Chapter list selectors
- `ruleContent`: Content extraction selectors

## Implemented Features

### Reader Features (ReaderScreen)
- **Reading Settings**:
  - Font size (12-32)
  - Line height (1.2-3.0)
  - Paragraph spacing (0-24)
  - Indent size (0-4 characters)
  - Horizontal/Vertical padding
  - Show/hide chapter title
- **Themes**: 6 preset themes (米黄色, 护眼绿, 夜间模式, 纯白, 羊皮纸, 蓝色护眼)
- **Page Turn Modes**: 4 modes with realistic animations
  - Slide: Default horizontal swipe
  - Cover: Page overlay transition
  - Simulation: Realistic page flip with shadow and edge effects
  - Scroll: Vertical continuous scrolling
- **Tap to Turn Page**: Click left/right screen edges to navigate
- **Chapter Progress**: Real-time progress bar and percentage within chapter
- **Progress Saving**: Auto-save chapter index and scroll position (2s delay)
- **Progress Restoration**: Resume reading at exact position when reopening
- **Content Caching**: Persistent cache with 30-day expiry
- **Bookmarks**: Full bookmark functionality
  - Add/remove bookmarks at current reading position
  - Optional notes for each bookmark
  - Bookmark list dialog with quick navigation
  - Visual indicator (solid/hollow icon) for bookmark status
  - Bookmarks persist across sessions
- **Chapter Drawer**: Left-side drawer for chapter navigation
  - Directory-style layout ("第N章 章节名称")
  - Download status indicators for each chapter
  - Batch download functionality with progress tracking
  - Select all / Deselect all
  - Background download, non-blocking UI
  - Cancel download at any time

### Bookshelf Features (HomeScreen)
- **Book Management**: Add, remove, update reading progress
- **Book Info Display**: Cover, author, last read chapter, source name
- **Reading Progress**: Auto-save last chapter and scroll position, display "读到：第X章"
- **Direct Reading**: Click book to open at last read position (skip chapter list)
- **Swipe to Delete**: Left swipe reveals delete action
- **Sorting**: Multiple sorting options with persistence
  - Sort by: Added time (default), Name, Author, Last read time, Read progress
  - Toggle ascending/descending by clicking same sort option
  - Settings saved to reader_settings.json
- **Batch Management**: Multi-select mode for bulk operations
  - Long press to enter selection mode
  - Select all / Deselect all
  - Batch delete with confirmation dialog
  - Batch mark as read / unread
  - Bottom action bar with operation count display

### Book Source Features (HomeScreen - Sources Tab)
- **Import Sources**: Import JSON files (append mode, won't overwrite)
- **Enable/Disable**: Toggle individual sources
- **Delete Sources**: Remove with confirmation dialog
- **View Modes**: List view / Grouped view by source type
- **Source Purify**: Test source validity, batch delete invalid sources
  - Test sources using default keyword "斗罗"
  - Real-time progress display with statistics
  - 8-second timeout per source
  - 5 concurrent tests maximum
  - Filter by status (all/valid/invalid/pending)
  - One-click purify invalid sources with confirmation

### Chapter List Features (ChapterListScreen)
- **Directory Style Layout**: Chapter number and name displayed as "第N章 章节名称"
- **Top Actions Bar**: Prominent "批量下载" button with cached count badge
- **Search Chapters**: Filter chapters by name
- **Sort Order**: Ascending / Descending toggle
- **Group View**: Group by 50 chapters
- **Quick Jump**: First chapter, Last chapter, Last read position
- **Continue Reading**: Play button to jump to last read position
- **Visual Indicators**: Highlight current chapter, mark latest chapter
- **Bookmark Toggle**: Add/remove from bookshelf via bookmark icon
- **Bookmark Indicators**: Chapters with bookmarks show bookmark icon
- **Batch Download**: Multi-select mode for batch chapter downloads
  - Select all / Deselect all
  - Download progress display (completed/total)
  - Background download, non-blocking UI
  - Cancel download at any time
  - Download status indicators (not downloaded/downloading/downloaded/failed)
  - Downloaded chapters saved to cache for offline reading

### Search Features (SearchScreen)
- **Multi-Source Search**: Concurrent search across all enabled sources
- **Streaming Results**: Results appear as they arrive
- **Quick Add to Bookshelf**: ⊕ button on each search result
- **Search History**: Auto-save keywords (max 20), click to re-search, clear all

### Settings Features (HomeScreen - Settings Tab)
- **Cache Management**: View and clear chapter cache
  - Display cache size and file count
  - One-click clear all cached chapters
  - Confirmation dialog before clearing

## Important Implementation Details

### Rule Parsing (SearchService)

The `_getElements()`, `_extractTextNew()`, and `_extractUrlNew()` methods implement a custom rule engine. When modifying:
- Rules are split by `@` for chained selections
- Support `@CSS:` prefix for raw CSS selectors
- `##pattern##replacement` for regex at end of rules
- Negative indices supported (`.class.-1` gets last element)

### Content Extraction Fallback

When book source rules fail, `_tryCommonContentSelectors()` attempts common novel content selectors (`#content`, `.chapter-content`, etc.) and falls back to finding the largest text block.

### Chapter Caching

`ChapterCacheService` provides persistent chapter content caching:
- Uses MD5 hash of chapter URL as cache key
- Stores in `~/Documents/chapter_cache/` directory
- 30-day cache expiry with automatic cleanup
- Check cache before network request
- `getCacheStats()` for cache statistics (file count, total size)
- `clearAllCache()` for clearing all cached content

### Batch Download

`BatchDownloadService` manages chapter batch downloads:
- Singleton service with progress stream
- Concurrent downloads (default 3 concurrent)
- Non-blocking background download
- Real-time progress tracking via `progressStream`
- Download status tracking (notDownloaded/downloading/downloaded/failed)
- Cancelable downloads
- Integrates with `ChapterCacheService` for storage

### Reader Settings Model

`ReaderSettings` model contains:
```dart
- fontSize: double (12-32, default 18)
- lineHeight: double (1.2-3.0, default 1.8)
- themeIndex: int (0-5, default 0)
- verticalPadding: double (default 16)
- horizontalPadding: double (default 16)
- paragraphSpacing: double (0-24, default 8)
- indentSize: double (0-4, default 2)
- showChapterTitle: bool (default true)
- pageTurnModeIndex: int (0-3, default 0) // 0=slide, 1=cover, 2=simulation, 3=scroll
- bookshelfSortModeIndex: int (0-4, default 0) // 0=addedTime, 1=name, 2=author, 3=lastReadTime, 4=readProgress
- bookshelfSortAscending: bool (default false)
```

### Page Turn Implementation

- **Slide Mode**: Default PageView horizontal swipe
- **Cover Mode**: PageView with cover transition
- **Simulation Mode**: Custom `SimulationPageTurn` widget with:
  - Realistic page flip animation with shadow effects
  - Gesture-based dragging for manual page turn
  - Page edge highlighting and fold effects
  - Smooth transition using Curves.easeInOutCubic
- **Scroll Mode**: ListView vertical scrolling
- **Tap Navigation**: Left 30% = previous, Right 30% = next, Center = toggle controls

### Data Persistence

All data stored in app documents directory:
```
~/Documents/ (or ~/.local/share/yuedu_flutter/ on Linux)
├── bookshelf.json           # Bookshelf data
├── reader_settings.json     # Reader settings
├── search_history.json      # Search history keywords
├── bookmarks.json           # Reading bookmarks
├── book_sources/
│   └── sources.json         # Imported book sources
└── chapter_cache/           # Cached chapter content (MD5 keys)
```

## Linting

The project uses `flutter_lints` with additional rules:
- `prefer_const_constructors: true`
- `prefer_single_quotes: true`
- `avoid_print: false` (debugging output is allowed)

## Dependencies

Key dependencies in `pubspec.yaml`:
- `flutter_riverpod: ^2.4.9` - State management
- `dio: ^5.4.0` - HTTP client
- `html: ^0.15.4` - HTML parsing
- `json_annotation: ^4.8.1` - JSON serialization
- `path_provider: ^2.1.2` - File system access
- `crypto: ^3.0.3` - MD5 hashing for cache keys
- `file_selector: ^1.0.3` - File picker for importing sources
- `url_launcher: ^6.2.2` - Open URLs in browser
- `freezed_annotation: ^2.4.0` - Immutable data classes

## Known Issues / TODO

2. **Some book sources may fail**: Due to rule incompatibility or website changes
3. **Reading Statistics**: Total time, word count not tracked

## Notes

- Sample book sources available at project root: `书源.json`
- Data persistence uses simple JSON files for storage
- The app targets Flutter 3.x with Material 3 design
- All services use singleton pattern via factory constructor
- For debugging, use `avoid_print: false` to allow console output

## Related Documentation

- `README.md` - User guide and usage instructions
- `docs/PROJECT_SPEC.md` - Original project specification
- `docs/BOOKSHELF_GUIDE.md` - Detailed bookshelf feature guide
- `docs/UI_GUIDE.md` - UI layout and design specifications
- `docs/flutter-android-deployment.md` - Android deployment guide
- `scripts/` - Development scripts and test files
