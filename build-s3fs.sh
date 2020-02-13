#!/usr/bin/env bash

# The MIT License (MIT)
#
# Copyright (c) 2016 - 2018 Volt Grid Pty Ltd
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Build S3FS from source
# See https://github.com/s3fs-fuse/s3fs-fuse

# Fail on errors
set -euo pipefail
[ "${DEBUG:-false}" == 'true' ] && set -x

# Don't prompt on install
export DEBIAN_FRONTEND=noninteractive

# Build config
echo "/usr/local/lib" > /etc/ld.so.conf.d/libc.conf
export MAKEFLAGS="-j$[$(nproc) + 1]"
export SRC=/usr/local
export PKG_CONFIG_PATH=${SRC}/lib/pkgconfig

# Runtime requirements
apt-get update
apt-get -y install fuse libfuse2 libcurl3-gnutls libxml2 libssl1.1

# Install build requirements
BUILD_REQS='automake autotools-dev curl g++ git libcurl4-gnutls-dev libfuse-dev libssl-dev libxml2-dev make pkg-config'
apt-get -y install $BUILD_REQS

# Build s3fs
DIR=$(mktemp -d) && cd ${DIR}
curl -s https://codeload.github.com/s3fs-fuse/s3fs-fuse/tar.gz/v${S3FS_VERSION} -o s3fs.tar.gz
sha1sum s3fs.tar.gz
echo "$S3FS_SHA1 s3fs.tar.gz" | sha1sum -c -
tar -xzf s3fs.tar.gz -C . --strip-components=1
./autogen.sh
./configure
make
make install
rm -rf ${DIR}

# Update shared library cache
ldconfig

# Check binary is sane
/usr/local/bin/s3fs --version

# Cleanup
apt-get -y remove $BUILD_REQS && apt-get -y autoremove && rm -rf /var/lib/apt/lists/*
rm -- "$0"