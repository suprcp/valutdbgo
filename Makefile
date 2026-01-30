# VaultDB Makefile

.PHONY: build clean test install run help

# Build variables
BINARY_NAME=vaultdb
BUILD_DIR=bin
GO_VERSION=1.21

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the vaultdb binary
	@echo "Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	@export CGO_CFLAGS="-I/opt/homebrew/include"; \
	 export CGO_LDFLAGS="-L/opt/homebrew/lib -lrocksdb -lzstd -llz4 -lsnappy -lz -pthread"; \
	 export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:$$PKG_CONFIG_PATH"; \
	 export DYLD_LIBRARY_PATH="/opt/homebrew/lib:$$DYLD_LIBRARY_PATH"; \
	 go build -o $(BUILD_DIR)/$(BINARY_NAME) .
	@echo "Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

clean: ## Clean build artifacts
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)
	@go clean
	@echo "Clean complete"

test: ## Run tests
	@echo "Running tests..."
	@export CGO_CFLAGS="-I/opt/homebrew/include"; \
	 export CGO_LDFLAGS="-L/opt/homebrew/lib -lrocksdb -lzstd -llz4 -lsnappy -lz -pthread"; \
	 export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:$$PKG_CONFIG_PATH"; \
	 export DYLD_LIBRARY_PATH="/opt/homebrew/lib:$$DYLD_LIBRARY_PATH"; \
	 go test -v ./...

test-coverage: ## Run tests with coverage
	@echo "Running tests with coverage..."
	@export CGO_CFLAGS="-I/opt/homebrew/include"; \
	 export CGO_LDFLAGS="-L/opt/homebrew/lib -lrocksdb -lzstd -llz4 -lsnappy -lz -pthread"; \
	 export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:$$PKG_CONFIG_PATH"; \
	 export DYLD_LIBRARY_PATH="/opt/homebrew/lib:$$DYLD_LIBRARY_PATH"; \
	 go test -v -coverprofile=coverage.out ./...; \
	 go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

install: ## Install dependencies
	@echo "Installing dependencies..."
	@go mod download
	@go mod tidy
	@echo "Dependencies installed"

run: build ## Build and run vaultdb (requires NODE_ID and DATA_PATH)
	@if [ -z "$(NODE_ID)" ] || [ -z "$(DATA_PATH)" ]; then \
		echo "Usage: make run NODE_ID=node0 DATA_PATH=~/node0"; \
		exit 1; \
	fi
	@$(BUILD_DIR)/$(BINARY_NAME) -id $(NODE_ID) $(DATA_PATH)

fmt: ## Format code
	@echo "Formatting code..."
	@go fmt ./...
	@echo "Format complete"

vet: ## Run go vet
	@echo "Running go vet..."
	@go vet ./...
	@echo "Vet complete"

lint: fmt vet ## Run linters

check: lint test ## Run all checks (format, vet, test)

.DEFAULT_GOAL := help
