#!/bin/bash

# Configuration
FLUTTER_VERSION="stable"
FLUTTER_CHANNEL="stable"

# 1. Download Flutter SDK
echo "--- Downloading Flutter SDK ($FLUTTER_VERSION) ---"
git clone https://github.com/flutter/flutter.git -b $FLUTTER_VERSION --depth 1

# 2. Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Pre-cache and Doctor (optional but helpful)
flutter precache --web
flutter doctor

# 4. Build the Web App
echo "--- Building Flutter Web App ---"
# Note: The API_URL is now set as the default in api_service.dart, 
# but you can still override it here if needed.
flutter build web --release

# 5. Move output to a folder Vercel can find (optional, usually build/web is used)
# Vercel's default output is 'public' or whatever you set in the dashboard.
# Since we set the Output Directory to 'build/web' in the UI, we don't need to move it.

echo "--- Build Complete ---"
