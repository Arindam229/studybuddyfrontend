import 'package:flutter/material.dart';

Widget renderGoogleSignInButton({
  required VoidCallback onPressed,
  bool isDarkMode = false,
}) {
  return OutlinedButton.icon(
    icon: const Icon(Icons.login),
    label: const Text('Sign in with Google'),
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
