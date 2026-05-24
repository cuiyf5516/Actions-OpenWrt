#!/bin/bash
#
# https://github.com/cuiyf5516/Actions-OpenWrt
#
# File: build.sh
# Description: Local build script for OpenWrt
#
# Copyright (c) 2021-2026 cuiyf5516 <yjcuiyf@gmail.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

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
DEFAULT_SOURCE="immortalwrt"
SOURCE="$DEFAULT_SOURCE"
LEDE_DIR="$SCRIPT_DIR/$SOURCE"

usage() {
	echo "usage: $0 update [immortalwrt|lede]" >&2
	echo "       $0 check [immortalwrt|lede] [amd64|r2s]" >&2
	echo "       $0 build [immortalwrt|lede] [clean]" >&2
	echo "compat: $0 check r2s" >&2
}

is_source() {
	case "${1:-}" in
		immortalwrt|lede)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

set_source() {
	SOURCE="${1:-$DEFAULT_SOURCE}"
	if ! is_source "$SOURCE"; then
		echo "error source: $SOURCE" >&2
		usage
		exit 1
	fi
	LEDE_DIR="$SCRIPT_DIR/$SOURCE"
}

validate_target() {
	case "${1:-}" in
		amd64|r2s)
			return 0
			;;
		*)
			echo "error target: ${1:-<empty>}" >&2
			usage
			exit 1
			;;
	esac
}

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
	local target="${1:-amd64}"
	local config_file="config/$SOURCE/$target.config"

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
	# make -j"$(nproc)" V=s
	make -j"$(nproc)" V=s || make -j1 V=s
	# make -j"$(nproc)" || make -j1 || make -j1 V=s
	echo "-----------end-------------"
}

command="${1:-}"
if [ "$#" -gt 0 ]; then
	shift
fi

case "$command" in
	update)
		if [ "$#" -gt 1 ]; then
			echo "error: too many arguments for update" >&2
			usage
			exit 1
		fi
		set_source "${1:-$DEFAULT_SOURCE}"
		update_code
		;;
	check)
		source="$DEFAULT_SOURCE"
		target="amd64"
		if [ "$#" -gt 0 ]; then
			if is_source "$1"; then
				source="$1"
				target="${2:-amd64}"
				if [ "$#" -gt 2 ]; then
					echo "error: too many arguments for check" >&2
					usage
					exit 1
				fi
			else
				target="$1"
				if [ "$#" -gt 1 ]; then
					echo "error: too many arguments for check" >&2
					usage
					exit 1
				fi
			fi
		fi
		validate_target "$target"
		set_source "$source"
		check_config "$target"
		;;
	build)
		source="$DEFAULT_SOURCE"
		build_arg=""
		if [ "$#" -gt 0 ]; then
			if is_source "$1"; then
				source="$1"
				build_arg="${2:-}"
				if [ "$#" -gt 2 ]; then
					echo "error: too many arguments for build" >&2
					usage
					exit 1
				fi
			else
				build_arg="$1"
				if [ "$#" -gt 1 ]; then
					echo "error: too many arguments for build" >&2
					usage
					exit 1
				fi
			fi
		fi
		if [ -n "$build_arg" ] && [ "$build_arg" != "clean" ]; then
			echo "error build argument: $build_arg" >&2
			usage
			exit 1
		fi
		set_source "$source"
		build_code "$build_arg"
		;;
	*)
		echo "error command: ${command:-<empty>}" >&2
		usage
		exit 1
		;;
esac
