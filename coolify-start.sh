#!/usr/bin/env bash
set -euo pipefail

docker compose -f docker-compose.yml -f docker-compose.graphiti.yml pull
docker compose -f docker-compose.yml -f docker-compose.graphiti.yml up -d --remove-orphans
