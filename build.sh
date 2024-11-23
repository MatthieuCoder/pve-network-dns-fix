#!/bin/bash

docker build . -t proxmox-buildenv --no-cache
docker run -v $(pwd):/env -ti proxmox-buildenv /env/build_inner.sh
