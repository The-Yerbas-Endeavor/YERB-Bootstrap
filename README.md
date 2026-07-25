# Yerbas Bootstrap

Bootstrap and PoW cache data for Yerbas Core wallets and services.

`bootstrap-index.zip` includes the additional indexes required by the Yerbas Multi-Explorer:

```ini
addressindex=1
assetindex=1
spentindex=1
timestampindex=1
txindex=1
```

## Create a release archive

Install the required tools and ensure a fully synchronized local `yerbasd` is running:

```bash
sudo apt install -y zip jq
```

Run the creation script from the repository root:

```bash
VERSION=1.0.0.4 \
DATA_DIR="$HOME/.yerbas" \
./scripts/create-bootstrap.sh
```

The script queries the local node immediately before packaging:

```bash
yerbas-cli getblockcount
yerbas-cli getbestblockhash
```

It creates the following files under `dist/`:

- `bootstrap-index.zip`
- `bootstrap-index.zip.sha256`
- `bootstrap-info.json`

The metadata includes the release version, exact block height, best-block hash, UTC creation time, compressed and estimated extracted sizes, SHA-256 checksum, and whether indexes are included.

Example metadata:

```json
{
  "version": "1.0.0.4",
  "block_height": 1384276,
  "best_block_hash": "0000000000000000000000000000000000000000000000000000000000000000",
  "created": "2026-07-25T02:30:00Z",
  "archive": "bootstrap-index.zip",
  "download_size_bytes": 2040109465,
  "estimated_extracted_size_bytes": 5905580032,
  "sha256": "...",
  "includes_indexes": true,
  "source_data_directory": "/home/yerbas/.yerbas"
}
```

Upload all three generated files to the matching GitHub release so installers can display and verify the bootstrap metadata before extraction.
