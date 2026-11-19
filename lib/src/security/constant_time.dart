/// Compares strings without returning early for a mismatching character.
bool constantTimeEquals(String first, String second) {
  var difference = first.length ^ second.length;
  final length = first.length > second.length ? first.length : second.length;
  for (var index = 0; index < length; index++) {
    final firstCode = index < first.length ? first.codeUnitAt(index) : 0;
    final secondCode = index < second.length ? second.codeUnitAt(index) : 0;
    difference |= firstCode ^ secondCode;
  }
  return difference == 0;
}
