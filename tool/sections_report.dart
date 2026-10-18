// Runs the section parser over the whole Phrack archive.
//
//   dart run tool/sections_report.dart              # summary + early check
//   dart run tool/sections_report.dart 59/3 68/4    # also print outlines
//
// Needs the tarballs cached by tool/ingest_archive.dart in
// tool/out/archive/. A developer tool that backs the Stage I Verify item
// in docs/decisions.md; it prints titles, never phile text.
import 'dart:io';

import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/sections/section_parser.dart';

/// Lines that look like headings to a naive eye: numbered or lettered
/// lists, Roman numerals, bracketed banners.
final _headingLike = RegExp(
  r'^(\d{1,2}\.\s+[A-Z]|(I|II|III|IV|V|VI|VII|VIII|IX|X)\.\s+[A-Z]|'
  r'-*\[\s*\S|\[\s*\d+\s*\]\s+\S)',
);

Future<void> main(List<String> args) async {
  final philes = <String, List<String>>{};
  for (var issue = 1; issue <= 72; issue++) {
    final tgz = File('tool/out/archive/phrack$issue.tar.gz');
    if (!tgz.existsSync()) continue;
    for (final p in importIssueArchive(issue, tgz.readAsBytesSync()).philes) {
      philes['$issue/${p.number}'] = p.text.lines;
    }
  }

  final withSections = <String, List<Section>>{};
  for (final MapEntry(:key, :value) in philes.entries) {
    final sections = parseSections(value);
    if (sections.isNotEmpty) withSections[key] = sections;
  }
  final issues = {
    for (final k in withSections.keys) int.parse(k.split('/')[0]),
  };
  final total = withSections.values.fold(0, (n, s) => n + s.length);
  stdout
    ..writeln(
      '${withSections.length} of ${philes.length} philes have sections '
      '($total headings); issues ${issues.reduce((a, b) => a < b ? a : b)}'
      '-${issues.reduce((a, b) => a > b ? a : b)}',
    )
    ..writeln(
      'philes per issue: ${[for (final i in issues.toList()..sort()) '$i:${withSections.keys.where((k) => k.startsWith('$i/')).length}'].join(' ')}',
    );

  // A heading listed twice may be a contents entry that slipped through.
  stdout.writeln('\nrepeated headings (compilations repeat legitimately):');
  for (final MapEntry(:key, :value) in withSections.entries) {
    final seen = <String>{};
    final repeated = {
      for (final s in value)
        if (!seen.add('${s.number} ${s.title}')) '${s.number} ${s.title}',
    };
    if (repeated.isNotEmpty) stdout.writeln('  $key: ${repeated.join('; ')}');
  }

  // Numbered-looking headings whose outline the parser rejected.
  final numbered = RegExp(r'^[-|][-=|]*\[\s*(\d|0x|Appendix)');
  stdout.writeln('\nrejected (2+ numbered-looking lines, no outline):');
  for (final MapEntry(:key, :value) in philes.entries) {
    if (withSections.containsKey(key)) continue;
    final count = value.where(numbered.hasMatch).length;
    if (count >= 2) stdout.writeln('  $key: $count lines');
  }

  // Spec Stage I: no false positives on twenty early-era philes. Chosen
  // from issues 1-40, those with the most heading-like lines, so the check
  // has something to be fooled by.
  final early = [
    for (final MapEntry(:key, :value) in philes.entries)
      if (int.parse(key.split('/')[0]) <= 40)
        (key, value.where(_headingLike.hasMatch).length),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  stdout.writeln('\nearly-era check (heading-like lines -> sections found):');
  var falsePositives = 0;
  for (final (key, count) in early.take(20)) {
    final found = parseSections(philes[key]!).length;
    if (found > 0) falsePositives++;
    stdout.writeln('  $key: $count heading-like lines -> $found sections');
  }
  stdout.writeln('  false positives: $falsePositives of 20');

  for (final key in args) {
    stdout.writeln('\n== $key');
    for (final s in parseSections(philes[key] ?? const [])) {
      stdout.writeln(
        '  ${s.line.toString().padLeft(5)}  ${'  ' * s.level}${s.number}  '
        '${s.title}',
      );
    }
  }
}
