import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/share_card.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds a transient ShareCard offscreen, captures it via RepaintBoundary,
/// and shares it. On mobile this writes a PNG to the temp directory and
/// hands the path to share_plus. On web that path doesn't exist —
/// `path_provider` throws — so we share the bytes directly via
/// `XFile.fromData`, which falls through to the browser's Web Share API
/// or its download fallback.
class ShareCardExporter {
  ShareCardExporter(this._ref);
  final Ref _ref;

  Future<bool> exportAndShare({
    required BuildContext context,
    required Catch catch_,
  }) async {
    final photoUrl = await _resolvePhotoUrl(catch_);
    // Pre-warm the image cache so the offscreen render doesn't race the
    // network. Without this, `CachedNetworkImage` shows its placeholder
    // and we capture a blank navy panel.
    final photoBytes = photoUrl == null ? null : await _prefetch(photoUrl);
    final bytes = await _capture(catch_, photoUrl, photoBytes);
    if (bytes == null) return false;

    final fileName =
        'fwf-share-${catch_.id}-${DateTime.now().millisecondsSinceEpoch}.png';

    if (kIsWeb) {
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: fileName,
          ),
        ],
        subject: 'My catch on Fishing with Friends',
      );
      return true;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    if (!context.mounted) return true;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: 'My catch on Fishing with Friends',
    );
    return true;
  }

  Future<String?> _resolvePhotoUrl(Catch catch_) async {
    if (catch_.photoPaths.isEmpty) return null;
    try {
      return await _ref
          .read(photoStorageProvider)
          .signedUrl(catch_.photoPaths.first);
    } on Exception {
      return null;
    }
  }

  Future<Uint8List?> _prefetch(String url) async {
    // NetworkAssetBundle works on web AND mobile — it's just an HTTP
    // GET behind ByteData. Avoids `dart:io.File` which doesn't exist on
    // web, and avoids depending on flutter_cache_manager just for this.
    try {
      final bundle = NetworkAssetBundle(Uri.parse(url));
      final byteData = await bundle.load('');
      return byteData.buffer.asUint8List();
    } on Exception {
      return null;
    }
  }

  Future<Uint8List?> _capture(
    Catch catch_,
    String? photoUrl,
    Uint8List? photoBytes,
  ) async {
    final repaint = RenderRepaintBoundary();
    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    final root = RenderView(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      configuration: const ViewConfiguration(
        physicalConstraints: BoxConstraints.tightFor(
          width: ShareCard.width,
          height: ShareCard.height,
        ),
        logicalConstraints: BoxConstraints.tightFor(
          width: ShareCard.width,
          height: ShareCard.height,
        ),
        devicePixelRatio: 1,
      ),
    );
    pipelineOwner.rootNode = root;
    root.prepareInitialFrame();

    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaint,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ShareCard(
          catch_: catch_,
          photoUrl: photoUrl,
          photoBytes: photoBytes,
        ),
      ),
    ).attachToRenderTree(buildOwner);

    root.child = repaint;
    buildOwner
      ..buildScope(rootElement)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    final image = await repaint.toImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

final shareCardExporterProvider = Provider<ShareCardExporter>(
  ShareCardExporter.new,
);
