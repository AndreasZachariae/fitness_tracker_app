/// Rules for user-entered names of exercises and plans.
library;

/// Maximum length of a name after cleaning.
const maxNameLength = 60;

/// Trims and collapses inner whitespace: `"  Bank   drücken "` →
/// `"Bank drücken"`.
String cleanName(String input) => input.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Key for case-insensitive uniqueness, including umlauts
/// (`"Übung"` and `"übung"` are the same name).
String nameKey(String input) => cleanName(input).toLowerCase();

/// Whether [input] is a usable name after cleaning.
bool isValidName(String input) {
  final cleaned = cleanName(input);
  return cleaned.isNotEmpty && cleaned.length <= maxNameLength;
}

/// Key for alphabetical sorting of German names (DIN 5007-1: ä = a,
/// ö = o, ü = u, ß = ss), ignoring case.
String sortKey(String input) =>
    nameKey(input)
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ß', 'ss');

/// Compares names alphabetically (see [sortKey]); ties by exact text.
int compareNames(String a, String b) {
  final byKey = sortKey(a).compareTo(sortKey(b));
  return byKey != 0 ? byKey : a.compareTo(b);
}
