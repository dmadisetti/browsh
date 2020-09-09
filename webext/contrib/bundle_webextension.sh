#!/usr/bin/env bash
# Convert the Browsh webextension into embedable binary data so that we can
# distribute Browsh as a single static binary.

# Requires the go-bindata binary, which seems to only be installed with:
#   `go get -u gopkg.in/shuLhan/go-bindata.v3/...`

set -e

PROJECT_ROOT=$(git rev-parse --show-toplevel)

NODE_BIN=$PROJECT_ROOT/webext/node_modules/.bin
destination=$PROJECT_ROOT/interfacer/src/browsh/webextension.go

cd $PROJECT_ROOT/webext && $NODE_BIN/webpack
cd $PROJECT_ROOT/webext/dist && rm *.map
if [ -f core ] ; then
  # Is this a core dump for some failed process?
  rm core
fi
ls -alh .
$NODE_BIN/web-ext build --overwrite-dest
ls -alh web-ext-artifacts

version=0.0.1

zip_file=browsh-$version.zip
source_dir=$PROJECT_ROOT/webext/dist/web-ext-artifacts
source_file=$source_dir/$zip_file
bundle_file=$source_dir/browsh.zip

cp -f $source_file $bundle_file

echo "Bundling $source_file to $destination using internal path $bundle_file"

XPI_FILE=$bundle_file BIN_FILE=$destination \
  $PROJECT_ROOT/interfacer/contrib/xpi2bin.sh
