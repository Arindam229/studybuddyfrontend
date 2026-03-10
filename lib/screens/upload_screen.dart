import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studybuddy_client/services/api_service.dart';
import 'package:studybuddy_client/screens/history_screen.dart';
import 'package:studybuddy_client/screens/result_screen.dart';

import 'package:studybuddy_client/widgets/custom_footer.dart';
import 'package:studybuddy_client/widgets/custom_navbar.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _handleUpload(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() => _isUploading = true);

      final response = await ApiService.uploadImage(image);

      if (response['success'] && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(data: response['data']),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomNavbar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 600),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hero Section
                      Text(
                        'Process your study notes',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(fontSize: 36, letterSpacing: -1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await ApiService.clearHistory();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Chat history cleared!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Clear Chat History',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('View All My History'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Upload or capture an image of your study materials to get an AI-powered explanation and summary.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Upload Card
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(
                            MediaQuery.of(context).size.width < 600
                                ? 24.0
                                : 48.0,
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 32),
                              if (_isUploading)
                                const Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Analyzing your notes...'),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _handleUpload(ImageSource.camera),
                                      icon: const Icon(Icons.camera_enhance),
                                      label: const Text('Capture Notes'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(200, 56),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _handleUpload(ImageSource.gallery),
                                      icon: const Icon(Icons.photo_library),
                                      label: const Text('Upload from Gallery'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(200, 56),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              if (!_isUploading)
                                Text(
                                  'Supports JPG, PNG, and PDF (scanned)',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const CustomFooter(),
          ],
        ),
      ),
    );
  }
}
