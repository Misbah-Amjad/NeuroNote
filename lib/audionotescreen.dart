import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'audionoteplayer.dart';
import 'local_storage_service.dart';
import 'navigation.dart';

class AudioNoteScreen extends StatefulWidget {
  const AudioNoteScreen({super.key});

  @override
  State<AudioNoteScreen> createState() => _AudioNoteScreenState();
}

class _AudioNoteScreenState extends State<AudioNoteScreen> {
  List<dynamic> audioNotes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    LocalStorageService.storageVersion.addListener(_onStorageChanged);
    _loadAudioNotes();
  }

  void _onStorageChanged() {
    if (mounted) _loadAudioNotes();
  }

  @override
  void dispose() {
    LocalStorageService.storageVersion.removeListener(_onStorageChanged);
    super.dispose();
  }

  Future<void> _loadAudioNotes() async {
    setState(() => isLoading = true);
    try {
      final data = await LocalStorageService.getAudioNotes();
      setState(() {
        audioNotes = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _confirmDelete(Map note) async {
    final id = note['id']?.toString();
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Delete Audio Note', style: GoogleFonts.poppins()),
        content: Text(
          'Are you sure you want to delete this audio note?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await LocalStorageService.deleteContentById('audio_note', id);
      await _loadAudioNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Audio Notes",
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
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainNavigation()),
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.teal),
            onPressed: _loadAudioNotes,
            tooltip: 'Refresh',
          ),
        ],
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
          if (isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.teal))
          else if (audioNotes.isEmpty)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.audiotrack, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No audio notes available',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Generate audio notes from the AI Chat!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: audioNotes.length,
                itemBuilder: (context, index) {
                  final note = audioNotes[index];
                  final title = note['title'] ?? 'Audio Note';
                  final content = note['content']?.toString() ?? '';
                  final preview =
                      note['preview']?.toString() ??
                      (content.length > 100
                          ? '${content.substring(0, 100)}...'
                          : content);
                  final date = note['date'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withValues(alpha: 0.15),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Container(
                        decoration: const BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview,
                            style: GoogleFonts.poppins(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (date.isNotEmpty)
                            Text(
                              '📅 $date',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 22,
                            ),
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(note),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 18),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AudioNotePlayerScreen(
                              title: title,
                              subtitle: preview,
                              scriptContent: content,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
