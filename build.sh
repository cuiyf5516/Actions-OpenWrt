#!/bin/sh

WORKDIR="/home/sky/build/lede"
ORI_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname ${0})"; pwd)"

update_code()
{
	echo "----------updating---------"
	cd $SCRIPT_DIR/lede
	git pull || exit 1
	#cd package/lean/luci-app-serverchan
        #git pull
        #cd ../../../
	./scripts/feeds update -a && ./scripts/feeds install -a -f || exit 2
	echo "-----------end-------------"
}

check_config()
{
	local config_file=amd64.config
        if [ x"$1" = x"r2s" ];then
                config_file=r2s.config
        fi
	echo "----------checking $config_file---------"
	cd $SCRIPT_DIR/lede
	cp ../Actions-OpenWrt-Lean/$config_file .config
	make defconfig || exit 3
	./scripts/diffconfig.sh > seed.config || exit 4
	echo "---echo seed.config diff---"
	diff -u ../Actions-OpenWrt-Lean/$config_file seed.config
	if [ $? -ne 0 ];then
		echo "move to ../Actions-OpenWrt-Lean/$config_file"
		cp seed.config ../Actions-OpenWrt-Lean/$config_file
	fi
	echo "-----------end-------------"
	#cd $ORI_DIR
}

check_test_config()
{
        local config_file=amd64-test.config
        if [ x"$1" = x"r2s" ];then
                config_file=r2s-test.config
        fi
        echo "----------checking $config_file---------"
        cd $SCRIPT_DIR/lede
        cp ../Actions-OpenWrt-Lean/$config_file .config
        make defconfig || exit 3
        ./scripts/diffconfig.sh > seed.config || exit 4
        echo "---echo seed.config diff---"
        diff -u ../Actions-OpenWrt-Lean/$config_file seed.config
        if [ $? -ne 0 ];then
                echo "move to ../Actions-OpenWrt-Lean/$config_file"
                cp seed.config ../Actions-OpenWrt-Lean/$config_file
        fi
        echo "-----------end-------------"
        #cd $ORI_DIR
}

build_code()
{
	echo "----------building---------"
	cd $SCRIPT_DIR/lede
	if [ "$1"x = "clean"x ];then
		echo "make dirclean"
		make dirclean
	fi
	make -j8 download V=s || exit 1
	#make -j$(($(nproc) + 1)) V=s || exit 2
	make -j$(($(nproc) + 1)) V=s || make -j1 V=s || exit 2
	#make -j$(nproc) || make -j1 || make -j1 V=s
	echo "-----------end-------------"
	#cd $ORI_DIR
}

case "$1" in
	update)
		update_code
		;;
        check)
                check_config $2
                ;;
	check_test)
		check_test_config $2
		;;
        build)
                build_code $2
                ;;
        *)
                echo "error command"
		echo "check or build"
esac
