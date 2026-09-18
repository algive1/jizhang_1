import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef InstallationDirectoryResolver = Future<Directory> Function();

class InstallationAgeRepository {
  InstallationAgeRepository({
    InstallationDirectoryResolver? applicationSupportDirectory,
    DateTime Function()? clock,
  })  : _applicationSupportDirectory =
            applicationSupportDirectory ?? getApplicationSupportDirectory,
        _clock = clock ?? DateTime.now;

  static const fileName = '.installation_created_at_v1';

  final InstallationDirectoryResolver _applicationSupportDirectory;
  final DateTime Function() _clock;

  Future<DateTime> createdAt() async {
    final now = _clock();
    final directory = await _applicationSupportDirectory();
    await directory.create(recursive: true);
    final marker = File(p.join(directory.path, fileName));

    if (await marker.exists()) {
      final raw = (await marker.readAsString()).trim();
      final parsed = DateTime.tryParse(raw);
      if (parsed != null && !parsed.isAfter(now)) {
        return parsed;
      }
    }

    await marker.writeAsString(now.toUtc().toIso8601String(), flush: true);
    return now;
  }
}
