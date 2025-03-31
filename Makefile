SHELL := /bin/bash

.ONESHELL:
.PHONY: docker linux-ceci darwin-ceci windows-ceci vendor

## version
LSB = $(shell lsb_release -i -s)$(shell lsb_release -r -s)
VER = $(shell ./dist/version.sh)
ARCH = $(shell uname -m)

## declare directory
SD = $(shell pwd)
BD = "$(SD)/build"
CD = "$(SD)/build/coverage"
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
update: ## update source code
	git pull
	git submodule init

env: update
	mkdir -p $(BD)
	go version
	gofmt -w -s ./pkg ./cmd

vendor:
	go clean -modcache
	go mod tidy
	go mod vendor -v

builder:
	docker run -d -it \
	--env http_proxy="${http_proxy}" --env https_proxy="${https_proxy}" \
	--volume $(SD)/:/opt/openceci --volume $(shell echo ~)/.ssh:/root/.ssh \
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
	cp -rf $(SD)/docker/centos $(BD)
	cd $(BD) && \
	sudo docker build -t luscis/openceci:$(VER).$(ARCH).el \
	--build-arg linux_bin=$(LIN_DIR).bin --build-arg http_proxy="${http_proxy}" --build-arg https_proxy="${https_proxy}" \
	--file centos/Dockerfile .

docker-deb: docker-bin ## build image for debian
	cp -rf $(SD)/docker/debian $(BD)
	cd $(BD) && \
	sudo docker build -t luscis/openceci:$(VER).$(ARCH).deb \
	--build-arg linux_bin=$(LIN_DIR).bin --build-arg http_proxy="${http_proxy}" --build-arg https_proxy="${https_proxy}" \
	--file debian/Dockerfile .

docker: docker-deb docker-rhel ## build docker images

docker-builder: builder ## create a builder

ceci: linux-ceci darwin-ceci windows-ceci ## build all platform ceci

linux-ceci:
	go build -mod=vendor -ldflags "$(LDFLAGS)" -o $(BD)/openceci ./cmd

linux-gzip: install ## build linux packages
	@rm -rf $(LIN_DIR).tar.gz
	tar -cf $(LIN_DIR).tar $(LIN_DIR) && mv $(LIN_DIR).tar $(BD)
	@rm -rf $(LIN_DIR)
	gzip -f $(BD)/$(LIN_DIR).tar


install: env linux-ceci ## install packages
	@mkdir -p $(LIN_DIR)
	@cp -rf $(SD)/dist/rootfs/{etc,usr} $(LIN_DIR)
	@cp -rf $(SD)/dist/cert/openlan/cert $(LIN_DIR)/etc/openceci
	@cp -rf $(SD)/dist/cert/openlan/ca/ca.crt $(LIN_DIR)/etc/openceci/cert
	@mkdir -p $(LIN_DIR)/usr/bin
	@cp -rf $(BD)/openceci $(LIN_DIR)/usr/bin
	@echo "Installed to $(LIN_DIR)"

windows-ceci:
	GOOS=windows GOARCH=amd64 go build -mod=vendor -ldflags "$(LDFLAGS)" -o $(BD)/openceci.exe ./cmd

windows-gzip: env windows-ceci ## build windows packages
	@rm -rf $(WIN_DIR) && mkdir -p $(WIN_DIR)
	@cp -rf $(SD)/dist/rootfs/etc/openceci/http.yaml.example $(WIN_DIR)/ceci.yaml
	@cp -rf $(BD)/openceci.exe $(WIN_DIR)
	tar -cf $(WIN_DIR).tar $(WIN_DIR) && mv $(WIN_DIR).tar $(BD)
	gzip -f $(BD)/$(WIN_DIR).tar && rm -rf $(WIN_DIR)

darwin-ceci:
	GOOS=darwin GOARCH=amd64 go build -mod=vendor -ldflags "$(LDFLAGS)" -o $(BD)/openceci.dar ./cmd
	GOOS=darwin GOARCH=arm64 go build -mod=vendor -ldflags "$(LDFLAGS)" -o $(BD)/openceci.arm64.dar ./cmd

darwin-gzip: env darwin-ceci ## build darwin packages
	@rm -rf $(MAC_DIR) && mkdir -p $(MAC_DIR)
	@cp -rf $(SD)/dist/rootfs/etc/openceci/http.yaml.example $(MAC_DIR)/ceci.yaml
	@cp -rf $(BD)/{openceci.dar,openceci.arm64.dar} $(MAC_DIR)
	tar -cf $(MAC_DIR).tar $(MAC_DIR) && mv $(MAC_DIR).tar $(BD)
	gzip -f $(BD)/$(MAC_DIR).tar && rm -rf $(MAC_DIR)

clean: ## clean cache
	rm -rvf ./build
