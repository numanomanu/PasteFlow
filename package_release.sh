#!/bin/bash
set -e

echo "🔨 Building PasteFlow via build_app.sh..."
./build_app.sh

VERSION="1.0.0"
ZIP_NAME="PasteFlow-v${VERSION}.zip"

echo "📦 Packaging ${ZIP_NAME} for GitHub Releases..."
rm -f "${ZIP_NAME}"
zip -r -y "${ZIP_NAME}" PasteFlow.app

echo "✅ Created ${ZIP_NAME} ($(du -sh "${ZIP_NAME}" | cut -f1))!"
echo "🚀 Upload ${ZIP_NAME} to GitHub Releases for one-click user downloads."
