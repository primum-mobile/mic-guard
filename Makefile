PREFIX ?= $(HOME)/.local
BIN := build/mic-guard

.PHONY: build install uninstall clean

build: $(BIN)

$(BIN): Sources/main.swift
	@mkdir -p build
	swiftc -O Sources/main.swift -o $(BIN)

install: build
	./install.sh $(ARGS)

uninstall:
	./uninstall.sh

clean:
	rm -rf build
