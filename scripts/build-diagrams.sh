#!/bin/bash
# Build D2 diagrams to SVG
# Usage: ./scripts/build-diagrams.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_DIR/src/diagrams"
OUT_DIR="$PROJECT_DIR/public/diagrams"

# Ensure output directory exists
mkdir -p "$OUT_DIR"

# Check if d2 is available
if ! command -v d2 &> /dev/null; then
    echo "d2 is not installed. Install from https://d2lang.com/"
    echo "Or run: curl -fsSL https://d2lang.com/install.sh | sh"
    exit 1
fi

echo "Building D2 diagrams..."

# Process each .d2 file
for d2_file in "$SRC_DIR"/*.d2; do
    if [ -f "$d2_file" ]; then
        name=$(basename "$d2_file" .d2)

        # Light theme (theme 3 = Flagship Terrastruct, polished)
        echo "  $name (light)..."
        d2 --theme 3 --layout elk --pad 150 "$d2_file" "$OUT_DIR/$name.svg"

        # Dark theme (theme 200 = Terminal, dark background)
        echo "  $name (dark)..."
        d2 --theme 200 --layout elk --pad 150 "$d2_file" "$OUT_DIR/$name-dark.svg"
    fi
done

# Fix permissions for web serving
chmod 644 "$OUT_DIR"/*.svg

# Add accessible titles to SVG diagrams
echo "Adding accessible titles to SVG diagrams..."
node "$SCRIPT_DIR/add-svg-titles.js"

echo "Done! Diagrams written to $OUT_DIR"
