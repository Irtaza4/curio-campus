import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageUtils {
  // Load an image from a base64 string
  static Widget loadBase64Image({
    String? base64String,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    if (base64String == null || base64String.isEmpty) {
      return placeholder ?? const SizedBox();
    }

    try {
      // Try to decode the base64 string
      final decodedImage = safelyDecodeBase64(base64String);

      if (decodedImage != null) {
        return Image.memory(
          decodedImage,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading image: $error');
            return placeholder ?? const SizedBox();
          },
        );
      } else {
        return placeholder ?? const SizedBox();
      }
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return placeholder ?? const SizedBox();
    }
  }

  // Safely decode a base64 string to Uint8List
  static Uint8List? safelyDecodeBase64(String base64String) {
    try {
      // Clean up the base64 string
      String cleanBase64 = base64String.trim();

      // Check if the string contains data URI prefix and remove it
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',')[1];
      }

      // Remove any whitespace or newlines
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');

      // Add padding if needed
      while (cleanBase64.length % 4 != 0) {
        cleanBase64 += '=';
      }

      // Try to decode
      return base64Decode(cleanBase64);
    } catch (e) {
      debugPrint('Base64 decoding error: $e');

      // Try alternative approach for malformed base64
      try {
        // Remove any non-base64 characters
        final cleanBase64 = base64String
            .replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '')
            .replaceAll(RegExp(r'\s+'), '');

        // Ensure proper padding
        String paddedBase64 = cleanBase64;
        while (paddedBase64.length % 4 != 0) {
          paddedBase64 += '=';
        }

        return base64Decode(paddedBase64);
      } catch (e2) {
        debugPrint('Alternative base64 decoding also failed: $e2');
        return null;
      }
    }
  }

  // Get a placeholder for group avatars
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

  // Get a placeholder for user avatars
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

  // Check if a base64 string is valid and not empty
  static bool isValidBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return false;
    }

    // If it's just whitespace or very short, it's not valid
    if (base64String.trim().length < 10) {
      return false;
    }

    return true;
  }

  // Get a placeholder image
  static Widget getPlaceholderImage({
    double? width,
    double? height,
    Color color = Colors.grey,
  }) {
    return Container(
      width: width,
      height: height,
      color: color.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          Icons.image,
          color: color.withValues(alpha: 0.7),
          size: (width != null && height != null)
              ? (width < height ? width / 3 : height / 3)
              : 24,
        ),
      ),
    );
  }

  // Save image to device
  static Future<String?> saveImageToDevice(
      String? base64String, String fileName) async {
    try {
      if (!isValidBase64(base64String)) {
        return null;
      }

      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return null;
      }

      // Decode base64 to bytes
      final imageData = safelyDecodeBase64(base64String!);
      if (imageData == null) {
        return null;
      }

      // Get download directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        return null;
      }

      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/$fileName-$timestamp.jpg';

      // Write file
      final file = File(path);
      await file.writeAsBytes(imageData);

      return path;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }
}
