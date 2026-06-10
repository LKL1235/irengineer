#!/usr/bin/env bash
# Cursor Cloud Agent: idempotent dependency install for iREngineer Linux builds & UI tests.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Flutter Linux desktop build chain (clang + GTK + tray_manager AppIndicator).
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    ninja-build \
    cmake \
    clang \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    g++ \
    build-essential \
    libstdc++-13-dev \
    libayatana-appindicator3-dev
fi

export PATH="/home/ubuntu/flutter/bin:${PATH}"

# clang++ needs explicit paths to link/find libstdc++ on Ubuntu Cloud images.
export LIBRARY_PATH="/usr/lib/gcc/x86_64-linux-gnu/13:${LIBRARY_PATH:-}"
export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/x86_64-linux-gnu/c++/13"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}/irengineer"
flutter pub get
