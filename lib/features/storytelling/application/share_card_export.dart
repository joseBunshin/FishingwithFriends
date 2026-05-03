import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fishing_with_friends/features/catches/data/catches_repository_provider.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/storytelling/presentation/widgets/share_card.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
    final hasPhoto = catch_.photoPaths.isNotEmpty;
    final photoUrl = await _resolvePhotoUrl(catch_);
    // Pre-warm the image cache so the offscreen render doesn't race the
    // network. Without this, `CachedNetworkImage` shows its placeholder
    // and we capture a blank navy panel.
    final photoBytes = photoUrl == null ? null : await _prefetch(photoUrl);

    // Decode bytes synchronously into a ui.Image before building the
    // offscreen tree. Without this step Image.memory races flushPaint
    // (the symptom that produced two prior bug-batch attempts at this
    // bug — the navy panel ships every time on first install).
    final photoImage = photoBytes == null ? null : await decodeImage(photoBytes);

    // Surface a SnackBar when the catch has a photo but it didn't make
    // it into the share card. Don't block the share — let the user
    // ship the card with the navy fallback if they want — but tell
    // them why so they're not confused by "where's my fish?"
    if (hasPhoto && photoImage == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't load the photo for this share card. Sharing without it.",
          ),
        ),
      );
    }

    // photoUrl is intentionally null when we have a decoded image — the
    // offscreen tree must NOT fall through to CachedNetworkImage, which
    // would re-introduce the race the decode path is meant to eliminate.
    final bytes = await _capture(
      catch_,
      photoImage == null ? photoUrl : null,
      photoImage,
    );
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
    } on Exception catch (e) {
      debugPrint(
        'share-card: signed URL resolution failed for catch '
        '${catch_.id}: $e',
      );
      return null;
    }
  }

  /// Decode raw photo bytes into a `ui.Image` so `RawImage` can paint
  /// synchronously inside the offscreen capture pipeline. Returns null
  /// for any failure mode — the caller surfaces a SnackBar fallback.
  ///
  /// Falsification guards (built in deliberately so a future "still
  /// shipping navy" report has the data needed to skip diagnostic
  /// guesswork):
  ///
  /// 1. **HEIC magic-byte detection.** iOS Photos library returns HEIC
  ///    bytes for many photos and Flutter's codec cannot decode HEIC.
  ///    Prior to this batch every fix tried to handle the bytes correctly
  ///    but assumed they were always JPEG/PNG. Detecting HEIC up front
  ///    fails fast and surfaces in logs as a distinct cause.
  /// 2. **Downsample large sources.** `targetWidth` tells the codec to
  ///    downsample in place, avoiding GPU texture-limit silent-no-op
  ///    rendering on older iOS devices when source photos exceed 4096
  ///    pixels on either axis.
  ///
  /// `@visibleForTesting` so the share-card-export test suite can verify
  /// each guard independently with fixture bytes.
  @visibleForTesting
  Future<ui.Image?> decodeImage(Uint8List bytes) async {
    if (bytes.isEmpty) {
      debugPrint('share-card decode: empty bytes; cannot decode');
      return null;
    }
    // HEIC files use the ISO BMFF container with brand 'heic', 'heix',
    // 'hevc', or 'mif1' at bytes 8-11 (after the 4-byte size + 'ftyp'
    // FourCC at bytes 4-7). If we see any of those, the codec will
    // fail — fail fast with a typed log line instead.
    if (bytes.length >= 12) {
      final ftyp = String.fromCharCodes(bytes.sublist(4, 8));
      final brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (ftyp == 'ftyp' &&
          (brand == 'heic' ||
              brand == 'heix' ||
              brand == 'hevc' ||
              brand == 'mif1')) {
        debugPrint(
          'share-card decode: HEIC bytes detected '
          '(brand=$brand, len=${bytes.length}); flutter codec cannot decode',
        );
        return null;
      }
    }
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1080,
      );
      final frame = await codec.getNextFrame();
      debugPrint(
        'share-card decode: ok '
        '(sourceLen=${bytes.length}, '
        'decoded=${frame.image.width}x${frame.image.height})',
      );
      return frame.image;
    } on Object catch (e) {
      debugPrint('share-card decode: failed (${e.runtimeType}): $e');
      return null;
    }
  }

  Future<Uint8List?> _prefetch(String url) async {
    // Direct http.get with an explicit timeout. The previous
    // NetworkAssetBundle implementation swallowed errors silently and
    // was the root cause of the share card's "always navy" symptom on
    // first TestFlight install — when prefetch failed, the offscreen
    // capture raced against the async CachedNetworkImage and won every
    // time. Logging failures via debugPrint keeps the next breakage
    // visible instead of silent.
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint(
          'share-card prefetch returned ${res.statusCode} for $url',
        );
        return null;
      }
      return res.bodyBytes;
    } on Object catch (e) {
      debugPrint('share-card prefetch failed for $url: $e');
      return null;
    }
  }

  Future<Uint8List?> _capture(
    Catch catch_,
    String? photoUrl,
    ui.Image? photoImage,
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
          photoImage: photoImage,
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
