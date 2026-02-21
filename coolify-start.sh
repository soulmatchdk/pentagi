#!/usr/bin/env bash
set -euo pipefail

export COMPOSE_PROJECT_NAME=os4s8scwcccs0ok88gko44kk

docker compose -f docker-compose.yml -f docker-compose-graphiti.yml pull
docker compose -f docker-compose.yml -f docker-compose-graphiti.yml up -d --remove-orphans
