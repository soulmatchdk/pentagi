#!/usr/bin/env bash
set -euo pipefail

BASE="docker-compose.yml"
OUT="docker-compose.coolify.yml"

cp "$BASE" "$OUT"

# --- Add neo4j_data volume (before networks:) if not present
if ! grep -qE '^[[:space:]]*neo4j_data:[[:space:]]*$' "$OUT"; then
  awk '
    BEGIN {added=0}
    /^networks:[[:space:]]*$/ && added==0 {
      print "  neo4j_data:"
      print "    driver: local"
      added=1
    }
    {print}
  ' "$OUT" > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"
fi

# --- Insert neo4j + graphiti right after services: if not present
if ! grep -qE '^[[:space:]]*neo4j:[[:space:]]*$' "$OUT"; then
  awk '
    BEGIN {inserted=0}
    /^services:[[:space:]]*$/ && inserted==0 {
      print
      print "  neo4j:"
      print "    image: neo4j:5.26.2"
      print "    restart: unless-stopped"
      print "    container_name: neo4j"
      print "    hostname: neo4j"
      print "    healthcheck:"
      print "      test: [\"CMD-SHELL\", \"wget -qO- http://localhost:7474 || exit 1\"]"
      print "      interval: 1s"
      print "      timeout: 10s"
      print "      retries: 10"
      print "      start_period: 3s"
      print "    ports:"
      print "      - \"127.0.0.1:7474:7474\""
      print "      - \"127.0.0.1:7687:7687\""
      print "    logging:"
      print "      options:"
      print "        max-size: 50m"
      print "        max-file: \"7\""
      print "    volumes:"
      print "      - neo4j_data:/data"
      print "    environment:"
      print "      - NEO4J_AUTH=${NEO4J_USER:-neo4j}/${NEO4J_PASSWORD:-devpassword}"
      print "    networks:"
      print "      - pentagi-network"
      print "    shm_size: 4g"
      print ""
      print "  graphiti:"
      print "    image: vxcontrol/graphiti:latest"
      print "    restart: unless-stopped"
      print "    container_name: graphiti"
      print "    hostname: graphiti"
      print "    healthcheck:"
      print "      test: [\"CMD\", \"python\", \"-c\", \"import urllib.request; urllib.request.urlopen(\\\"http://localhost:8000/healthcheck\\\")\"]"
      print "      interval: 10s"
      print "      timeout: 5s"
      print "      retries: 3"
      print "    depends_on:"
      print "      neo4j:"
      print "        condition: service_healthy"
      print "    ports:"
      print "      - \"127.0.0.1:8000:8000\""
      print "    logging:"
      print "      options:"
      print "        max-size: 50m"
      print "        max-file: \"7\""
      print "    environment:"
      print "      - NEO4J_URI=${NEO4J_URI:-bolt://neo4j:7687}"
      print "      - NEO4J_USER=${NEO4J_USER:-neo4j}"
      print "      - NEO4J_DATABASE=${NEO4J_DATABASE:-neo4j}"
      print "      - NEO4J_PASSWORD=${NEO4J_PASSWORD:-devpassword}"
      print "      - MODEL_NAME=${GRAPHITI_MODEL_NAME:-gpt-5-mini}"
      print "      - OPENAI_BASE_URL=${OPEN_AI_SERVER_URL:-https://api.openai.com/v1}"
      print "      - OPENAI_API_KEY=${OPEN_AI_KEY:-}"
      print "      - PORT=8000"
      print "    networks:"
      print "      - pentagi-network"
      inserted=1
      next
    }
    {print}
  ' "$OUT" > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"
fi

# Start with merged compose
docker compose -f "$OUT" pull
docker compose -f "$OUT" up -d --remove-orphans
