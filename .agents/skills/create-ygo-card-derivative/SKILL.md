---
name: create-ygo-card-derivative
description: Use when creating a new ygo_data derivative package (like ygo_card_mycard) in the uniygo-flutter monorepo. Triggered by requests to create a new card CDN service, card database implementation, or card resource provider.
---

# Create ygo_data Derivative Package

## Overview

Scaffolds a new derivative package under `packages/` that depends on `ygo_data` and implements `ICardService` via `service_loader`.

## Architecture Pattern

```
packages/ygo_card_<name>/
  lib/
    ygo_card_<name>.dart    # Main entry: @Service + factory or class implementing ICardService
    src/
      card_service.dart      # BaseCardService (or equivalent) implements ICardService
      ...
  analysis_options.yaml
  pubspec.yaml
```

## Workflow

### 1. Create directory structure

```bash
mkdir -p packages/ygo_card_<name>/lib/src
```

### 2. Create pubspec.yaml

```yaml
name: ygo_card_<name>
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
  ygo_data:
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

### 4. Create ICardService implementation

Path: `packages/ygo_card_<name>/lib/src/card_service.dart`

```dart
import 'package:resource_data/card_info.dart';
import 'package:resource_data/lf_table.dart';
import 'package:resource_data/ygo_data.dart';

class <Name>CardService implements ICardService {
  @override
  get envType => null;

  @override
  set envType(dynamic value) {}

  @override
  Future<Map<int, LfTable>> getAllLfTable() async {
    throw UnimplementedError();
  }

  @override
  Future<LfTable?> getLfTable(int code) async {
    throw UnimplementedError();
  }

  @override
  String getCardImageUrl(int code) {
    throw UnimplementedError();
  }

  @override
  Future<CardInfo?> getCard(int code) async {
    throw UnimplementedError();
  }

  @override
  Future<List<CardInfo>> searchCards(String keyword) async {
    throw UnimplementedError();
  }

  @override
  Future<List<CardInfo>> searchCombined({
    String? query,
    int? cardType,
    int? attribute,
    int? race,
    int maxResults = 100,
  }) async {
    throw UnimplementedError();
  }

  @override
  List<String> validateDeck(
    List<CardInfo> main,
    List<CardInfo> extra,
    List<CardInfo> side,
  ) {
    throw UnimplementedError();
  }
}
```

Reference implementation at `packages/resource_card_mycard/lib/src/card_service.dart:66` (`BaseCardService`).

### 5. Create main entry file

Path: `packages/ygo_card_<name>/lib/ygo_card_<name>.dart`

```dart
import 'package:service_loader/service_loader.dart';
import 'package:ygo_card_<name>/src/card_service.dart';

@Service(<Name>CardService)
class <Name>CardService extends _BaseCardService {
  // If constructor has no required params, use class annotation:
  // @Service(<Name>CardService)
  // class <Name>CardService implements ICardService { ... }
}

@OnServiceRegister()
onServiceRegister() {
  // Initialization logic (DB download, config loading, etc.)
}
```

If the service class needs constructor params (like `ygo_card_mycard`'s `EnvConfig`), register via factory function instead:
```dart
@Service(CardServiceClass)
CardServiceClass create<Name>CardService() =>
    CardServiceClass(config: MyConfig.production);
```

### 6. Register in workspace

Add to root `pubspec.yaml` under `workspace:`:
```yaml
  - packages/ygo_card_<name>
```

### 7. Install dependencies

```bash
dart pub get
```

## Key Interfaces (from ygo_data)

- **`ICardService`** (`packages/resource_data/lib/ygo_data.dart:7`) — abstract card resource contract:
  - `getAllLfTable()` / `getLfTable(int code)` — banlist
  - `getCardImageUrl(int code)` — CDN image URL
  - `getCard(int code)` / `searchCards(String)` / `searchCombined(...)` — card lookup
  - `validateDeck(main, extra, side)` — deck validation
- **`CardInfo`** (`packages/resource_data/lib/card_info.dart`) — card data model
- **`LfTable`** / **`LfInfo`** (`packages/resource_data/lib/lf_table.dart`) — banlist model

## Common Mistakes

- Forgetting to add the new package to the root `pubspec.yaml` workspace list
- Not implementing all `ICardService` methods — the interface requires full implementation
- Using `@Service` on a class with required constructor params without providing a factory function
- Forgetting the `@OnServiceRegister()` for init-time setup (DB preload, config loading)
