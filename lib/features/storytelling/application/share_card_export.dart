import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds a transient ShareCard offscreen, captures it via RepaintBoundary,
/// writes the PNG to a temp file, and hands it to share_plus. Returns the
/// temp-file path on success, null on degraded paths (no photo URL available
/// is fine — share card still composes against a fallback panel).
class ShareCardExporter {
  ShareCardExporter(this._ref);
  final Ref _ref;

  Future<String?> exportAndShare({
    required BuildContext context,
    required Catch catch_,
  }) async {
    final photoUrl = await _resolvePhotoUrl(catch_);
    final bytes = await _capture(catch_, photoUrl);
    if (bytes == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/fwf-share-${catch_.id}-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);

    if (!context.mounted) return file.path;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: 'My catch on Fishing with Friends',
    );
    return file.path;
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

  Future<Uint8List?> _capture(Catch catch_, String? photoUrl) async {
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
        child: ShareCard(catch_: catch_, photoUrl: photoUrl),
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
