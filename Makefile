SHELL := /bin/bash

.ONESHELL:
.PHONY: docker linux-ceci darwin-ceci windows-ceci vendor

## version
LSB = $(shell lsb_release -i -s)$(shell lsb_release -r -s)
VER = $(shell ./dist/version.sh)
ARCH = $(shell uname -m)

## declare directory
SRC_DIR = $(shell pwd)
BUILD_DIR = "$(SRC_DIR)/build"
LIN_DIR ?= "openceci-linux-$(VER).$(ARCH)"
WIN_DIR ?= "openceci-windows-$(VER).$(ARCH)"
MAC_DIR ?= "openceci-darwin-$(VER).$(ARCH)"

## declare flags
MOD = github.com/luscis/libol
LDFLAGS += -X $(MOD).Date=$(shell date +%FT%T%z)
LDFLAGS += -X $(MOD).Version=$(VER)

build: ceci

gzip: linux-gzip windows-gzip darwin-gzip ## build all plaftorm gzip

help: ## show make targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {sub("\\\\n",sprintf("\n%22c"," "), $$2);\
	printf " \033[36m%-20s\033[0m  %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## prepare environment
update:
	mkdir -p $(BUILD_DIR)
	git pull
	git submodule init
	go version
	gofmt -w -s ./pkg ./cmd

vendor:
	go clean -modcache
	go mod tidy
	go mod vendor -v

builder:
	docker run -d -it \
	--env http_proxy="${http_proxy}" --env https_proxy="${https_proxy}" \
	--volume $(SRC_DIR)/:/opt/openceci --volume $(shell echo ~)/.ssh:/root/.ssh \
	--name openceci_der debian:bullseye bash
	docker exec openceci_der bash -c "apt update && apt install -y git lsb-release wget make gcc"
	docker exec openceci_der bash -c "wget https://golang.google.cn/dl/go1.16.linux-amd64.tar.gz && tar -xf go1.16.linux-amd64.tar.gz -C /usr/local"
	docker exec openceci_der bash -c "cd /usr/local/bin && ln -s ../go/bin/go . && ln -s ../go/bin/gofmt ."
	docker exec openceci_der git config --global --add safe.directory /opt/openceci
	docker exec openceci_der git config --global --add safe.directory /opt/openceci/dist/cert

docker-gzip: ## binary by Docker
	docker exec openceci_der bash -c "cd /opt/openceci && make gzip"

docker-ceci: ## binary for ceci by Docker
	docker exec openceci_der bash -c "cd /opt/openceci && make ceci"

docker-rhel: docker-bin ## build image for redhat
	cp -rf $(SRC_DIR)/docker/centos $(BUILD_DIR)
	cd $(BUILD_DIR) && \
	sudo docker build -t luscis/openceci:$(VER).$(ARCH).el \
	--build-arg linux_bin=$(LIN_DIR).bin --build-arg http_proxy="${http_proxy}" --build-arg https_proxy="${https_proxy}" \
	--file centos/Dockerfile .

docker-deb: docker-bin ## build image for debian
	cp -rf $(SRC_DIR)/docker/debian $(BUILD_DIR)
	cd $(BUILD_DIR) && \
	sudo docker build -t luscis/openceci:$(VER).$(ARCH).deb \
	--build-arg linux_bin=$(LIN_DIR).bin --build-arg http_proxy="${http_proxy}" --build-arg https_proxy="${https_proxy}" \
	--file debian/Dockerfile .

docker: docker-deb docker-rhel ## build docker images

docker-builder: builder ## create a builder

ceci: linux-ceci darwin-ceci windows-ceci ## build all platform ceci

linux-ceci:
	go build -mod=vendor -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/openceci ./cmd

linux-gzip: install ## build linux packages
	@rm -rf $(LIN_DIR).tar.gz
	tar -cf $(LIN_DIR).tar $(LIN_DIR) && mv $(LIN_DIR).tar $(BUILD_DIR)
	@rm -rf $(LIN_DIR)
	gzip -f $(BUILD_DIR)/$(LIN_DIR).tar


install: update linux-ceci ## install packages
	@mkdir -p $(LIN_DIR)
	@cp -rf $(SRC_DIR)/dist/rootfs/{etc,usr} $(LIN_DIR)
	@cp -rf $(SRC_DIR)/dist/cert/openlan/cert $(LIN_DIR)/etc/openceci
	@cp -rf $(SRC_DIR)/dist/cert/openlan/ca/ca.crt $(LIN_DIR)/etc/openceci/cert
	@mkdir -p $(LIN_DIR)/usr/bin
	@cp -rf $(BUILD_DIR)/openceci $(LIN_DIR)/usr/bin
	@echo "Installed to $(LIN_DIR)"

windows-ceci:
	GOOS=windows GOARCH=amd64 go build -mod=vendor -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/openceci.exe ./cmd

windows-gzip: update windows-ceci ## build windows packages
	@rm -rf $(WIN_DIR) && mkdir -p $(WIN_DIR)
	@cp -rf $(SRC_DIR)/dist/rootfs/etc/openceci/http.yaml.example $(WIN_DIR)/ceci.yaml
	@cp -rf $(BUILD_DIR)/openceci.exe $(WIN_DIR)
	tar -cf $(WIN_DIR).tar $(WIN_DIR) && mv $(WIN_DIR).tar $(BUILD_DIR)
	gzip -f $(BUILD_DIR)/$(WIN_DIR).tar && rm -rf $(WIN_DIR)

darwin-ceci:
	GOOS=darwin GOARCH=amd64 go build -mod=vendor -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/openceci.dar ./cmd
	GOOS=darwin GOARCH=arm64 go build -mod=vendor -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/openceci.arm64.dar ./cmd

darwin-gzip: update darwin-ceci ## build darwin packages
	@rm -rf $(MAC_DIR) && mkdir -p $(MAC_DIR)
	@cp -rf $(SRC_DIR)/dist/rootfs/etc/openceci/http.yaml.example $(MAC_DIR)/ceci.yaml
	@cp -rf $(BUILD_DIR)/{openceci.dar,openceci.arm64.dar} $(MAC_DIR)
	tar -cf $(MAC_DIR).tar $(MAC_DIR) && mv $(MAC_DIR).tar $(BUILD_DIR)
	gzip -f $(BUILD_DIR)/$(MAC_DIR).tar && rm -rf $(MAC_DIR)

clean: ## clean cache
	rm -rvf ./build
