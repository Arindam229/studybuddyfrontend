#!/bin/bash

# Configuration
FLUTTER_CHANNEL="stable"

# Exit on error
set -e

# Setup absolute paths
ROOT_DIR=$(pwd)
export PATH="$ROOT_DIR/flutter/bin:$PATH"
FLUTTER_BIN="$ROOT_DIR/flutter/bin/flutter"

echo "--- Debugging Env ---"
echo "Current Path: $PATH"
echo "Which Flutter: $(which flutter)"

# 1. Download/Verify Flutter SDK
echo "--- Ensuring Flutter SDK ---"
if [ ! -d "flutter/.git" ]; then
  echo "Flutter directory is missing or invalid. Cleaning and cloning..."
  rm -rf flutter
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# 2. Check Version
echo "--- Flutter Version ---"
$FLUTTER_BIN --version

# 3. Handle Environment Variables (Vercel)
echo "--- Injecting Environment Variables ---"
if [ -f ".env.server" ]; then
  echo ".env.server found. Prioritizing it for build..."
  cp .env.server .env
  echo "Successfully copied .env.server to .env."
elif [ -n "$API_URL" ]; then
  echo "Generating .env from Vercel API_URL secret..."
  echo "API_URL=$API_URL" > .env
  echo "Successfully generated .env."
else
  echo "WARNING: Neither .env.server nor API_URL secret found. Build might use defaults."
fi

# 4. Initialize Web
echo "--- Initializing Web ---"
$FLUTTER_BIN config --enable-web
$FLUTTER_BIN precache --web

# 4. Build the Web App
echo "--- Building Flutter Web App ---"
# Removing the flag temporarily to identify if it's the root cause of the usage error
$FLUTTER_BIN build web --release

# 5. Move output to a folder Vercel can find (optional, usually build/web is used)
# Vercel's default output is 'public' or whatever you set in the dashboard.
# Since we set the Output Directory to 'build/web' in the UI, we don't need to move it.

echo "--- Build Complete ---"
ls -R build/web
