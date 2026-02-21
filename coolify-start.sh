#!/usr/bin/env bash
set -euo pipefail

# Lav en merged compose-fil ud fra upstream docker-compose.yml
cp docker-compose.yml docker-compose.coolify.yml

# Tilføj neo4j_data volume hvis den mangler
if ! grep -qE '^\s*neo4j_data:\s*$' docker-compose.coolify.yml; then
  perl -0777 -i -pe 's/(volumes:\n(?:[^\n]*\n)+?)(networks:\n)/$1  neo4j_data:\n    driver: local\n$2/s' docker-compose.coolify.yml
fi

# Indsæt services neo4j + graphiti hvis de ikke allerede er der
if ! grep -qE '^\s*neo4j:\s*$' docker-compose.coolify.yml; then
  perl -0777 -i -pe 's/(\nservices:\n)/$1  neo4j:\n    image: neo4j:5.26.2\n    restart: unless-stopped\n    container_name: neo4j\n    hostname: neo4j\n    healthcheck:\n      test: [\"CMD-SHELL\", \"wget -qO- http:\\/\\/localhost:7474 || exit 1\"]\n      interval: 1s\n      timeout: 10s\n      retries: 10\n      start_period: 3s\n    ports:\n      - \"127.0.0.1:7474:7474\"\n      - \"127.0.0.1:7687:7687\"\n    logging:\n      options:\n        max-size: 50m\n        max-file: \"7\"\n    volumes:\n      - neo4j_data:\\/data\n    environment:\n      - NEO4J_AUTH=${NEO4J_USER:-neo4j}\\/${NEO4J_PASSWORD:-devpassword}\n    networks:\n      - pentagi-network\n    shm_size: 4g\n\n  graphiti:\n    image: vxcontrol\\/graphiti:latest\n    restart: unless-stopped\n    container_name: graphiti\n    hostname: graphiti\n    healthcheck:\n      test: [\"CMD\", \"python\", \"-c\", \"import urllib.request; urllib.request.urlopen(\\x27http:\\/\\/localhost:8000\\/healthcheck\\x27)\"]\n      interval: 10s\n      timeout: 5s\n      retries: 3\n    depends_on:\n      neo4j:\n        condition: service_healthy\n    ports:\n      - \"127.0.0.1:8000:8000\"\n    logging:\n      options:\n        max-size: 50m\n        max-file: \"7\"\n    environment:\n      - NEO4J_URI=${NEO4J_URI:-bolt:\\/\\/neo4j:7687}\n      - NEO4J_USER=${NEO4J_USER:-neo4j}\n      - NEO4J_DATABASE=${NEO4J_DATABASE:-neo4j}\n      - NEO4J_PASSWORD=${NEO4J_PASSWORD:-devpassword}\n      - MODEL_NAME=${GRAPHITI_MODEL_NAME:-gpt-5-mini}\n      - OPENAI_BASE_URL=${OPEN_AI_SERVER_URL:-https:\\/\\/api.openai.com\\/v1}\n      - OPENAI_API_KEY=${OPEN_AI_KEY:-}\n      - PORT=8000\n    networks:\n      - pentagi-network\n\n/s' docker-compose.coolify.yml
fi

docker compose -f docker-compose.coolify.yml pull
docker compose -f docker-compose.coolify.yml up -d --remove-orphans
