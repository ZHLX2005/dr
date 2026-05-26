#!/bin/sh
cd "$(dirname "$0")/../.." || exit 1
docker-compose up -d
