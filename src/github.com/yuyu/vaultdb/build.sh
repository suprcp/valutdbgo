#!/bin/bash
# VaultDB build script with RocksDB support

set -e

# Detect RocksDB paths using pkg-config
if command -v pkg-config &> /dev/null && pkg-config --exists rocksdb; then
    CGO_CFLAGS=$(pkg-config --cflags rocksdb)
    CGO_LDFLAGS=$(pkg-config --libs rocksdb)
    echo "Using pkg-config for RocksDB paths"
else
    # Fallback paths for Homebrew on macOS
    CGO_CFLAGS="-I/opt/homebrew/include"
    CGO_LDFLAGS="-L/opt/homebrew/lib -lrocksdb"
    echo "Using fallback paths for RocksDB"
fi

echo "CGO_CFLAGS=$CGO_CFLAGS"
echo "CGO_LDFLAGS=$CGO_LDFLAGS"
echo "Building vaultdb..."

export CGO_CFLAGS
export CGO_LDFLAGS

go build -o vaultdb .

echo "Build complete: ./vaultdb"
