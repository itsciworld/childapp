import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Reader side of the JSONL queue that the native social-capture services write
/// (`SocialQueueWriter` on the Kotlin side). One instance per queue file.
///
/// The directory matches the native writer: Android's `getApplicationSupport
/// Directory()` resolves to the app's `filesDir`, and both sides use the
/// `vigil_social/` subfolder.
class SocialQueueFile {
  SocialQueueFile(this.fileName);

  /// e.g. `notif_queue.jsonl` / `a11y_queue.jsonl`.
  final String fileName;

  static const String _dirName = 'vigil_social';

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Atomically claims everything captured so far: renames the live file aside
  /// (so the native services immediately start a fresh one and never lose a
  /// write), then parses and deletes the claimed copy. Each returned map is one
  /// decoded JSON line.
  ///
  /// Also recovers a `.processing` file left behind if a previous drain was
  /// killed mid-flight, so nothing is dropped on a crash.
  Future<List<Map<String, dynamic>>> drain() async {
    final dir = await _dir();
    final live = File('${dir.path}/$fileName');
    final claimed = File('${dir.path}/$fileName.processing');
    final out = <Map<String, dynamic>>[];

    // 1. Recover a leftover claim from a crashed previous pass.
    if (await claimed.exists()) {
      await _parseInto(claimed, out);
      await _safeDelete(claimed);
    }

    // 2. Claim the current queue.
    if (await live.exists()) {
      try {
        await live.rename(claimed.path);
      } on FileSystemException catch (e) {
        debugPrint('[SocialQueueFile] claim failed for $fileName: $e');
        return out;
      }
      await _parseInto(claimed, out);
      await _safeDelete(claimed);
    }

    return out;
  }

  /// Re-appends [jsonLines] (already-encoded JSON objects) to the live queue so
  /// the next pass retries them — used when an upload fails or overflows the
  /// per-pass cap.
  Future<void> requeue(Iterable<String> jsonLines) async {
    final lines = jsonLines.toList();
    if (lines.isEmpty) return;
    final dir = await _dir();
    final live = File('${dir.path}/$fileName');
    try {
      await live.writeAsString(
        '${lines.join('\n')}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('[SocialQueueFile] requeue failed for $fileName: $e');
    }
  }

  Future<void> _parseInto(File file, List<Map<String, dynamic>> out) async {
    try {
      for (final line in await file.readAsLines()) {
        final s = line.trim();
        if (s.isEmpty) continue;
        try {
          final decoded = jsonDecode(s);
          if (decoded is Map<String, dynamic>) out.add(decoded);
        } catch (_) {
          // Skip a single corrupt line rather than dropping the whole batch.
        }
      }
    } catch (e) {
      debugPrint('[SocialQueueFile] read failed for ${file.path}: $e');
    }
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
