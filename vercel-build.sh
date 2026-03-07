#!/bin/bash

# Configuration
FLUTTER_VERSION="stable"
FLUTTER_CHANNEL="stable"

# Exit on error
set -e

# 1. Download Flutter SDK
echo "--- Downloading Flutter SDK ($FLUTTER_VERSION) ---"
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b $FLUTTER_VERSION --depth 1
fi

# 2. Add Flutter to PATH (Prepend to avoid system version)
export PATH="`pwd`/flutter/bin:$PATH"

# 3. Initialize and check
flutter config --enable-web
flutter doctor

# 4. Build the Web App
echo "--- Building Flutter Web App ---"
# Using equals sign for the flag and ensuring it uses the html renderer correctly.
flutter build web --release --web-renderer=html

# 5. Move output to a folder Vercel can find (optional, usually build/web is used)
# Vercel's default output is 'public' or whatever you set in the dashboard.
# Since we set the Output Directory to 'build/web' in the UI, we don't need to move it.

echo "--- Build Complete ---"
