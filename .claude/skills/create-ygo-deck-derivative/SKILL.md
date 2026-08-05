---
name: create-ygo-deck-derivative
description: Use when creating a new ygo_deck derivative package (like ygo_deck_mdpro3) in the uniygo-flutter monorepo. Triggered by requests to create a new deck API client, deck square service, or deck management implementation.
---

# Create ygo_deck Derivative Package

## Overview

Scaffolds a new derivative package under `packages/` that depends on `ygo_data` and implements `IDeckService` via `service_loader`.

## Architecture Pattern

```
packages/ygo_deck_<name>/
  lib/
    ygo_deck_<name>.dart       # Main entry: @Service + class implementing IDeckService
    services/
      deck_service.dart         # IDeckService implementation
      deck_api_client.dart      # HTTP API client (optional)
  analysis_options.yaml
  pubspec.yaml
```

## Workflow

### 1. Create directory structure

```bash
mkdir -p packages/ygo_deck_<name>/lib/services
```

### 2. Create pubspec.yaml

```yaml
name: ygo_deck_<name>
version: 1.0.0
resolution: workspace
publish_to: 'none'
environment:
  sdk: ^3.12.2

dependencies:
  http: ^1.2.1
  sqflite: ^2.4.2
  sqflite_common_ffi: ^2.3.4+4
  path_provider: ^2.1.3
  path: ^1.9.0
  ygo_deck:
    path: ../ygo_data
  service_loader:
    path: ../service_loader

dev_dependencies:
  test: ^1.24.0
  flutter_lints: ^6.0.0
```

### 3. Create analysis_options.yaml

```yaml
include: package:flutter_lints/flutter.yaml
```

### 4. Create IDeckService implementation

Path: `packages/ygo_deck_<name>/lib/services/deck_service.dart`

```dart
import 'package:service_loader/service_loader.dart';
import 'package:ygo_data/ygo_deck.dart';

/// Deck service implementing IDeckService.
@Service(<Name>DeckService)
class <Name>DeckService implements IDeckService {
  // Add deck API methods here
}

@OnServiceRegister()
onServiceRegister() {
  // Initialization logic if needed
}
```

Reference implementation at `packages/ygo_deck_mdpro3/lib/services/deck_service.dart:18`.

### 5. Create main entry file

Path: `packages/ygo_deck_<name>/lib/ygo_deck_<name>.dart`

```dart
import 'package:service_loader/service_loader.dart';
import 'package:ygo_deck_<name>/services/deck_service.dart';
```

### 6. Register in workspace

Add to root `pubspec.yaml` under `workspace:`:
```yaml
  - packages/ygo_deck_<name>
```

### 7. Install dependencies

```bash
dart pub get
```

## Key Interfaces & Models (from ygo_data)

- **`IDeckService`** (`packages/ygo_data/lib/ygo_deck.dart:4`) — abstract deck service contract (extensible, currently minimal)
- **`DeckInfo`** / **`DeckCard`** (`packages/ygo_data/lib/deck_info.dart`) — deck data models
- **`MdPro3DeckInfo`** (`packages/ygo_data/lib/deck_info.dart`) — MDPro3-specific deck info
- **`DeckSummary`** (`packages/ygo_data/lib/deck_info.dart`) — deck summary for list views
- **`DeckListPage`** (`packages/ygo_data/lib/deck_list_page.dart`) — paginated deck list

## Optional: HTTP API Client

If the derivative talks to an HTTP API (like `ygo_deck_mdpro3` does), create:

Path: `packages/ygo_deck_<name>/lib/services/deck_api_client.dart`

Reference implementation at `packages/ygo_deck_mdpro3/lib/services/deck_api_client.dart`.

## Common Mistakes

- Forgetting to add the new package to the root `pubspec.yaml` workspace list
- Not importing `service_loader` for `@Service` annotation
- `IDeckService` is intentionally minimal — extend it with domain-specific methods
- Forgetting `@OnServiceRegister()` if init logic is needed
