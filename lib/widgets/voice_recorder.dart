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

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Request microphone permission explicitly
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required to record audio'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // Start recording automatically when the recorder is shown
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _recordingPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
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

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
        });
      } else {
        await _checkPermissions();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    _timer?.cancel();

    try {
      final path = await _audioRecorder.stop();

      if (path != null) {
        // Convert audio file to base64
        final File audioFile = File(path);
        final bytes = await audioFile.readAsBytes();
        final base64Audio = base64Encode(bytes);

        widget.onStop(base64Audio, _recordingDuration);
      } else {
        widget.onCancel();
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      widget.onCancel();
    }

    setState(() {
      _isRecording = false;
      _isProcessing = false;
    });
  }

  void _cancelRecording() async {
    if (_isProcessing) return;

    _timer?.cancel();

    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }

    setState(() {
      _isRecording = false;
    });

    widget.onCancel();
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.mic,
                color: _isRecording ? Colors.red : AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _isRecording
                    ? 'Recording... ${_formatDuration(_recordingDuration)}'
                    : 'Preparing to record...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              if (_isProcessing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: _cancelRecording,
                ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.red),
                  onPressed: _stopRecording,
                ),
              ],
            ],
          ),
          if (_isRecording) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: null, // Indeterminate
              backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ],
        ],
      ),
    );
  }
}
