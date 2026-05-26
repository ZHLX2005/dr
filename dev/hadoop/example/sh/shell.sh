#!/bin/sh
cd "$(dirname "$0")/../.." || exit 1
docker-compose exec hadoop-all-in-one sh
