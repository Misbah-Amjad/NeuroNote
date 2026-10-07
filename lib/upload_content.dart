import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:neuronote/ai_chat.dart';
import 'document_text_extractor.dart';

class UploadContentScreen extends StatefulWidget {
  const UploadContentScreen({super.key});

  @override
  State<UploadContentScreen> createState() => _UploadContentScreenState();
}

class _UploadContentScreenState extends State<UploadContentScreen> {
  PlatformFile? pickedFile;
  String? selectedFileName;
  String? fileContent;

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'md'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      String? content;
      if (file.bytes != null) {
        final extracted = await DocumentTextExtractor.extract(
          file.name,
          file.bytes!,
        );
        if (DocumentTextExtractor.isUsableContent(extracted)) {
          content = extracted;
        }
      }

      setState(() {
        pickedFile = file;
        selectedFileName = file.name;
        fileContent = content ??
            'Could not extract readable text from "${file.name}". '
                'Try a text-based PDF or TXT file.';
      });

      _showSnackBar('📄 "${file.name}" selected', isSuccess: true);
    }
  }

  void _navigateToAIChatWithFile() {
    if (pickedFile == null) {
      _showSnackBar('Please pick a file first', isSuccess: false);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIChatScreen(
          uploadedFileName: selectedFileName,
          uploadedFileContent: fileContent,
          initialAction: 'show_modal',
          initialContent: '',
          returnToUploadOnBack: true,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.teal : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.teal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Upload Content",
          style: GoogleFonts.poppins(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: Lottie.asset(
              'assets/animations/Sparkles Animation.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pickedFile == null
                      ? Text(
                          "No file selected yet.",
                          style: GoogleFonts.poppins(
                            color: Colors.teal,
                            fontSize: 16,
                          ),
                        )
                      : Text(
                          "Selected: ${pickedFile!.name}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      "Pick a File",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (pickedFile != null)
                    ElevatedButton.icon(
                      onPressed: _navigateToAIChatWithFile,
                      icon: const Icon(Icons.bolt),
                      label: Text(
                        "Generate from File",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
