#!/usr/bin/env bash
set -Eeuo pipefail

# Build a Yerbas bootstrap archive and matching metadata.
# The blockchain height is queried immediately before packaging so the
# metadata describes the exact node state used to create the archive.

YERBAS_CLI="${YERBAS_CLI:-yerbas-cli}"
DATA_DIR="${DATA_DIR:-${HOME}/.yerbas}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/dist}"
ARCHIVE_NAME="${ARCHIVE_NAME:-bootstrap-index.zip}"
VERSION="${VERSION:-}"
INCLUDE_INDEXES="${INCLUDE_INDEXES:-yes}"

log() { printf '[bootstrap] %s\n' "$*"; }
die() { printf '[bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

command -v "$YERBAS_CLI" >/dev/null 2>&1 || die "Yerbas CLI not found: $YERBAS_CLI"
command -v zip >/dev/null 2>&1 || die "zip is required"
command -v jq >/dev/null 2>&1 || die "jq is required"
[[ -d "$DATA_DIR" ]] || die "Yerbas data directory not found: $DATA_DIR"

if [[ -z "$VERSION" ]]; then
  VERSION="$(date -u +'%Y.%m.%d.%H%M')"
fi

mkdir -p "$OUTPUT_DIR"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"
METADATA_PATH="$OUTPUT_DIR/bootstrap-info.json"
CHECKSUM_PATH="$OUTPUT_DIR/${ARCHIVE_NAME}.sha256"

# Confirm the node is reachable before doing any filesystem work.
"$YERBAS_CLI" getblockchaininfo >/dev/null 2>&1 || die "Unable to query the local Yerbas node"

# Ask the wallet to flush chainstate to disk before taking the archive.
# Failure is non-fatal because older clients may not expose this RPC.
"$YERBAS_CLI" savemempool >/dev/null 2>&1 || true
sync

# Query these values immediately before packaging. Do not move this block
# earlier in the script: it is intentionally adjacent to archive creation.
BLOCK_HEIGHT="$($YERBAS_CLI getblockcount)"
BEST_BLOCK_HASH="$($YERBAS_CLI getbestblockhash)"
CREATED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

[[ "$BLOCK_HEIGHT" =~ ^[0-9]+$ ]] || die "Invalid block height returned by yerbas-cli: $BLOCK_HEIGHT"
[[ "$BEST_BLOCK_HASH" =~ ^[0-9a-fA-F]{64}$ ]] || die "Invalid best block hash returned by yerbas-cli"

INCLUDE_PATHS=(blocks chainstate)
if [[ "$INCLUDE_INDEXES" == yes ]]; then
  INCLUDE_PATHS+=(indexes)
fi

EXISTING_PATHS=()
for path in "${INCLUDE_PATHS[@]}"; do
  [[ -e "$DATA_DIR/$path" ]] && EXISTING_PATHS+=("$path")
done
[[ ${#EXISTING_PATHS[@]} -gt 0 ]] || die "No bootstrap data found in $DATA_DIR"

rm -f "$ARCHIVE_PATH" "$METADATA_PATH" "$CHECKSUM_PATH"

log "Creating $ARCHIVE_PATH at block height $BLOCK_HEIGHT"
(
  cd "$DATA_DIR"
  zip -r -q "$ARCHIVE_PATH" "${EXISTING_PATHS[@]}"
)

[[ -s "$ARCHIVE_PATH" ]] || die "Archive creation failed: $ARCHIVE_PATH is empty"

ARCHIVE_BYTES="$(stat -c '%s' "$ARCHIVE_PATH")"
EXTRACTED_BYTES="$(du -sb "${EXISTING_PATHS[@]/#/$DATA_DIR/}" | awk '{ total += $1 } END { print total + 0 }')"
ARCHIVE_SHA256="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
printf '%s  %s\n' "$ARCHIVE_SHA256" "$ARCHIVE_NAME" > "$CHECKSUM_PATH"

jq -n \
  --arg version "$VERSION" \
  --argjson block_height "$BLOCK_HEIGHT" \
  --arg best_block_hash "$BEST_BLOCK_HASH" \
  --arg created "$CREATED_AT" \
  --arg archive "$ARCHIVE_NAME" \
  --argjson download_size_bytes "$ARCHIVE_BYTES" \
  --argjson extracted_size_bytes "$EXTRACTED_BYTES" \
  --arg sha256 "$ARCHIVE_SHA256" \
  --arg data_directory "$DATA_DIR" \
  --argjson includes_indexes "$([[ "$INCLUDE_INDEXES" == yes ]] && echo true || echo false)" \
  '{
    version: $version,
    block_height: $block_height,
    best_block_hash: $best_block_hash,
    created: $created,
    archive: $archive,
    download_size_bytes: $download_size_bytes,
    estimated_extracted_size_bytes: $extracted_size_bytes,
    sha256: $sha256,
    includes_indexes: $includes_indexes,
    source_data_directory: $data_directory
  }' > "$METADATA_PATH"

jq empty "$METADATA_PATH"

log "Created archive: $ARCHIVE_PATH"
log "Created metadata: $METADATA_PATH"
log "Created checksum: $CHECKSUM_PATH"
log "Block height: $BLOCK_HEIGHT"
log "Best block: $BEST_BLOCK_HASH"
