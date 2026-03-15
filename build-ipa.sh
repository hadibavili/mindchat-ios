#!/bin/bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
PROJECT_PATH="$PROJECT_DIR/Mind Chat.xcodeproj"
SCHEME="Mind Chat"
CONFIGURATION="Release"
EXPORT_OPTIONS="$PROJECT_DIR/ExportOptions.plist"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_DIR="$BUILD_DIR/archives"
ARCHIVE_PATH="$ARCHIVE_DIR/MindChat_${TIMESTAMP}.xcarchive"
EXPORT_DIR="$BUILD_DIR/ipa/$TIMESTAMP"

# Diawi API token — set via environment variable or .env file
DIAWI_TOKEN="${DIAWI_TOKEN:-}"
ENV_FILE="$PROJECT_DIR/.env"
if [ -z "$DIAWI_TOKEN" ] && [ -f "$ENV_FILE" ]; then
    DIAWI_TOKEN=$(grep -E '^DIAWI_TOKEN=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' || true)
fi

# ─── Parse arguments ─────────────────────────────────────────────────
OPEN_ORGANIZER=false
SKIP_UPLOAD=false
for arg in "$@"; do
    case "$arg" in
        --open-organizer) OPEN_ORGANIZER=true ;;
        --no-upload) SKIP_UPLOAD=true ;;
        -h|--help)
            echo "Usage: $0 [--open-organizer] [--no-upload]"
            echo ""
            echo "  --open-organizer   Archive only, then open Xcode Organizer"
            echo "                     (skip automatic IPA export and upload)"
            echo "  --no-upload        Build and export IPA but skip Diawi upload"
            echo ""
            echo "Environment:"
            echo "  DIAWI_TOKEN        API token from https://dashboard.diawi.com/profile/api"
            echo "                     Can also be set in .env file"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--open-organizer] [--no-upload]"
            exit 1
            ;;
    esac
done

# ─── Preflight checks ────────────────────────────────────────────────
TOTAL_STEPS=4
if [ "$SKIP_UPLOAD" = true ] || [ -z "$DIAWI_TOKEN" ]; then
    TOTAL_STEPS=3
fi

echo "============================================"
echo "  MindChat Ad Hoc Build"
echo "  $(date)"
echo "============================================"
echo ""

if [ ! -d "$PROJECT_PATH" ]; then
    echo "ERROR: Xcode project not found at $PROJECT_PATH"
    exit 1
fi

if [ "$OPEN_ORGANIZER" = false ] && [ ! -f "$EXPORT_OPTIONS" ]; then
    echo "ERROR: ExportOptions.plist not found at $EXPORT_OPTIONS"
    exit 1
fi

if [ "$SKIP_UPLOAD" = false ] && [ -z "$DIAWI_TOKEN" ]; then
    echo "WARNING: No DIAWI_TOKEN found. Skipping upload."
    echo "         Set it via: export DIAWI_TOKEN=your_token"
    echo "         Or add DIAWI_TOKEN=your_token to .env"
    echo ""
fi

# Create output directories
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$EXPORT_DIR"

# ─── Step 1: Clean ───────────────────────────────────────────────────
echo "[1/$TOTAL_STEPS] Cleaning build..."
xcodebuild clean \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -quiet

echo "         Clean complete."
echo ""

# ─── Step 2: Archive ─────────────────────────────────────────────────
echo "[2/$TOTAL_STEPS] Archiving (this may take a few minutes)..."
xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -quiet

echo "         Archive complete: $ARCHIVE_PATH"
echo ""

# ─── Step 3: Export or open Organizer ─────────────────────────────────
if [ "$OPEN_ORGANIZER" = true ]; then
    echo "[3/$TOTAL_STEPS] Opening Xcode Organizer..."
    open -a Xcode "$ARCHIVE_PATH"
    echo "         Archive opened in Xcode. Use Organizer to distribute."
    echo ""
    echo "============================================"
    echo "  Done! Archive saved to:"
    echo "  $ARCHIVE_PATH"
    echo "============================================"
    exit 0
fi

echo "[3/$TOTAL_STEPS] Exporting IPA for ad hoc distribution..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -quiet

echo "         Export complete."
echo ""

IPA_FILE=$(find "$EXPORT_DIR" -name "*.ipa" -maxdepth 1 | head -1)

# ─── Step 4: Upload to Diawi ─────────────────────────────────────────
DIAWI_LINK=""
if [ "$SKIP_UPLOAD" = false ] && [ -n "$DIAWI_TOKEN" ] && [ -n "$IPA_FILE" ]; then
    echo "[4/$TOTAL_STEPS] Uploading to Diawi..."

    # Upload IPA
    UPLOAD_RESPONSE=$(curl -s -X POST "https://upload.diawi.com" \
        -F "token=$DIAWI_TOKEN" \
        -F "file=@$IPA_FILE")

    JOB=$(echo "$UPLOAD_RESPONSE" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('job',''))" 2>/dev/null || true)

    if [ -z "$JOB" ]; then
        echo "         ERROR: Upload failed. Response: $UPLOAD_RESPONSE"
    else
        echo "         Upload started (job: $JOB). Waiting for processing..."

        # Poll for status (max 30 attempts, 3 seconds apart = 90s max)
        for i in $(seq 1 30); do
            sleep 3
            STATUS_RESPONSE=$(curl -s "https://upload.diawi.com/status?job=$JOB&token=$DIAWI_TOKEN")
            STATUS=$(echo "$STATUS_RESPONSE" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status',0))" 2>/dev/null || echo "0")

            if [ "$STATUS" = "2000" ]; then
                DIAWI_LINK=$(echo "$STATUS_RESPONSE" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('link',''))" 2>/dev/null || true)
                echo "         Upload complete!"
                break
            elif [ "$STATUS" = "2001" ]; then
                printf "         Processing... (%d/30)\r" "$i"
            else
                ERROR_MSG=$(echo "$STATUS_RESPONSE" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('message','Unknown error'))" 2>/dev/null || echo "Unknown error")
                echo "         ERROR: $ERROR_MSG"
                break
            fi
        done

        if [ "$STATUS" = "2001" ]; then
            echo "         Timed out waiting for Diawi processing."
        fi
    fi
    echo ""
fi

# ─── Summary ──────────────────────────────────────────────────────────
echo "============================================"
echo "  Build Successful!"
echo ""
echo "  Archive: $ARCHIVE_PATH"
echo "  IPA:     ${IPA_FILE:-$EXPORT_DIR}"
if [ -n "$DIAWI_LINK" ]; then
    echo ""
    echo "  Diawi:   $DIAWI_LINK"
fi
echo "============================================"

# Open the export folder in Finder
open "$EXPORT_DIR"
