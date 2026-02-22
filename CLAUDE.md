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
├── main.dart              # App entry point, Riverpod ProviderScope
├── models/                # Data models with JSON serialization
│   ├── book_source.dart   # BookSource, RuleSearch, RuleToc, RuleContent
│   └── book.dart          # Book model for bookshelf
├── services/              # Business logic layer
│   ├── book_source_service.dart  # Import/parse/save book sources
│   ├── search_service.dart       # Web scraping engine, rule parser
│   └── bookshelf_service.dart    # Bookshelf CRUD operations
└── screens/               # UI layer
    ├── home_screen.dart   # Tab navigation (Bookshelf, Sources, Settings)
    ├── search_screen.dart # Multi-source search with streaming results
    ├── chapter_list_screen.dart  # Chapter list with bookmark toggle
    └── reader_screen.dart # PageView-based reader with caching
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
3. **Read**: Chapter URL → `SearchService.getChapterContent()` → fetch HTML → parse content via rules → cache in memory

### Book Source Format

Book sources must be compatible with 阅读3.0 JSON format. Key fields:
- `bookSourceName`, `bookSourceUrl`: Identity
- `searchUrl`: URL template with `{{key}}` placeholder
- `ruleSearch`: CSS/JSON selectors for search results
- `ruleToc`: Chapter list selectors
- `ruleContent`: Content extraction selectors

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

`ReaderScreen` maintains `_contentCache` map for preloading adjacent chapters. Content is fetched on-demand and cached for the session.

## Linting

The project uses `flutter_lints` with additional rules:
- `prefer_const_constructors: true`
- `prefer_single_quotes: true`
- `avoid_print: false` (debugging output is allowed)

## Notes

- Sample book sources available at project root: `书源.json`
- Data persistence uses simple JSON files in app documents directory (not Isar database despite being listed in dependencies)
- The app targets Flutter 3.x with Material 3 design
