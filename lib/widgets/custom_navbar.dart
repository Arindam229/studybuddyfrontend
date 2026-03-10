import 'package:flutter/material.dart';
import 'package:studybuddy_client/services/api_service.dart';
import 'package:studybuddy_client/services/auth_service.dart';
import 'package:studybuddy_client/services/theme_service.dart';
import 'package:studybuddy_client/utils/browser_reload.dart' as browser_reload;
import 'package:studybuddy_client/screens/history_screen.dart';
import 'package:studybuddy_client/screens/upload_screen.dart';
import 'package:studybuddy_client/screens/board_screen.dart';

class CustomNavbar extends StatelessWidget implements PreferredSizeWidget {
  const CustomNavbar({super.key});

  void _showJoinMeetDialog(BuildContext context) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Collaboration Meet'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Room Code',
            hintText: 'Enter 8-digit invite code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isNotEmpty) {
                try {
                  Navigator.pop(dialogContext); // Close dialog

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final response = await ApiService.joinGroup(
                    codeController.text,
                  );

                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BoardScreen(group: response['group']),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading if exists
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error joining: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo Section
          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const UploadScreen()),
                (route) => false,
              );
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_stories,
                    color: theme.colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'StudyBuddy',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Action Section
          ListenableBuilder(
            listenable: themeService,
            builder: (context, _) {
              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                      themeService.isDarkMode
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => themeService.toggleTheme(),
                    tooltip: 'Toggle Theme',
                  ),
                  const SizedBox(width: 8),
                  StreamBuilder(
                    stream: AuthService().authStateChanges,
                    initialData: AuthService().currentUser,
                    builder: (context, snapshot) {
                      if (AuthService().currentUser == null) {
                        return const SizedBox.shrink();
                      }

                      return Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _showJoinMeetDialog(context),
                            icon: const Icon(Icons.meeting_room, size: 18),
                            label: const Text('Join Meet'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HistoryScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.history, size: 18),
                            label: const Text('My History'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              try {
                                await ApiService.clearHistory();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('History cleared.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              'Clear Chat',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await AuthService().signOut();
                              await browser_reload.reloadPage();
                            },
                            child: const Text('Sign Out'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
