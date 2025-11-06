#!/bin/bash
set -e

# 准备 ohos-sdk
# OpenHarmony 发布页（https://gitcode.com/openharmony/docs/blob/master/zh-cn/release-notes/OpenHarmony-v6.0-release.md）里面的 6.0 release 版本 ohos-sdk 并未包含代码签名工具
# 为了使用代码签名工具，这里只能从 OpenHarmony 官方社区的每日构建流水线（https://ci.openharmony.cn/workbench/cicd/dailybuild/dailylist）下载主干版本的 ohos-sdk
sdk_download_url="https://cidownload.openharmony.cn/version/Daily_Version/OpenHarmony_6.0.0.56/20251027_150702/version-Daily_Version-OpenHarmony_6.0.0.56-20251027_150702-ohos-sdk-public.tar.gz"
curl $sdk_download_url -o ohos-sdk-public.tar.gz
mkdir -p /opt/ohos-sdk
tar -zxf ohos-sdk-public.tar.gz -C /opt/ohos-sdk
cd /opt/ohos-sdk/linux
unzip -q native-*.zip
unzip -q toolchains-*.zip
cd - >/dev/null

# 设置交叉编译所需的环境变量
export OHOS_SDK=/opt/ohos-sdk/linux
export AS=${OHOS_SDK}/native/llvm/bin/llvm-as
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=aarch64-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=aarch64-linux-ohos"
export LD=${OHOS_SDK}/native/llvm/bin/ld.lld
export STRIP=${OHOS_SDK}/native/llvm/bin/llvm-strip
export RANLIB=${OHOS_SDK}/native/llvm/bin/llvm-ranlib
export OBJDUMP=${OHOS_SDK}/native/llvm/bin/llvm-objdump
export OBJCOPY=${OHOS_SDK}/native/llvm/bin/llvm-objcopy
export NM=${OHOS_SDK}/native/llvm/bin/llvm-nm
export AR=${OHOS_SDK}/native/llvm/bin/llvm-ar
export CFLAGS="-D__MUSL__=1"
export CXXFLAGS="-D__MUSL__=1"

# 编译 openssl
curl -L -O https://github.com/openssl/openssl/releases/download/openssl-3.0.9/openssl-3.0.9.tar.gz
tar -zxf openssl-3.0.9.tar.gz
cd openssl-3.0.9/
./Configure --prefix=/opt/openssl-3.0.9-ohos-arm64 linux-aarch64 no-shared
make -j$(nproc)
make install
cd ..

# 编译 zlib
curl -L -O https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
tar -zxf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --prefix=/opt/zlib-1.3.1-ohos-arm64 --static
make -j$(nproc)
make install
cd ..

# 编译 curl
curl -L -O  https://curl.se/download/curl-8.8.0.tar.gz
tar -zxf curl-8.8.0.tar.gz
cd curl-8.8.0/
./configure \
    --host=aarch64-linux \
    --prefix=/opt/curl-8.8.0-ohos-arm64 \
    --enable-static \
    --disable-shared \
    --with-openssl=/opt/openssl-3.0.9-ohos-arm64 \
    --with-zlib=/opt/zlib-1.3.1-ohos-arm64 \
    --with-ca-bundle=/etc/ssl/certs/cacert.pem \
    --with-ca-path=/etc/ssl/certs \
    CPPFLAGS="-D_GNU_SOURCE"
make -j$(nproc)
make install
cd ..

# 履行开源义务，把使用的开源软件的 license 全部聚合起来放到制品中
curl_license=$(cat curl-8.8.0/COPYING; echo)
openssl_license=$(cat openssl-3.0.9/LICENSE.txt; echo)
openssl_authors=$(cat openssl-3.0.9/AUTHORS.md; echo)
zlib_license=$(cat zlib-1.3.1/LICENSE; echo)
printf '%s' "$(cat <<EOF
This document describes the licenses of all software distributed with the
bundled application.
==========================================================================

curl
=============
$curl_license

openssl
=============
==license==
$openssl_license
==authors==
$openssl_authors

zlib
=============
$zlib_license
EOF
)" > /opt/curl-8.8.0-ohos-arm64/licenses.txt

# 代码签名。做这一步是为了现在或以后能让它运行在 OpenHarmony 的商业发行版——HarmonyOS 上。
/opt/ohos-sdk/linux/toolchains/lib/binary-sign-tool sign -inFile /opt/curl-8.8.0-ohos-arm64/bin/curl -outFile /opt/curl-8.8.0-ohos-arm64/bin/curl -selfSign 1

# 打包最终产物
cd /opt
tar -zcf curl-8.8.0-ohos-arm64.tar.gz curl-8.8.0-ohos-arm64
