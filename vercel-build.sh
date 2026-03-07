#!/bin/bash

# Configuration
FLUTTER_CHANNEL="stable"

# Exit on error
set -e

# Setup absolute paths
ROOT_DIR=$(pwd)
FLUTTER_BIN="$ROOT_DIR/flutter/bin/flutter"

# 1. Download Flutter SDK
echo "--- Downloading Flutter SDK ---"
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "Flutter directory already exists, skipping clone."
fi

# 2. Add Flutter to PATH and Check
export PATH="$ROOT_DIR/flutter/bin:$PATH"
echo "--- Flutter Version ---"
$FLUTTER_BIN --version

# 3. Initialize Web
echo "--- Ensuring Web is enabled ---"
$FLUTTER_BIN config --enable-web
$FLUTTER_BIN precache --web

# 4. Build the Web App
echo "--- Building Flutter Web App ---"
# Using the binary directly to be safe
$FLUTTER_BIN build web --release --web-renderer html

# 5. Move output to a folder Vercel can find (optional, usually build/web is used)
# Vercel's default output is 'public' or whatever you set in the dashboard.
# Since we set the Output Directory to 'build/web' in the UI, we don't need to move it.

echo "--- Build Complete ---"
