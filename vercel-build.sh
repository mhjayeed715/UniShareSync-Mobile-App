#!/bin/bash
set -e

echo "==> Preparing Flutter SDK for Vercel Build..."
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:$(pwd)/flutter/bin"

echo "==> Flutter Doctor..."
flutter doctor -v

echo "==> Building Flutter Web Release..."
flutter build web --release --no-tree-shake-icons

echo "==> Build finished successfully! Output in build/web"
