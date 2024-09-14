#!/bin/bash

docker build . -t proxmox-buildenv
docker run -v $(pwd):/env -ti proxmox-buildenv /env/build_inner.sh

