.PHONY: help install build test test-gas snapshot fmt fmt-check lint clean coverage coverage-html coverage-open

# Default target: print available commands
help:
	@echo "MergeGain — comandos disponibles:"
	@echo ""
	@echo "  make install        Instala/actualiza dependencias de Foundry (git submodules)"
	@echo "  make build          Compila los contratos"
	@echo "  make test           Corre todos los tests"
	@echo "  make test-gas       Corre tests mostrando reporte de gas"
	@echo "  make snapshot       Genera snapshot de gas (.gas-snapshot)"
	@echo "  make fmt            Formatea el código Solidity"
	@echo "  make fmt-check      Verifica formato sin modificar archivos (útil en CI)"
	@echo "  make coverage       Reporte de coverage en terminal"
	@echo "  make coverage-html  Genera reporte HTML en ./coverage/"
	@echo "  make coverage-open  Genera y abre el reporte HTML en el navegador"
	@echo "  make clean          Borra artefactos de build y coverage"

install:
	forge install

build:
	forge build

test:
	forge test -vv

test-gas:
	forge test --gas-report

snapshot:
	forge snapshot

fmt:
	forge fmt

fmt-check:
	forge fmt --check

coverage:
	forge coverage --no-match-coverage "(test|script)"

coverage-html: lcov.info
	@command -v genhtml >/dev/null 2>&1 || { \
		echo "Error: 'genhtml' no encontrado. Instálalo con: brew install lcov"; exit 1; \
	}
	genhtml lcov.info --output-directory coverage --branch-coverage --quiet
	@echo "Reporte generado en ./coverage/index.html"

lcov.info:
	forge coverage --report lcov --no-match-coverage "(test|script)"

coverage-open: coverage-html
	open coverage/index.html

clean:
	forge clean
	rm -rf coverage lcov.info
