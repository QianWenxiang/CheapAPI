#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Parse arguments ---
NO_CACHE=""
SKIP_FRONTEND=""

for arg in "$@"; do
  case "$arg" in
    --no-cache)     NO_CACHE="--no-cache" ;;
    --skip-frontend) SKIP_FRONTEND="1" ;;
    -h|--help)
      echo "Usage: build.sh [--no-cache] [--skip-frontend]"
      echo "  --no-cache       Docker build without cache"
      echo "  --skip-frontend  Skip frontend build (use existing dist/)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# --- Read VERSION ---
VERSION="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' | sed 's/^v//')"
if [ -z "$VERSION" ]; then
  echo "ERROR: VERSION file is empty. Write a version like '1.0.0' into the VERSION file." >&2
  exit 1
fi
echo "=== Building new-api v$VERSION ==="

# --- Build frontends ---
if [ -z "$SKIP_FRONTEND" ]; then
  echo ""
  echo ">>> Building default frontend (web/default)..."
  cd "$SCRIPT_DIR/web/default"
  bun install
  DISABLE_ESLINT_PLUGIN='true' VITE_REACT_APP_VERSION="$VERSION" bun run build
  if [ ! -f "$SCRIPT_DIR/web/default/dist/index.html" ]; then
    echo "ERROR: web/default/dist/index.html not found after build" >&2
    exit 1
  fi

  echo ""
  echo ">>> Building classic frontend (web/classic)..."
  cd "$SCRIPT_DIR/web/classic"
  bun install
  VITE_REACT_APP_VERSION="$VERSION" bun run build
  if [ ! -f "$SCRIPT_DIR/web/classic/dist/index.html" ]; then
    echo "ERROR: web/classic/dist/index.html not found after build" >&2
    exit 1
  fi
else
  echo ">>> Skipping frontend build (--skip-frontend)"
fi

# --- Build Docker image ---
echo ""
echo ">>> Building Docker image new-api:$VERSION..."
cd "$SCRIPT_DIR"
docker build $NO_CACHE \
  -t "new-api:$VERSION" \
  -t "new-api:latest" \
  -f "$SCRIPT_DIR/Dockerfile.local" \
  "$SCRIPT_DIR"

# --- Package ---
DIST_DIR="$SCRIPT_DIR/dist"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo ""
echo ">>> Exporting Docker image..."
docker save "new-api:$VERSION" -o "$STAGING_DIR/new-api-image.tar"

echo ">>> Packaging archive..."
cp "$SCRIPT_DIR/manage.sh" "$STAGING_DIR/manage.sh"
cp "$SCRIPT_DIR/VERSION" "$STAGING_DIR/VERSION"
chmod +x "$STAGING_DIR/manage.sh"

ARCHIVE_NAME="new-api-$VERSION.tar.gz"
mkdir -p "$DIST_DIR"
tar czf "$DIST_DIR/$ARCHIVE_NAME" -C "$STAGING_DIR" .

# --- Output ---
FILE_SIZE="$(du -h "$DIST_DIR/$ARCHIVE_NAME" | cut -f1)"
echo ""
echo "=========================================="
echo "  Build complete!"
echo "  Archive:  $DIST_DIR/$ARCHIVE_NAME"
echo "  Size:     $FILE_SIZE"
echo ""
echo "  Deploy to server:"
echo "    scp $DIST_DIR/$ARCHIVE_NAME lance@8.154.37.125:~/"
echo ""
echo "  On server:"
echo "    mkdir -p ~/new-api && tar xzf $ARCHIVE_NAME -C ~/new-api"
echo "    cd ~/new-api && ./manage.sh deploy"
echo "=========================================="
