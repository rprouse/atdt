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

const _appLegalese = 'Source code under the MIT License.';

/// The licences page, reached from Credits. It lists every package licence
/// plus the fonts registered by [registerFontLicences].
void showAtdtLicences(BuildContext context) => showLicensePage(
  context: context,
  applicationName: 'ATDT',
  applicationLegalese: _appLegalese,
);

/// A plain dialog rather than [showAboutDialog], which always adds a
/// "View licenses" button; that link lives in Credits instead.
void showAtdtAbout(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('ATDT'),
    content: const Text('$_appLegalese $phrackCredit'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(MaterialLocalizations.of(context).closeButtonLabel),
      ),
    ],
  ),
);
