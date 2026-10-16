import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'archive_database.dart';

const _backupChannel = MethodChannel('org.prouse.atdt/backup');

/// `<application support>/atdt/`, excluded from cloud backup: Android
/// through `res/xml` backup rules, iOS through a flag set here.
Future<Directory> archiveDirectory() async {
  final support = await getApplicationSupportDirectory();
  final dir = Directory('${support.path}${Platform.pathSeparator}atdt');
  await dir.create(recursive: true);
  if (Platform.isIOS) {
    try {
      await _backupChannel.invokeMethod<bool>('excludeFromBackup', {
        'path': dir.path,
      });
    } on PlatformException catch (e) {
      developer.log('backup exclusion failed: $e', name: 'atdt.storage');
    }
  }
  return dir;
}

/// The on-device archive. drift runs it on a background isolate.
ArchiveDatabase openArchiveDatabase() => ArchiveDatabase(
  driftDatabase(
    name: 'archive',
    native: const DriftNativeOptions(databaseDirectory: archiveDirectory),
  ),
);
