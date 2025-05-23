#!/bin/bash

set -e

# Download and install pixlet.
PIXLET_VERSION=$(cat ./PIXLET_VERSION)
curl -LO "https://github.com/tronbyt/pixlet/releases/download/${PIXLET_VERSION}/pixlet_${PIXLET_VERSION}_linux_amd64.tar.gz"
sudo tar -C /usr/local/bin -xvf "pixlet_${PIXLET_VERSION}_linux_amd64.tar.gz"
rm "pixlet_${PIXLET_VERSION}_linux_amd64.tar.gz"