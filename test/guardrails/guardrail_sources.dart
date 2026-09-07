import 'dart:io';

/// One banned occurrence: the file, the 1-based line, and the line's text.
class GuardrailHit {
  const GuardrailHit(this.path, this.line, this.text);

  final String path;
  final int line;
  final String text;

  @override
  String toString() => '$path:$line  ${text.trim()}';
}

/// Every `.dart` file under [dir], sorted for a stable report. Throws on a
/// missing or empty dir: a ratchet that scans nothing passes vacuously.
List<File> dartFilesUnder(String dir) {
  final Directory root = Directory(dir);
  if (!root.existsSync()) {
    throw StateError('$dir not found — run guardrail tests from the repo root');
  }
  final List<File> files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
  files.sort((File a, File b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    throw StateError('no .dart files under $dir — the scan would be vacuous');
  }
  return files;
}

/// Blanks out `//` and `/* */` comments, keeping every byte offset and every
/// newline so a hit's line number still points at the real line.
String blankComments(String source) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  bool inLine = false;
  bool inBlock = false;
  String? quote;
  bool raw = false;
  while (i < source.length) {
    final String c = source[i];
    final String next = i + 1 < source.length ? source[i + 1] : '';
    if (inLine) {
      if (c == '\n') {
        inLine = false;
        out.write(c);
      } else {
        out.write(' ');
      }
      i++;
      continue;
    }
    if (inBlock) {
      if (c == '*' && next == '/') {
        inBlock = false;
        out.write('  ');
        i += 2;
        continue;
      }
      out.write(c == '\n' ? '\n' : ' ');
      i++;
      continue;
    }
    if (quote != null) {
      out.write(c);
      if (c == r'\' && !raw) {
        if (i + 1 < source.length) {
          out.write(next);
          i += 2;
          continue;
        }
      }
      if (c == quote) {
        quote = null;
        raw = false;
      }
      i++;
      continue;
    }
    if (c == '/' && next == '/') {
      inLine = true;
      out.write('  ');
      i += 2;
      continue;
    }
    if (c == '/' && next == '*') {
      inBlock = true;
      out.write('  ');
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      raw = i > 0 && source[i - 1] == 'r';
      out.write(c);
      i++;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Every match of [pattern] in the comment-free source of every file under
/// [dir], excluding any file whose path contains one of [skipPaths].
List<GuardrailHit> scan(
  String dir,
  RegExp pattern, {
  List<String> skipPaths = const <String>[],
}) {
  final List<GuardrailHit> hits = <GuardrailHit>[];
  for (final File file in dartFilesUnder(dir)) {
    if (skipPaths.any(file.path.contains)) {
      continue;
    }
    final String source = file.readAsStringSync();
    final String code = blankComments(source);
    final List<String> lines = source.split('\n');
    for (final RegExpMatch m in pattern.allMatches(code)) {
      final int line = '\n'.allMatches(code.substring(0, m.start)).length;
      hits.add(GuardrailHit(file.path, line + 1, lines[line]));
    }
  }
  return hits;
}

/// The failure message a ratchet prints: the floor, the count, and every site.
String report(String label, int floor, List<GuardrailHit> hits) {
  final StringBuffer b = StringBuffer()
    ..writeln('$label: ${hits.length} site(s), ratchet floor $floor.')
    ..writeln(
      hits.length > floor
          ? 'This change ADDED one. Use the JEEB kit instead.'
          : 'The floor is now too high — lower it to ${hits.length}.',
    );
  for (final GuardrailHit hit in hits) {
    b.writeln('  $hit');
  }
  return b.toString();
}
