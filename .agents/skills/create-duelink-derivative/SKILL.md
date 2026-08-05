---
name: create-duelink-derivative
description: Use when creating a new duelink derivative package (like duelink_ai, duelink_websocket, duelink_socket) in the uniygo-flutter monorepo. Triggered by requests to create a new duel connection implementation, duel service variant, or dueling mode package.
---

# Create duelink Derivative Package

## Overview

Scaffolds a new derivative package under `packages/` that depends on `duelink` and registers a duel service via `service_loader`.

## Architecture Pattern

```
packages/duelink_<name>/
  lib/
    duelink_<name>.dart    # Main entry: @Service + class extending BaseDuelService
    src/
      <name>_connection.dart  # Implements DuelConnection interface
  analysis_options.yaml
  pubspec.yaml
```

The new package provides a `DuelConnection` implementation. The `BaseDuelService` from `duelink` handles all room state machine and protocol logic automatically.

## Workflow

### 1. Create directory structure

```bash
mkdir -p packages/duelink_<name>/lib/src
```

### 2. Create pubspec.yaml

```yaml
name: duelink_<name>
description: <description>
version: 0.0.1
environment:
  sdk: ^3.12.2
resolution: workspace
publish_to: 'none'

dependencies:
  flutter:
    sdk: flutter
  duelink:
    path: ../duelink
  async: ^2.11.0
  service_loader:
    path: ../service_loader

dev_dependencies:
  test: ^1.25.0
  flutter_lints: ^6.0.0
```

If the package has assets (like `duelink_ai` has scripts), add:
```yaml
flutter:
  assets:
    - assets/<dir>/
```

### 3. Create analysis_options.yaml

```yaml
include: package:flutter_lints/flutter.yaml
```

### 4. Create DuelConnection implementation

Path: `packages/duelink_<name>/lib/src/<name>_connection.dart`

```dart
import 'dart:async';
import 'package:duelink/duelink.dart';

class <Name>Connection implements DuelConnection {
  final _messageController = StreamController<YgoStocMsg>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();
  ConnectionState _state = ConnectionState.disconnected;

  @override
  Stream<YgoStocMsg> get messages => _messageController.stream;

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Future<void> connect(String address, int port) async {
    _setState(ConnectionState.connecting);
    // TODO: implement connection logic
    _setState(ConnectionState.connected);
  }

  @override
  void send(YgoCtosMsg msg) {
    // TODO: handle outgoing messages
  }

  @override
  Future<void> disconnect() async {
    // TODO: cleanup
    _setState(ConnectionState.disconnected);
  }

  void _setState(ConnectionState s) {
    _state = s;
    _stateController.add(s);
  }
}
```

Reference implementations at:
- `packages/duelink_ai/lib/src/ai_connection.dart` — local OCGCore engine
- `packages/duelink_websocket/lib/src/websocket_connection.dart` — WebSocket transport

### 5. Create main entry file

Path: `packages/duelink_<name>/lib/duelink_<name>.dart`

```dart
library duelink_<name>;

export 'src/<name>_connection.dart';

import 'package:duelink/duelink.dart';
import 'package:service_loader/service_loader.dart';

import 'duelink_<name>.dart';

@Service(<Name>DuelService)
class <Name>DuelService extends BaseDuelService {
  <Name>DuelService({DuelConnection? connection})
    : super(connection ?? <Name>Connection());
}

@OnServiceRegister()
onServiceRegister() {
  print("onServiceRegister");
}
```

### 6. Register in workspace

Add to root `pubspec.yaml` under `workspace:`:
```yaml
  - packages/duelink_<name>
```

### 7. Install dependencies

```bash
cd packages/duelink_<name> && dart pub get
```

Or from root:
```bash
dart pub get
```

## Key Interfaces (from duelink)

- **`IDuelService`** (`packages/duelink/lib/duelink.dart:157`) — public duel service contract
- **`BaseDuelService`** (`packages/duelink/lib/src/base_duel_service.dart`) — shared implementation with room state machine
- **`DuelConnection`** (`packages/duelink/lib/duelink.dart:244`) — transport layer abstraction to implement
- **`ConnectionState`** — `disconnected`, `connecting`, `connected`, `error`

## Common Mistakes

- Forgetting to add the new package to the root `pubspec.yaml` workspace list
- Not extending `BaseDuelService` — all protocol/state logic lives there
- Not exporting the connection class from the library file
- Using wrong import prefix — always `package:duelink/duelink.dart`
