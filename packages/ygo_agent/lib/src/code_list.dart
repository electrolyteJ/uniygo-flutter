/// Training-era card pool, ported from `features.init_code_list`.
library;

/// Maps card codes to model card ids. Id 0 is reserved (padding/unknown);
/// the remaining ids are assigned in file order starting from 1.
///
/// The file order is part of the trained model: the Dart side must load the
/// exact `code_list.txt` bundled with the tflite checkpoint (864 codes for
/// 0546_26550M).
class CodeList {
  CodeList.parse(String content) {
    _codeToId[0] = 0;
    var i = 1;
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final code = int.parse(trimmed);
      _codeToId[code] = i;
      i++;
    }
  }

  final Map<int, int> _codeToId = {};

  /// Number of real cards (excluding the reserved id 0).
  int get size => _codeToId.length - 1;

  bool contains(int code) => _codeToId.containsKey(code);

  /// Like upstream `get_code_id`: throws for codes outside the pool.
  /// Callers integrating with the duel engine should check [contains] first
  /// and fall back to the rule-based AI.
  int idOf(int code) {
    final id = _codeToId[code];
    if (id == null) {
      throw ArgumentError.value(code, 'code', 'not in code_list');
    }
    return id;
  }
}
