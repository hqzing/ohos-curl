# ohos-curl
This project will build curl for the OpenHarmony platform and release prebuilt packages.

This is a statically linked curl. Just copy the binary and use it.

## Get prebuilt packages
Go to the [release page](https://github.com/Harmonybrew/ohos-curl/releases).

## Build from source
Run the build.sh script on a Linux x64 server to cross-compile curl for OpenHarmony (e.g., on Ubuntu 24.04 x64).
```sh
sudo apt update && sudo apt install -y build-essential unzip jq
./build.sh
```
