/* import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class AudioNotePlayerScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String audioPath; // Placeholder (in real app you'd load it)

  const AudioNotePlayerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.audioPath,
  });

  @override
  State<AudioNotePlayerScreen> createState() => _AudioNotePlayerScreenState();
}

class _AudioNotePlayerScreenState extends State<AudioNotePlayerScreen> {
  bool isPlaying = false;
  double progress = 0.3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          /// Lottie background
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),

          /// Foreground player UI
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.audiotrack, color: Colors.white, size: 70),
                ),
                const SizedBox(height: 30),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                Slider(
                  value: progress,
                  onChanged: (value) {
                    setState(() => progress = value);
                  },
                  activeColor: Colors.teal,
                  inactiveColor: Colors.teal.withOpacity(0.2),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "1:25",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                    Text(
                      "3:45",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.replay_10,
                        color: Colors.teal,
                        size: 30,
                      ),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 30),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => isPlaying = !isPlaying);
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.all(20),
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 30),
                    IconButton(
                      icon: const Icon(
                        Icons.forward_10,
                        color: Colors.teal,
                        size: 30,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Premium upgrade section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.teal, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock, color: Colors.teal, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        "Want more audio concepts?",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Upgrade to Premium to unlock unlimited audio notes and deeper learning insights!",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Redirecting to Premium Upgrade...",
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upgrade),
                        label: const Text("Upgrade to Premium"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 */
/* import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class AudioNotePlayerScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String audioPath; // e.g. 'assets/audio/sample.mp3'

  const AudioNotePlayerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.audioPath,
  });

  @override
  State<AudioNotePlayerScreen> createState() => _AudioNotePlayerScreenState();
}

class _AudioNotePlayerScreenState extends State<AudioNotePlayerScreen> {
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Load audio
    _setAudio();

    // Listen to events
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() => duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() => position = newPosition);
    });
  }

  Future<void> _setAudio() async {
    // Ensure the audio file is in pubspec.yaml under "assets"
    await _audioPlayer.setSource(AssetSource(widget.audioPath));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          /// 🔹 Animated Background
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),

          /// 🔹 Foreground Scrollable Player UI
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                const CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.audiotrack, color: Colors.white, size: 70),
                ),
                const SizedBox(height: 30),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),

                // Slider with real audio progress
                Slider(
                  min: 0,
                  max: duration.inSeconds.toDouble(),
                  value: position.inSeconds.toDouble().clamp(
                    0,
                    duration.inSeconds.toDouble(),
                  ),
                  onChanged: (value) async {
                    final newPosition = Duration(seconds: value.toInt());
                    await _audioPlayer.seek(newPosition);
                  },
                  activeColor: Colors.teal,
                  inactiveColor: Colors.teal.withOpacity(0.2),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(position),
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                    Text(
                      _formatTime(duration - position),
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Control Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.replay_10,
                        color: Colors.teal,
                        size: 30,
                      ),
                      onPressed: () async {
                        final newPos = position - const Duration(seconds: 10);
                        await _audioPlayer.seek(
                          newPos >= Duration.zero ? newPos : Duration.zero,
                        );
                      },
                    ),
                    const SizedBox(width: 30),
                    ElevatedButton(
                      onPressed: () async {
                        if (isPlaying) {
                          await _audioPlayer.pause();
                        } else {
                          await _audioPlayer.resume();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.all(20),
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 30),
                    IconButton(
                      icon: const Icon(
                        Icons.forward_10,
                        color: Colors.teal,
                        size: 30,
                      ),
                      onPressed: () async {
                        final newPos = position + const Duration(seconds: 10);
                        if (newPos < duration) {
                          await _audioPlayer.seek(newPos);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // 🔒 Premium Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.teal, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock, color: Colors.teal, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        "Want more audio concepts?",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Upgrade to Premium to unlock unlimited audio notes and deeper learning insights!",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Redirecting to Premium Upgrade...",
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upgrade),
                        label: const Text("Upgrade to Premium"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 */
/* import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class AudioNotePlayerScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String audioPath;

  const AudioNotePlayerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.audioPath,
  });

  @override
  State<AudioNotePlayerScreen> createState() => _AudioNotePlayerScreenState();
}

class _AudioNotePlayerScreenState extends State<AudioNotePlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();

    _initAudio();

    // Listen for audio events
    _audioPlayer.onDurationChanged.listen((d) {
      setState(() => duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      setState(() => position = p);
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => isPlaying = state == PlayerState.playing);
    });
  }

  Future<void> _initAudio() async {
    // Load local asset properly
    await _audioPlayer.setSourceAsset(widget.audioPath);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          /// Lottie Background
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),

          /// Scrollable Foreground
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.audiotrack, color: Colors.white, size: 70),
                ),
                const SizedBox(height: 25),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),

                /// Progress Slider
                Slider(
                  activeColor: Colors.teal,
                  inactiveColor: Colors.teal.withOpacity(0.3),
                  min: 0,
                  max: duration.inSeconds.toDouble(),
                  value: position.inSeconds.toDouble().clamp(
                    0,
                    duration.inSeconds.toDouble(),
                  ),
                  onChanged: (value) async {
                    final newPos = Duration(seconds: value.toInt());
                    await _audioPlayer.seek(newPos);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(position),
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                    Text(
                      _formatTime(duration - position),
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// Playback Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.replay_10,
                        size: 32,
                        color: Colors.teal,
                      ),
                      onPressed: () async {
                        final newPos = position - const Duration(seconds: 10);
                        await _audioPlayer.seek(
                          newPos >= Duration.zero ? newPos : Duration.zero,
                        );
                      },
                    ),
                    const SizedBox(width: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(20),
                      ),
                      onPressed: () async {
                        if (isPlaying) {
                          await _audioPlayer.pause();
                        } else {
                          await _audioPlayer.resume();
                        }
                      },
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 30),
                    IconButton(
                      icon: const Icon(
                        Icons.forward_10,
                        size: 32,
                        color: Colors.teal,
                      ),
                      onPressed: () async {
                        final newPos = position + const Duration(seconds: 10);
                        if (newPos < duration) {
                          await _audioPlayer.seek(newPos);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                /// Premium Upgrade Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.teal, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock, color: Colors.teal, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        "Want more audio concepts?",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Upgrade to Premium to unlock unlimited audio notes!",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Redirecting to Premium Upgrade...",
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upgrade),
                        label: const Text("Upgrade to Premium"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
 */
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'local_storage_service.dart';

class AudioNotePlayerScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? audioPath;
  final String? scriptContent;

  const AudioNotePlayerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.audioPath,
    this.scriptContent,
  });

  @override
  State<AudioNotePlayerScreen> createState() => _AudioNotePlayerScreenState();
}

class _AudioNotePlayerScreenState extends State<AudioNotePlayerScreen> {
  AudioPlayer? _audioPlayer;
  final FlutterTts _flutterTts = FlutterTts();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  List<dynamic> historyNotes = [];
  bool isLoadingHistory = true;
  bool _useTts = false;

  @override
  void initState() {
    super.initState();
    _useTts = widget.scriptContent != null &&
        widget.scriptContent!.trim().isNotEmpty;

    if (_useTts) {
      _initTts();
    } else if (widget.audioPath != null && widget.audioPath!.isNotEmpty) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onDurationChanged.listen((d) {
        if (mounted) setState(() => duration = d);
      });
      _audioPlayer!.onPositionChanged.listen((p) {
        if (mounted) setState(() => position = p);
      });
      _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => isPlaying = state == PlayerState.playing);
        }
      });
      _audioPlayer!.setSource(
        AssetSource(widget.audioPath!.replaceFirst('assets/', '')),
      );
    }

    _loadHistory();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(kIsWeb ? 0.9 : 0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.awaitSpeakCompletion(true);
      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => isPlaying = false);
      });
      _flutterTts.setErrorHandler((_) {
        if (mounted) setState(() => isPlaying = false);
      });
    } catch (_) {}
  }

  Future<void> _togglePlayback() async {
    if (_useTts) {
      if (isPlaying) {
        await _flutterTts.stop();
        setState(() => isPlaying = false);
        return;
      }
      var text = widget.scriptContent ?? '';
      text = text
          .replaceAll(RegExp(r'[📝🧠🗺️🎧📚🔹🔸▶️]'), '')
          .replaceAll(RegExp(r'Voice Note Generated', caseSensitive: false), '')
          .trim();
      if (text.length > 3000) text = '${text.substring(0, 3000)}...';
      if (text.isEmpty) return;
      setState(() => isPlaying = true);
      try {
        await _flutterTts.speak(text);
      } catch (_) {
        if (mounted) setState(() => isPlaying = false);
      }
      return;
    }

    if (_audioPlayer == null) return;
    if (isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.play(
        AssetSource(widget.audioPath!.replaceFirst('assets/', '')),
      );
    }
  }

  Future<void> _loadHistory() async {
    final data = await LocalStorageService.getAudioNotes();
    if (mounted) {
      setState(() {
        historyNotes = data;
        isLoadingHistory = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  String formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.audiotrack, color: Colors.white, size: 70),
                ),
                const SizedBox(height: 25),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.scriptContent != null &&
                    widget.scriptContent!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.scriptContent!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 25),

                // Slider (file audio only)
                if (!_useTts) ...[
                Slider(
                  activeColor: Colors.teal,
                  inactiveColor: Colors.teal.withOpacity(0.3),
                  min: 0,
                  max: duration.inSeconds.toDouble(),
                  value: position.inSeconds.toDouble().clamp(
                    0,
                    duration.inSeconds.toDouble(),
                  ),
                  onChanged: (value) async {
                    final newPos = Duration(seconds: value.toInt());
                    await _audioPlayer?.seek(newPos);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatTime(position),
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                    Text(
                      formatTime(duration - position),
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ],
                ),
                ],
                const SizedBox(height: 20),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_useTts)
                      IconButton(
                        icon: const Icon(
                          Icons.replay_10,
                          size: 32,
                          color: Colors.teal,
                        ),
                        onPressed: () async {
                          final newPos = position - const Duration(seconds: 10);
                          await _audioPlayer?.seek(
                            newPos >= Duration.zero ? newPos : Duration.zero,
                          );
                        },
                      ),
                    if (!_useTts) const SizedBox(width: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(20),
                      ),
                      onPressed: _togglePlayback,
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                    if (!_useTts) const SizedBox(width: 30),
                    if (!_useTts)
                      IconButton(
                        icon: const Icon(
                          Icons.forward_10,
                          size: 32,
                          color: Colors.teal,
                        ),
                        onPressed: () async {
                          final newPos = position + const Duration(seconds: 10);
                          if (newPos < duration) {
                            await _audioPlayer?.seek(newPos);
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your Generated History',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (isLoadingHistory)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: Colors.teal),
                    ),
                  )
                else if (historyNotes.isEmpty)
                  Text(
                    'No generated audio notes yet.',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  )
                else
                  ...historyNotes.map((note) {
                    final title = note['title']?.toString() ?? 'Audio Note';
                    final preview = note['preview']?.toString() ??
                        note['content']?.toString() ??
                        '';
                    final date = note['date']?.toString() ?? '';
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade800,
                            ),
                          ),
                          if (preview.isNotEmpty)
                            Text(
                              preview.length > 120
                                  ? '${preview.substring(0, 120)}...'
                                  : preview,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          if (date.isNotEmpty)
                            Text(
                              date,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                // Premium Upgrade Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.teal, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock, color: Colors.teal, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        "Want more audio concepts?",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Upgrade to Premium to unlock unlimited audio notes!",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Redirecting to Premium Upgrade...",
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upgrade),
                        label: const Text("Upgrade to Premium"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
