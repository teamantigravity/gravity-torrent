import 'dart:io';

import 'package:external_path/external_path.dart';

import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/session.dart';

initDefaultDownloadDir(Engine engine) async {
  final session = await engine.fetchSession();
  String? downloadDir;
  try {
    downloadDir = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DOWNLOAD,
    );
  } catch (_) {}
  if (downloadDir == null || downloadDir.isEmpty) return;
  await Directory(downloadDir).create(recursive: true);

  // Default download directory set by transmission is not correct.
  // See tr_getDefaultDownloadDir() in platform.cc
  if (session.downloadDir != downloadDir) {
    final sessionUpdate = SessionBase(downloadDir: downloadDir);
    await session.update(sessionUpdate);
  }
}
