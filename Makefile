# Go and compilation related variables
VERSION ?= $(shell git describe --tags --dirty)
BUILD_DIR ?= out

GOPATH ?= $(shell go env GOPATH)

BINARY_NAME := crc-admin-helper
RELEASE_DIR ?= release
GOLANGCI_LINT_VERSION = v1.41.1

LDFLAGS := -X github.com/code-ready/admin-helper/pkg/constants.Version=$(VERSION) -extldflags='-static' -s -w $(GO_LDFLAGS)

# Add default target
.PHONY: all
all: build

.PHONY: vendor
vendor:
	go mod tidy
	go mod vendor

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	rm -fr release
	rm -fr crc-admin-helper.spec

.PHONY: golangci-lint
golangci-lint:
	@if $(GOPATH)/bin/golangci-lint version 2>&1 | grep -vq $(GOLANGCI_LINT_VERSION); then\
		pushd /tmp && GO111MODULE=on go get github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION) && popd; \
	fi

$(BUILD_DIR)/macos-amd64/$(BINARY_NAME):
	CGO_ENABLED=0 GOARCH=amd64 GOOS=darwin go build -ldflags="$(LDFLAGS)" -o $@ $(GO_BUILDFLAGS) ./cmd/admin-helper/

$(BUILD_DIR)/macos-arm64/$(BINARY_NAME)-arm64:
	CGO_ENABLED=0 GOARCH=arm64 GOOS=darwin go build -ldflags="$(LDFLAGS)" -o $@ $(GO_BUILDFLAGS) ./cmd/admin-helper/

$(BUILD_DIR)/linux-amd64/$(BINARY_NAME):
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o $@ $(GO_BUILDFLAGS) ./cmd/admin-helper/

$(BUILD_DIR)/windows-amd64/$(BINARY_NAME).exe:
	CGO_ENABLED=0 GOARCH=amd64 GOOS=windows go build -ldflags="$(LDFLAGS)" -o $@ $(GO_BUILDFLAGS) ./cmd/admin-helper/

.PHONY: cross ## Cross compiles all binaries
cross: $(BUILD_DIR)/macos-amd64/$(BINARY_NAME) $(BUILD_DIR)/macos-arm64/$(BINARY_NAME)-arm64 $(BUILD_DIR)/linux-amd64/$(BINARY_NAME) $(BUILD_DIR)/windows-amd64/$(BINARY_NAME).exe

.PHONY: release
release: clean lint test cross
	mkdir $(RELEASE_DIR)
	cp $(BUILD_DIR)/linux-amd64/$(BINARY_NAME) $(RELEASE_DIR)/$(BINARY_NAME)-linux
	cp $(BUILD_DIR)/macos-amd64/$(BINARY_NAME) $(RELEASE_DIR)/$(BINARY_NAME)-darwin
	cp $(BUILD_DIR)/windows-amd64/$(BINARY_NAME).exe $(RELEASE_DIR)/$(BINARY_NAME)-windows.exe
	pushd $(RELEASE_DIR) && sha256sum * > sha256sum.txt && popd

.PHONY: build
build:
	CGO_ENABLED=0 go build -ldflags="$(LDFLAGS)" -o $(BINARY_NAME) $(GO_BUILDFLAGS) ./cmd/admin-helper/

.PHONY: lint
lint: golangci-lint
	$(GOPATH)/bin/golangci-lint run

.PHONY: test
test:
	go test ./...

.PHONY: spec
spec: crc-admin-helper.spec

$(GOPATH)/bin/gomod2rpmdeps:
	pushd /tmp && GO111MODULE=on go get github.com/cfergeau/gomod2rpmdeps/cmd/gomod2rpmdeps && popd

%.spec: %.spec.in $(GOPATH)/bin/gomod2rpmdeps
	@$(GOPATH)/bin/gomod2rpmdeps | sed -e '/__BUNDLED_REQUIRES__/r /dev/stdin' \
					   -e '/__BUNDLED_REQUIRES__/d' \
				       $< >$@
