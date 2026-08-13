@JS()
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window.__ocgcorePluginStatus')
external JSAny? get _pluginStatus;

@JS('window.__lastOcgcoreError')
external JSAny? get _lastError;

@JS('window.__ocgcoreWasmExportKeys')
external JSAny? get _wasmExportKeys;

@JS('window.Module')
external JSObject? get _module;

String ocgcoreWebDebugStatus() {
  final pluginStatus = _pluginStatus?.dartify();
  final lastError = _lastError?.dartify();
  final exportKeys = _wasmExportKeys?.dartify();
  final module = _module;
  final modulePresent = module != null;
  var hasCreateDuel = false;
  var hasCcall = false;
  var hasMalloc = false;
  var hasHeapU8 = false;
  if (modulePresent) {
    try {
      hasCreateDuel = module['_create_duel'] != null;
      hasCcall = module['ccall'] != null;
      hasMalloc = module['_malloc'] != null;
      hasHeapU8 = module['HEAPU8'] != null;
    } catch (_) {
      hasCreateDuel = false;
      hasCcall = false;
      hasMalloc = false;
      hasHeapU8 = false;
    }
  }
  final exportKeysText = exportKeys is List ? exportKeys.join(',') : '<unset>';
  return 'pluginStatus=${pluginStatus ?? '<unset>'}; '
      'modulePresent=$modulePresent; '
      'hasCreateDuel=$hasCreateDuel; '
      'hasCcall=$hasCcall; '
      'hasMalloc=$hasMalloc; '
      'hasHeapU8=$hasHeapU8; '
      'exportKeys=$exportKeysText; '
      'lastError=${lastError ?? '<none>'}';
}
