#!/usr/bin/env bash
# Sync docs/**/*.md to Confluence using md2cf (Python).
# Reads credentials from .confluence/credentials (gitignored).
# Page titles come from the H1 of each markdown file.
# Subdirectories under the target become parent pages (capitalized via --beautify-folders).

set -euo pipefail

cd "$(dirname "$0")/.."

CRED_PATH=".confluence/credentials"
if [ ! -f "$CRED_PATH" ]; then
    echo "Missing $CRED_PATH. Copy .confluence/credentials.example and fill it in." >&2
    exit 1
fi

# shellcheck disable=SC1090
set -a; source "$CRED_PATH"; set +a

for var in CONFLUENCE_BASE_URL CONFLUENCE_EMAIL CONFLUENCE_API_TOKEN; do
    if [ -z "${!var:-}" ]; then
        echo "Missing $var in $CRED_PATH" >&2
        exit 1
    fi
done

if ! command -v python >/dev/null 2>&1; then
    echo "python not on PATH. Install Python 3 first." >&2
    exit 1
fi

if ! python -m md2cf --help >/dev/null 2>&1; then
    echo "md2cf not installed. Run: pip install md2cf" >&2
    exit 1
fi

# md2cf wants the API root, not the wiki root
API_URL="${CONFLUENCE_BASE_URL%/}/rest/api/"
SPACE="${CONFLUENCE_SPACE:-MFS}"

# Where the docs land in the space:
#   - CONFLUENCE_PARENT_ID set → place all pages under that page id
#   - CONFLUENCE_PARENT_TITLE set → place all pages under the page with that title
#   - neither → push to the top level of the space
PARENT_ARGS=()
if [ -n "${CONFLUENCE_PARENT_ID:-}" ]; then
    PARENT_ARGS+=("-A" "$CONFLUENCE_PARENT_ID")
elif [ -n "${CONFLUENCE_PARENT_TITLE:-}" ]; then
    PARENT_ARGS+=("-a" "$CONFLUENCE_PARENT_TITLE")
else
    PARENT_ARGS+=("--top-level")
fi

# Force UTF-8 so the terminal can render em-dashes and other unicode in titles
export PYTHONIOENCODING=utf-8
export PYTHONUTF8=1

# Default sync target is the whole docs/ tree. Override with a positional argument.
TARGET="${1:-docs/}"

echo "Syncing $TARGET to Confluence space $SPACE (${PARENT_ARGS[*]})..."

python -m md2cf \
    -o "$API_URL" \
    -u "$CONFLUENCE_EMAIL" \
    -p "$CONFLUENCE_API_TOKEN" \
    -s "$SPACE" \
    "${PARENT_ARGS[@]}" \
    --beautify-folders \
    --strip-top-header \
    --skip-empty \
    "$TARGET"

echo "Done."
