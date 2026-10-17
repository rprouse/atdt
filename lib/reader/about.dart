import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'reader_font.dart';

/// Adds each bundled font's licence to the "View licenses" page.
///
/// The texts are the licence files shipped with the fonts (named in the
/// manifest), loaded lazily when the page opens.
void registerFontLicences(FontRegistry registry, AssetBundle bundle) {
  LicenseRegistry.addLicense(() async* {
    for (final font in registry.fonts) {
      final text = await bundle.loadString(FontRegistry.licencePath(font));
      yield LicenseEntryWithLineBreaks(['${font.displayName} (font)'], text);
    }
  });
}

const phrackCredit =
    'Phrack and all Phrack content belong to their authors and the Phrack '
    'staff; text is downloaded from phrack.org. ATDT is not affiliated with '
    'Phrack.';

void showAtdtAbout(BuildContext context, FontRegistry registry) {
  final textTheme = Theme.of(context).textTheme;
  showAboutDialog(
    context: context,
    applicationName: 'ATDT',
    applicationLegalese: 'Source code under the MIT License. $phrackCredit',
    children: [
      const SizedBox(height: 16),
      Text('Fonts', style: textTheme.titleSmall),
      for (final font in registry.fonts)
        Padding(
          key: ValueKey('credit-${font.id}'),
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${font.spec.attribution} Licence: ${font.spec.licenceName}.',
            style: textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 8),
      Text(
        'Full licence texts are under "View licenses" and in Credits.',
        style: textTheme.bodySmall,
      ),
    ],
  );
}
