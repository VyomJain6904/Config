.PHONY: all build clean test

BIN_DIR ?= $(CURDIR)/bin
BINARY := $(BIN_DIR)/qs-helper
GO_SOURCES := $(shell find . -type f -name '*.go')

all: build

build: $(BINARY)

$(BINARY): go.mod Makefile $(GO_SOURCES)
	mkdir -p $(BIN_DIR)
	CGO_ENABLED=1 go build -buildvcs=false -trimpath -ldflags='-s -w' -o $(BINARY) ./cmd/qs-helper

test:
	go test ./...

clean:
	rm -f $(BINARY)
