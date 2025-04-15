import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:curio_campus/utils/app_theme.dart';

class VoiceRecorder extends StatefulWidget {
  final Function(String audioBase64, int duration) onStop;
  final Function() onCancel;

  const VoiceRecorder({
    Key? key,
    required this.onStop,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String _recordingPath = '';
  Timer? _timer;
  int _recordingDuration = 0;
  bool _isProcessing = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Request microphone permission explicitly
    final status = await Permission.microphone.request();
    setState(() {
      _hasPermission = status.isGranted;
    });

    if (!_hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Microphone permission is required to record audio'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      await _checkPermissions();
      if (!_hasPermission) return;
    }

    try {
      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Configure audio recorder - fixed parameter issues
      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start timer to track recording duration
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    setState(() {
      _isProcessing = true;
    });

    try {
      // Stop recording
      await _audioRecorder.stop();

      // Read file as bytes
      final file = File(_recordingPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final base64Audio = base64Encode(bytes);

        // Call the callback with the base64 encoded audio
        widget.onStop(base64Audio, _recordingDuration);

        // Clean up
        await file.delete();
      } else {
        throw Exception('Recording file not found');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process recording: $e')),
      );
      widget.onCancel();
    } finally {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });
    }
  }

  void _cancelRecording() async {
    _timer?.cancel();

    try {
      await _audioRecorder.stop();

      // Delete the recording file if it exists
      final file = File(_recordingPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    } finally {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });
      widget.onCancel();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isRecording ? 'Recording...' : 'Voice Message',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isRecording) ...[
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: null, // Indeterminate
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!_isRecording && !_isProcessing)
                ElevatedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic),
                  label: const Text('Start Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                )
              else if (_isProcessing)
                const CircularProgressIndicator()
              else ...[
                  IconButton(
                    onPressed: _cancelRecording,
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 32),
                  ),
                  IconButton(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop_circle, color: Colors.green, size: 32),
                  ),
                ],
            ],
          ),
        ],
      ),
    );
  }
}
