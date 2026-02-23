# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

YueDu Flutter (YDF) - An open-source book reader app that supports importing local JSON book sources (compatible with "阅读3.0" format). Users can import existing book source libraries for "configure once, read anywhere".

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
│   ├── book_source.dart         # BookSource, RuleSearch, RuleToc, RuleContent
│   ├── book.dart                # Book model for bookshelf
│   ├── reader_settings.dart     # Reader settings (font, theme, page turn mode)
│   └── bookmark.dart            # Bookmark model for chapter bookmarks
├── services/                    # Business logic layer
│   ├── book_source_service.dart # Import/parse/save book sources
│   ├── search_service.dart      # Web scraping engine, rule parser
│   ├── bookshelf_service.dart   # Bookshelf CRUD operations
│   ├── reader_settings_service.dart  # Reader settings persistence
│   ├── chapter_cache_service.dart    # Chapter content persistent cache
│   └── bookmark_service.dart    # Bookmark management
└── screens/                     # UI layer
    ├── home_screen.dart         # Tab navigation (Bookshelf, Sources, Settings)
    ├── search_screen.dart       # Multi-source search with streaming results
    ├── chapter_list_screen.dart # Chapter list with search, sort, group
    └── reader_screen.dart       # PageView-based reader with full features
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
- **Reading Settings**: Font size (12-32), line height (1.2-3.0), 6 themes
- **Page Turn Modes**: Slide, Cover, Simulation, Scroll
- **Tap to Turn Page**: Click left/right screen edges to navigate
- **Chapter Progress**: Real-time progress bar and percentage
- **Content Caching**: Persistent cache with 30-day expiry
- **Bookmarks**: Add/remove bookmarks per chapter

### Bookshelf Features (HomeScreen)
- **Book Management**: Add, remove, update reading progress
- **Book Info Display**: Cover, author, last read chapter, source

### Book Source Features (HomeScreen - Sources Tab)
- **Import Sources**: Import JSON files (append mode, won't overwrite)
- **Enable/Disable**: Toggle individual sources
- **Delete Sources**: Remove with confirmation dialog
- **View Modes**: List view / Grouped view by source type

### Chapter List Features (ChapterListScreen)
- **Search Chapters**: Filter chapters by name
- **Sort Order**: Ascending / Descending toggle
- **Group View**: Group by 50 chapters
- **Quick Jump**: First chapter, Last chapter, Last read position
- **Visual Indicators**: Highlight current chapter, mark latest chapter

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

### Reader Settings

`ReaderSettings` model and `ReaderSettingsService` handle:
- Font size (12-32 range)
- Line height (1.2-3.0 range)
- Theme selection (6 preset themes)
- Page turn mode (slide/cover/simulation/scroll)
- Tap-to-turn-page toggle
- All settings persist to `~/Documents/reader_settings.json`

### Page Turn Implementation

- **Slide Mode**: Default PageView horizontal swipe
- **Cover Mode**: PageView with cover transition
- **Simulation Mode**: Standard page flip (placeholder)
- **Scroll Mode**: ListView vertical scrolling
- **Tap Navigation**: Left 30% = previous, Right 30% = next, Center = toggle controls

## Linting

The project uses `flutter_lints` with additional rules:
- `prefer_const_constructors: true`
- `prefer_single_quotes: true`
- `avoid_print: false` (debugging output is allowed)

## Dependencies

Key dependencies in `pubspec.yaml`:
- `flutter_riverpod`: State management
- `dio`: HTTP client
- `html`: HTML parsing
- `json_annotation`: JSON serialization
- `path_provider`: File system access
- `crypto`: MD5 hashing for cache keys
- `file_selector`: File picker for importing sources

## Known Issues / TODO

1. **Simulation Page Turn**: Currently uses default PageView, needs custom animation
2. **Image Support**: Images in chapter content not yet supported
3. **Book Source Testing**: No validation/test feature for imported sources
4. **Some book sources may fail**: Due to rule incompatibility or website changes

## Notes

- Sample book sources available at project root: `书源.json`
- Data persistence uses simple JSON files in app documents directory (not Isar database despite being listed in dependencies)
- The app targets Flutter 3.x with Material 3 design
- All services use singleton pattern via factory constructor
