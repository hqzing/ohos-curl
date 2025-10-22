#!/bin/bash
set -e

# Setup ohos-sdk
query_component() {
  component=$1
  curl -fsSL 'https://ci.openharmony.cn/api/daily_build/build/list/component' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: application/json' \
    --data-raw '{"projectName":"openharmony","branch":"master","pageNum":1,"pageSize":10,"deviceLevel":"","component":"'${component}'","type":1,"startTime":"2025080100000000","endTime":"20990101235959","sortType":"","sortField":"","hardwareBoard":"","buildStatus":"success","buildFailReason":"","withDomain":1}'
}
sdk_download_url=$(query_component "ohos-sdk-public" | jq -r ".data.list.dataList[0].obsPath")
curl $sdk_download_url -o ohos-sdk-public.tar.gz
mkdir -p /opt/ohos-sdk
tar -zxf ohos-sdk-public.tar.gz -C /opt/ohos-sdk
cd /opt/ohos-sdk/linux
unzip -q native-*.zip
unzip -q toolchains-*.zip
cd - >/dev/null

# Setup env
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
export CFLAGS="-fPIC -D__MUSL__=1"
export CXXFLAGS="-fPIC -D__MUSL__=1"

# Build openssl
curl -L -O https://github.com/openssl/openssl/releases/download/openssl-3.0.9/openssl-3.0.9.tar.gz
tar -zxf openssl-3.0.9.tar.gz
cd openssl-3.0.9/
./Configure --prefix=/opt/openssl-3.0.9-ohos-arm64 linux-aarch64 no-shared
make -j$(nproc)
make install
cd ..

# Build zlib
curl -L -O https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
tar -zxf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --prefix=/opt/zlib-1.3.1-ohos-arm64 --static
make -j$(nproc)
make install
cd ..

# Build curl
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
cp COPYING /opt/curl-8.8.0-ohos-arm64
cd ..

# Codesign
/opt/ohos-sdk/linux/toolchains/lib/binary-sign-tool sign -inFile /opt/curl-8.8.0-ohos-arm64/bin/curl -outFile /opt/curl-8.8.0-ohos-arm64/bin/curl -selfSign 1

cd /opt
tar -zcf curl-8.8.0-ohos-arm64.tar.gz curl-8.8.0-ohos-arm64
