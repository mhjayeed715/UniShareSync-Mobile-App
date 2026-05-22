import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class ImageCompression {
  static Future<Uint8List?> toWebp(
    Uint8List bytes, {
    int maxDimension = 1600,
    int quality = 80,
  }) async {
    final image = html.ImageElement();
    final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));

    try {
      final loadFuture = image.onLoad.first;
      image.src = url;
      await loadFuture;

      final sourceWidth = image.width ?? 0;
      final sourceHeight = image.height ?? 0;
      if (sourceWidth <= 0 || sourceHeight <= 0) {
        return bytes;
      }

      final scale = (sourceWidth > sourceHeight)
          ? (sourceWidth > maxDimension ? maxDimension / sourceWidth : 1.0)
          : (sourceHeight > maxDimension ? maxDimension / sourceHeight : 1.0);
      final targetWidth = (sourceWidth * scale).round().clamp(1, sourceWidth);
      final targetHeight = (sourceHeight * scale).round().clamp(1, sourceHeight);

      final canvas = html.CanvasElement(width: targetWidth, height: targetHeight);
      canvas.context2D.drawImageScaled(image, 0, 0, targetWidth, targetHeight);

      final dataUrl = canvas.toDataUrl('image/webp', quality / 100);
      final base64Index = dataUrl.indexOf(',');
      if (base64Index == -1) {
        return bytes;
      }

      return Uint8List.fromList(base64Decode(dataUrl.substring(base64Index + 1)));
    } catch (_) {
      return bytes;
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}