#!/usr/bin/env bash
set -euo pipefail

SDK_DIR="${VERCEL_FLUTTER_SDK_DIR:-${HOME}/.cache/orta-flutter-sdk}"
if [[ ! -x "${SDK_DIR}/bin/flutter" ]]; then
  metadata_file="$(mktemp)"
  install_dir="$(mktemp -d)"
  trap 'rm -f "$metadata_file"' EXIT
  curl --fail --silent --show-error --location     https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json     --output "$metadata_file"
  archive_url="$(FLUTTER_VERSION="${FLUTTER_VERSION:-}" node -e '
    const fs = require("node:fs");
    const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const version = process.env.FLUTTER_VERSION;
    const release = data.releases.find(item =>
      item.channel === "stable" && (!version || item.version === version));
    if (!release) {
      console.error(version ? "Requested Flutter stable version was not found." : "No stable Flutter SDK was found.");
      process.exit(1);
    }
    process.stdout.write(data.base_url.replace(/\/$/, "") + "/" + release.archive);
  ' "$metadata_file")"
  echo "Installing Flutter SDK from the stable channel."
  curl --fail --silent --show-error --location "$archive_url" | tar -xJ -C "$install_dir"
  mkdir -p "$(dirname "$SDK_DIR")"
  mv "$install_dir/flutter" "$SDK_DIR"
fi

export PATH="${SDK_DIR}/bin:${PATH}"
# Vercel may extract the SDK as root while Flutter runs as a different build user.
git config --global --add safe.directory "${SDK_DIR}"
: "${SUPABASE_URL:?Set SUPABASE_URL in Vercel Environment Variables}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set SUPABASE_PUBLISHABLE_KEY in Vercel Environment Variables}"
: "${ORTA_BACKEND_URL:?Set ORTA_BACKEND_URL to the public Render service URL}"

flutter config --no-analytics
flutter pub get
flutter build web --release   "--dart-define=SUPABASE_URL=${SUPABASE_URL}"   "--dart-define=SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}"   "--dart-define=ORTA_BACKEND_URL=${ORTA_BACKEND_URL%/}"
