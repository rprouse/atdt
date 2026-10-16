import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reader_font.dart';

/// Adds each bundled font's licence to the "View licenses" page.
///
/// The texts are the licence files shipped with the fonts, loaded lazily
/// when the page opens.
void registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final font in readerFonts) {
      final text = await rootBundle.loadString(font.credit.licenceAsset);
      yield LicenseEntryWithLineBreaks(['${font.displayName} (font)'], text);
    }
  });
}

void showAtdtAbout(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  showAboutDialog(
    context: context,
    applicationName: 'ATDT',
    applicationLegalese:
        'Source code under the MIT License. Phrack and all Phrack content '
        'belong to their authors and the Phrack staff; text is downloaded '
        'from phrack.org. ATDT is not affiliated with Phrack.',
    children: [
      const SizedBox(height: 16),
      Text('Fonts', style: textTheme.titleSmall),
      for (final font in readerFonts)
        Padding(
          key: ValueKey('credit-${font.id}'),
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${font.credit.attribution} Licence: ${font.credit.licenceName}.',
            style: textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 8),
      Text(
        'Full licence texts are under "View licenses".',
        style: textTheme.bodySmall,
      ),
    ],
  );
}
