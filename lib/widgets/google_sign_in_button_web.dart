import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web_auth;

Widget renderGoogleSignInButton({
  required VoidCallback onPressed,
  bool isDarkMode = false,
}) {
  return SizedBox(
    height: 50,
    child: web_auth.renderButton(
      configuration: web_auth.GSIButtonConfiguration(
        theme: isDarkMode
            ? web_auth.GSIButtonTheme.filledBlue
            : web_auth.GSIButtonTheme.outline,
        size: web_auth.GSIButtonSize.large,
        shape: web_auth.GSIButtonShape.rectangular,
      ),
    ),
  );
}
