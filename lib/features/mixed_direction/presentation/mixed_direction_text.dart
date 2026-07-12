import 'package:flutter/material.dart';

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs — see docs/project-understanding/reconciliation/orphans.md
class MixedDirectionText extends StatelessWidget {

  const MixedDirectionText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  static TextDirection detectDirection(String text) {
    if (text.isEmpty) return TextDirection.ltr;
    final firstChar = text.trim().codeUnits.first;
    if (firstChar >= 0x0600 && firstChar <= 0x06FF) return TextDirection.rtl;
    if (firstChar >= 0xFE70 && firstChar <= 0xFEFF) return TextDirection.rtl;
    if (firstChar >= 0x0590 && firstChar <= 0x05FF) return TextDirection.rtl;
    return TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: detectDirection(text),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
