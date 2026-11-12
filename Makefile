.PHONY: setup_dev test lint test_infra test_all clean

setup_dev:
	@echo "Installing bats..."
	@git clone https://github.com/bats-core/bats-core.git /tmp/bats-core 2>/dev/null || true
	@/tmp/bats-core/install.sh "$$HOME/.local" 2>/dev/null || true
	@echo "Installing shellcheck..."
	@command -v shellcheck >/dev/null 2>&1 || sudo apt-get install -y shellcheck
	@echo "Installing actionlint..."
	@command -v actionlint >/dev/null 2>&1 || go install github.com/rhysd/actionlint/cmd/actionlint@latest 2>/dev/null || true
	@echo "Installing zizmor..."
	@command -v zizmor >/dev/null 2>&1 || pip install --quiet zizmor==1.26.1 2>/dev/null || true

test:
	bats tests/unit/

test_infra:
	bats tests/unit/test_infra_files.bats

lint:
	shellcheck scripts/*.sh .github/scripts/*.sh
	actionlint
	zizmor --offline .github/workflows/

test_all: test lint

clean:
	rm -rf /tmp/bats-core /tmp/gha-repo-index-*
