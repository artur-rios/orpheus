import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';

/// One record's sleeve, decoded.
///
/// Keyed by the cover's own id — the hash of its bytes — rather than by a
/// track or a record, which is what makes the twelve tracks of one album, and
/// every screen showing any of them, watch a single decoded picture instead of
/// twelve copies of it.
///
/// Auto-disposed, and the image with it: a library of a thousand records
/// scrolled past would otherwise hold a thousand decoded pictures for the life
/// of the process.
class AlbumArtController extends AsyncNotifier<ui.Image?> {
  /// Creates the controller for [coverId].
  AlbumArtController(this.coverId);

  /// The picture in the cover store this sleeve is.
  final String coverId;

  @override
  Future<ui.Image?> build() async {
    final bytes = await ref.read(coverStoreProvider).read(coverId);
    if (bytes == null) return null;

    final image = await _decode(bytes);
    if (image == null) return null;

    // The one thing a decoded image needs that a plain value does not: the
    // texture is native memory, and a row scrolled off screen has to give it
    // back.
    ref.onDispose(image.dispose);

    return image;
  }

  /// The bytes as an image, or `null` when they are not one.
  ///
  /// A file whose tag holds something that is not a picture is the same answer
  /// as a file with no picture: there is nothing to draw, and an owner has
  /// nothing to do about either.
  Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      return frame.image;
    } on Object {
      return null;
    }
  }
}
