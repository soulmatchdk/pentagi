#!/usr/bin/env bash
set -euo pipefail

BASE="docker-compose.yml"
OUT="docker-compose.coolify.yml"

cp "$BASE" "$OUT"

# 1) Tilføj neo4j_data volume i volumes:-sektionen (ligger helt i toppen i din fil)
# Vi indsætter lige efter "pentagi-postgres-data:" blokken, som du har.
if ! grep -qE '^[[:space:]]*neo4j_data:[[:space:]]*$' "$OUT"; then
  awk '
    BEGIN {done=0}
    /^[[:space:]]*pentagi-postgres-data:[[:space:]]*$/ { print; nextline=1; next }
    (nextline==1 && done==0) {
      # print current line
      print
      # and insert right after the driver line
      if ($0 ~ /^[[:space:]]*driver:[[:space:]]*local[[:space:]]*$/) {
        print "  neo4j_data:"
        print "    driver: local"
        done=1
        nextline=0
      }
      next
    }
    { print }
  ' "$OUT" > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"
fi

# 2) Indsæt neo4j+graphiti services som et "kendt godt" YAML-stykke
# Vi indsætter lige før "pgvector:" (som findes i din fil), så vi ikke roder med services:-headere.
if ! grep -qE '^[[:space:]]*neo4j:[[:space:]]*$' "$OUT"; then
  awk '
    BEGIN {inserted=0}
    /^[[:space:]]*pgvector:[[:space:]]*$/ && inserted==0 {
      # Insert BEFORE pgvector: with same indentation as other services (2 spaces)
      print "  neo4j:"
      print "    image: neo4j:5.26.2"
      print "    restart: unless-stopped"
      print "    container_name: neo4j"
      print "    hostname: neo4j"
      print "    # Healthcheck uden wget/curl (kun bash tcp-check)"
      print "    healthcheck:"
      print "      test: [\"CMD-SHELL\", \"bash -lc </dev/tcp/localhost/7474\" ]"
      print "      interval: 5s"
      print "      timeout: 5s"
      print "      retries: 20"
      print "      start_period: 10s"
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
      print "      test: [\"CMD-SHELL\", \"python -c \\\"import urllib.request; urllib.request.urlopen(\\\\\\\"http://localhost:8000/healthcheck\\\\\\\")\\\"\" ]"
      print "      interval: 10s"
      print "      timeout: 5s"
      print "      retries: 10"
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
      print "      - MODEL_NAME=${GRAPHITI_MODEL_NAME:-minimax-m2.5-free}"
      print "      - OPENAI_BASE_URL=${OPEN_AI_SERVER_URL:-https://opencode.ai/zen/v1}"
      print "      - OPENAI_API_KEY=${OPEN_AI_KEY:-}"
      print "      - PORT=8000"
      print "    networks:"
      print "      - pentagi-network"
      print ""
      inserted=1
    }
    {print}
  ' "$OUT" > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"
fi

# 3) Debug: print last 120 lines so we can see what we generated in Coolify logs
echo "----- docker-compose.coolify.yml (tail) -----"
tail -n 120 "$OUT" || true
echo "--------------------------------------------"

# 4) Validate compose file (this will show the exact YAML error line if any)
docker compose -f "$OUT" config >/dev/null

# 5) Start stack
docker compose -f "$OUT" pull
docker compose -f "$OUT" up -d --remove-orphans
