import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert';

class SummaryMindMapDetailScreen extends StatelessWidget {
  final String topicTitle;
  final Map<String, dynamic>? topicData;

  const SummaryMindMapDetailScreen({
    super.key,
    required this.topicTitle,
    this.topicData,
  });

  @override
  Widget build(BuildContext context) {
    final content = topicData?['content'] ?? 'Content not available.';
    final action = topicData?['action']?.toString() ?? 'summarize';
    final isMindMap = action == 'mindmap' || action == 'summary_mindmap';
    final imageBase64 = topicData?['imageBase64'] as String?;
    final imageUrl = topicData?['imageUrl'] as String? ??
        _fallbackImageUrl(content);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          topicTitle,
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
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isMindMap
                        ? Colors.purple.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMindMap ? Icons.account_tree : Icons.description,
                        size: 16,
                        color: isMindMap
                            ? Colors.purple.shade700
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isMindMap ? '🧠 Mind Map' : '📝 Summary',
                        style: GoogleFonts.poppins(
                          color: isMindMap
                              ? Colors.purple.shade700
                              : Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ─── IMAGE (always shows with proper spacing) ─────
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (imageBase64 != null || imageUrl != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImage(
                              imageBase64: imageBase64,
                              imageUrl: imageUrl,
                            ),
                          ),
                        );
                      }
                    },
                    child: Hero(
                      tag: 'summary_image_${topicData?['id'] ?? ''}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: _buildImageWidget(imageBase64, imageUrl, content),
                      ),
                    ),
                  ),
                ),

                // ─── CONTENT ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topicTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        content,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[800],
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Upgrade Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.teal, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock, color: Colors.teal, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        "Want more detailed summaries and mind maps?",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Upgrade to Premium to unlock full access to advanced visual mind maps and AI-generated summaries!",
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
                              content: Text("Redirecting to Premium..."),
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(
    String? imageBase64,
    String? imageUrl,
    String content,
  ) {
    if (imageBase64 != null) {
      try {
        return Image.memory(
          base64Decode(imageBase64),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage(content);
          },
        );
      } catch (e) {
        return _buildPlaceholderImage(content);
      }
    }

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.shade100,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage(content);
        },
      );
    }

    return _buildPlaceholderImage(content);
  }

  static String? _fallbackImageUrl(String content) {
    if (content.trim().isEmpty) return null;
    final snippet = content.length > 200 ? content.substring(0, 200) : content;
    final prompt =
        'educational infographic mind map illustration $snippet';
    return 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(prompt)}'
        '?width=1024&height=576&nologo=true&enhance=true';
  }

  Widget _buildPlaceholderImage(String content) {
    final fallback = _fallbackImageUrl(content);
    if (fallback != null) {
      return Image.network(
        fallback,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.shade100,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildNoImagePlaceholder();
        },
      );
    }

    return _buildNoImagePlaceholder();
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.grey.shade200,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Loading visual...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full Screen Image Viewer ─────────────────────────────────
class FullScreenImage extends StatelessWidget {
  final String? imageBase64;
  final String? imageUrl;

  const FullScreenImage({super.key, this.imageBase64, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Hero(
            tag: 'summary_image_full',
            child: imageBase64 != null
                ? Image.memory(
                    base64Decode(imageBase64!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFullScreenPlaceholder();
                    },
                  )
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFullScreenPlaceholder();
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Image not available',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
