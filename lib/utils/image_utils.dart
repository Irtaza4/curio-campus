import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageUtils {
  // Safely decode base64 string
  static Uint8List? safelyDecodeBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return null;
    }

    try {
      // Remove any potential data URL prefix
      String sanitizedString = base64String;
      if (base64String.contains(',')) {
        sanitizedString = base64String.split(',').last;
      }

      // Try to decode
      return base64Decode(sanitizedString);
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return null;
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

  // Safely load a base64 image with fallback
  static Widget loadBase64Image({
    required String? base64String,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    bool isCircular = false,
  }) {
    if (base64String == null || base64String.isEmpty) {
      return placeholder ?? Container(width: width, height: height);
    }

    try {
      final imageData = safelyDecodeBase64(base64String);

      if (imageData == null) {
        return placeholder ?? Container(width: width, height: height);
      }

      final imageWidget = Image.memory(
        imageData,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return placeholder ?? Container(width: width, height: height);
        },
      );

      if (isCircular) {
        return ClipOval(child: imageWidget);
      }

      return imageWidget;
    } catch (e) {
      debugPrint('Error loading base64 image: $e');
      return placeholder ?? Container(width: width, height: height);
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
}
