#!/bin/sh

apt-get install -y curl
curl https://omnitruck.chef.io/install.sh | sudo bash -s -- -p -P chef -v 12.7.2
