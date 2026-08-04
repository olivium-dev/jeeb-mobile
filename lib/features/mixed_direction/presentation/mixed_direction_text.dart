import 'package:flutter/material.dart';

import '../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
const Size _mixedDirectionTextLineBox = Size(390, 120);

const Size _mixedDirectionTextBlockBox = Size(390, 220);

const double _mixedDirectionTextContentWidth = 342;

const double _mixedDirectionTextGutter = 24;

Widget _mixedDirectionTextHosted(
  String text, {
  TextAlign? textAlign,
  int? maxLines,
  TextOverflow? overflow,
}) =>
    Padding(
      padding: const EdgeInsets.all(_mixedDirectionTextGutter),
      child: SizedBox(
        width: _mixedDirectionTextContentWidth,
        child: Builder(
          builder: (BuildContext context) => MixedDirectionText(
            text,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
      ),
    );

@JeebPreview(
  group: 'mixed_direction',
  name: 'English (LTR)',
  size: _mixedDirectionTextLineBox,
)
Widget mixedDirectionTextEnglish() =>
    _mixedDirectionTextHosted('Pickup from Spinneys, Hamra');

@JeebPreview(
  group: 'mixed_direction',
  name: 'Arabic (RTL)',
  size: _mixedDirectionTextBlockBox,
  matrix: true,
)
Widget mixedDirectionTextArabic() =>
    _mixedDirectionTextHosted('توصيل من محل الحلويات في الأشرفية');

@JeebPreview(
  group: 'mixed_direction',
  name: 'Arabic name in an English frame',
  size: _mixedDirectionTextLineBox,
)
Widget mixedDirectionTextArabicNameInEnglish() => _mixedDirectionTextHosted(
      'Rate محمد الحلبي',
      textAlign: TextAlign.center,
    );

@JeebPreview(
  group: 'mixed_direction',
  name: 'Leading digit · LTR misfire',
  size: _mixedDirectionTextBlockBox,
  matrix: true,
)
Widget mixedDirectionTextLeadingDigit() =>
    _mixedDirectionTextHosted('2 boxes - توصيل سريع');

@JeebPreview(
  group: 'mixed_direction',
  name: 'Long Arabic note · clamped to 2 lines',
  size: _mixedDirectionTextBlockBox,
)
Widget mixedDirectionTextLongArabicNote() => _mixedDirectionTextHosted(
      'الرجاء التوصيل إلى مبنى الأمين، الطابق الرابع، شارع الحمرا، بيروت، '
      'والاتصال بي قبل الوصول بعشر دقائق',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

@JeebPreview(
  group: 'mixed_direction',
  name: 'Leading whitespace (crash boundary)',
  size: _mixedDirectionTextLineBox,
)
Widget mixedDirectionTextLeadingWhitespace() =>
    _mixedDirectionTextHosted('  توصيل من الأشرفية');
