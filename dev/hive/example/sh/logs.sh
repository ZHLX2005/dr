#!/bin/sh
cd "$(dirname "$0")/../.." || exit 1
docker-compose logs -f --tail=100
