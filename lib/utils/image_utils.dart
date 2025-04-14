import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageUtils {
  // Safely decode base64 string with proper padding and format handling
  static Uint8List? safelyDecodeBase64(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) {
      return null;
    }

    try {
      String sanitized = base64String
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .replaceAll(' ', '')
          .replaceAll(RegExp(r'data:image/[^;]+;base64,'), '');

      while (sanitized.length % 4 != 0) {
        sanitized += '=';
      }

      final decoded = base64Decode(sanitized);

      // Optional: Basic validation of image signature
      if (!_isLikelyImage(decoded)) {
        debugPrint('Decoded bytes are not likely a valid image');
        return null;
      }

      return decoded;
    } catch (e) {
      debugPrint('Base64 decode error: $e');
      return null;
    }
  }

  static bool _isLikelyImage(Uint8List data) {
    if (data.length < 4) return false;

    // JPEG check (starts with 0xFFD8)
    if (data[0] == 0xFF && data[1] == 0xD8) return true;

    // PNG check (starts with 0x89504E47)
    if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) return true;

    return false;
  }

  static bool isValidBase64(String? base64String) {
    return base64String != null && base64String.trim().length > 20;
  }

  static Widget getGroupPlaceholder({
    double size = 40,
    Color backgroundColor = Colors.teal,
    Color iconColor = Colors.white,
  }) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      child: Icon(
        Icons.group,
        color: iconColor,
        size: size / 2,
      ),
    );
  }

  static Widget getUserPlaceholder({
    double size = 40,
    Color backgroundColor = Colors.teal,
    String? initial,
    Color textColor = Colors.white,
  }) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      child: Text(
        initial != null && initial.isNotEmpty ? initial[0].toUpperCase() : '?',
        style: TextStyle(
          color: textColor,
          fontSize: size / 3,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Widget loadBase64Image({
    required String? base64String,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    bool isCircular = false,
    VoidCallback? onTap,
  }) {
    Widget defaultPlaceholder = placeholder ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: Icon(
            Icons.image,
            color: Colors.grey[600],
            size: width / 2,
          ),
        );

    if (!isValidBase64(base64String)) {
      return isCircular
          ? ClipOval(child: SizedBox(width: width, height: height, child: defaultPlaceholder))
          : defaultPlaceholder;
    }

    try {
      final imageData = safelyDecodeBase64(base64String);
      if (imageData == null || imageData.isEmpty) {
        return isCircular
            ? ClipOval(child: SizedBox(width: width, height: height, child: defaultPlaceholder))
            : defaultPlaceholder;
      }

      Widget imageWidget = Image.memory(
        imageData,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Image.memory failed: $error');
          return defaultPlaceholder;
        },
      );

      if (onTap != null) {
        imageWidget = GestureDetector(
          onTap: onTap,
          child: imageWidget,
        );
      }

      return isCircular ? ClipOval(child: imageWidget) : imageWidget;
    } catch (e) {
      debugPrint('Error displaying base64 image: $e');
      return isCircular
          ? ClipOval(child: SizedBox(width: width, height: height, child: defaultPlaceholder))
          : defaultPlaceholder;
    }
  }

  static Widget getPlaceholderImage({
    double width = 200,
    double height = 200,
    Color backgroundColor = Colors.grey,
    IconData icon = Icons.image_not_supported,
    Color iconColor = Colors.white,
  }) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor,
      child: Center(
        child: Icon(
          icon,
          color: iconColor,
          size: width / 4,
        ),
      ),
    );
  }

  static Future<String?> saveImageToDevice(String? base64String, String fileName) async {
    try {
      if (!isValidBase64(base64String)) return null;

      final status = await Permission.storage.request();
      if (!status.isGranted) return null;

      final imageData = safelyDecodeBase64(base64String);
      if (imageData == null) return null;

      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/$fileName-$timestamp.jpg';

      final file = File(path);
      await file.writeAsBytes(imageData);

      return path;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }
}
