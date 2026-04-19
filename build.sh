#!/bin/bash

set -eu

resolve_repo_dir() {
	local source_path="${BASH_SOURCE[0]}"
	local source_dir=""

	while [ -L "$source_path" ]; do
		source_dir="$(cd -P "$(dirname "$source_path")" && pwd)"
		source_path="$(readlink "$source_path")"
		if [[ "$source_path" != /* ]]; then
			source_path="$source_dir/$source_path"
		fi
	done

	cd -P "$(dirname "$source_path")" && pwd
}

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(resolve_repo_dir)"
#LEDE_DIR="$SCRIPT_DIR/lede"
LEDE_DIR="$SCRIPT_DIR/immortalwrt"

detect_go_bootstrap_root() {
	local go_bin go_root

	if ! go_bin="$(command -v go 2>/dev/null)"; then
		return 1
	fi

	go_root="$(go env GOROOT 2>/dev/null || true)"
	if [ -n "$go_root" ] && [ -x "$go_root/bin/go" ]; then
		printf '%s\n' "$go_root"
		return 0
	fi

	case "$go_bin" in
		/usr/bin/go)
			if [ -x /usr/lib/go/bin/go ]; then
				printf '%s\n' "/usr/lib/go"
				return 0
			fi
			;;
	esac

	return 1
}

prepare_golang_bootstrap() {
	local host_arch bootstrap_root

	host_arch="$(uname -m)"
	case "$host_arch" in
		aarch64|arm64)
			;;
		*)
			return 0
			;;
	esac

	if ! bootstrap_root="$(detect_go_bootstrap_root)"; then
		echo "error: ARM64 host detected but no usable system Go bootstrap was found." >&2
		echo "error: Install Go before building, or set CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT manually." >&2
		exit 1
	fi

	echo "----------configuring golang bootstrap for $host_arch---------"
	cd "$LEDE_DIR"
	if [ -f .config ] && grep -q '^CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT=' .config; then
		sed -i.bak "s|^CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT=.*|CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT=\"$bootstrap_root\"|" .config
	else
		printf '\nCONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT="%s"\n' "$bootstrap_root" >> .config
	fi
	rm -f .config.bak
	echo "using CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT=$bootstrap_root"
	echo "-----------end-------------"
}

update_code() {
	echo "----------updating---------"
	cd "$LEDE_DIR"
	git pull
	# cd package/lean/luci-app-serverchan
	# git pull
	# cd -
	./scripts/feeds update -a
	./scripts/feeds install -a -f
	echo "-----------end-------------"
}

check_config() {
	local config_file="config/amd64.config"

	if [ "${1:-}" = "r2s" ]; then
		config_file="config/r2s.config"
	fi

	echo "----------checking $config_file---------"
	cd "$LEDE_DIR"
	cp "$REPO_DIR/$config_file" .config
	make defconfig
	./scripts/diffconfig.sh > seed.config
	echo "---echo seed.config diff---"
	if ! diff -u "$REPO_DIR/$config_file" seed.config; then
		echo "move to $REPO_DIR/$config_file"
		cp seed.config "$REPO_DIR/$config_file"
	fi
	echo "-----------end-------------"
}

build_code() {
	echo "----------building---------"
	cd "$LEDE_DIR"
	if [ "${1:-}" = "clean" ]; then
		echo "make dirclean"
		make dirclean
	fi
	prepare_golang_bootstrap
	make -j8 download V=s
	# make -j"$(( $(nproc) + 1 ))" V=s
	make -j"$(( $(nproc) + 1 ))" V=s || make -j1 V=s
	# make -j"$(nproc)" || make -j1 || make -j1 V=s
	echo "-----------end-------------"
}

command="${1:-}"
target="${2:-}"

case "$command" in
	update)
		update_code
		;;
	check)
		check_config "$target"
		;;
	build)
		build_code "$target"
		;;
	*)
		echo "error command: ${command:-<empty>}" >&2
		echo "usage: $0 {update|check|build} [r2s|clean]" >&2
		exit 1
		;;
esac
