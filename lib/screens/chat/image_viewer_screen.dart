import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:curio_campus/utils/image_utils.dart';

class ImageViewerScreen extends StatefulWidget {
  final String? imageUrl;
  final String? imageBase64;
  final String title;

  const ImageViewerScreen({
    Key? key,
    this.imageUrl,
    this.imageBase64,
    required this.title,
  }) : super(key: key);

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _isSaving = false;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _downloadImage() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final base64String = widget.imageBase64 ?? widget.imageUrl;
      if (base64String == null) {
        _showErrorSnackBar('No image data available to download');
        return;
      }

      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showErrorSnackBar('Storage permission is required to save images');
        return;
      }

      // Decode base64 to bytes using our improved utility
      final imageData = ImageUtils.safelyDecodeBase64(base64String);
      if (imageData == null) {
        _showErrorSnackBar('Failed to decode image data');
        return;
      }

      // Get download directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        _showErrorSnackBar('Could not access storage directory');
        return;
      }

      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/image_$timestamp.jpg';

      // Write file
      final file = File(path);
      await file.writeAsBytes(imageData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to: $path'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to download image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        title: Text(widget.title),
        actions: [
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadImage,
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              width: 48,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: _buildImage(),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black.withOpacity(0.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_out, color: Colors.white),
              onPressed: () {
                final Matrix4 currentTransform =
                    _transformationController.value;
                final Matrix4 newTransform = currentTransform.clone()
                  ..scale(0.8, 0.8);
                _transformationController.value = newTransform;
              },
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in, color: Colors.white),
              onPressed: () {
                final Matrix4 currentTransform =
                    _transformationController.value;
                final Matrix4 newTransform = currentTransform.clone()
                  ..scale(1.2, 1.2);
                _transformationController.value = newTransform;
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _transformationController.value = Matrix4.identity();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.imageUrl != null && widget.imageUrl!.startsWith('http')) {
      // Network image
      return Image.network(
        widget.imageUrl!,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            _isLoading = false;
            return child;
          }
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: AppTheme.primaryColor,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          _hasError = true;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );
    } else if (widget.imageBase64 != null ||
        (widget.imageUrl != null && !widget.imageUrl!.startsWith('http'))) {
      // Base64 image
      final base64String = widget.imageBase64 ?? widget.imageUrl;

      try {
        // Try to decode the base64 string using our improved utility
        final bytes = ImageUtils.safelyDecodeBase64(base64String!);

        if (bytes == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Invalid image data',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error rendering image: $error');
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.broken_image,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to display image',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
        );
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to decode image data',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      }
    } else {
      // No image provided
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_not_supported,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No image available',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
  }
}
