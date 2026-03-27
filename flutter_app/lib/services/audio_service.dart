import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<bool> startRecording() async {
    final granted = await requestPermission();
    if (!granted) return false;

    final dir = await getTemporaryDirectory();
    _currentPath =
        '${dir.path}/voice_expense_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _currentPath!,
    );

    _isRecording = true;
    return true;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    await _recorder.stop();
    _isRecording = false;
    return _currentPath;
  }

  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
