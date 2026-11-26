#!/bin/bash

set -u

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR" || exit 1

echo "=================================="
echo " University Bus Tracking Startup"
echo "=================================="

# PostgreSQL
echo "[1/4] Starting PostgreSQL..."
sudo service postgresql start

# Kafka
echo "[2/4] Starting Kafka..."
if ! pgrep -f 'kafka.Kafka' >/dev/null; then
    /home/asus/kafka/bin/kafka-server-start.sh -daemon /home/asus/kafka/config/server.properties
else
    echo "Kafka already running."
fi

# Superset
echo "[3/4] Starting Superset..."
TAG=6.0.0 docker-compose -f /home/asus/superset/docker-compose-image-tag.yml up -d

# FastAPI
echo "[4/4] Starting FastAPI..."
if ! pgrep -f 'uvicorn backend.app.main:app' >/dev/null; then
    if [ -f "BUS-Tracking/bin/activate" ]; then
        source BUS-Tracking/bin/activate
    fi
    nohup uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 > backend.log 2>&1 &
else
    echo "Backend already running."
fi

# Frontend
if ! pgrep -f 'http.server 5500' >/dev/null; then
    nohup python3 -m http.server 5500 --directory frontend > frontend.log 2>&1 &
else
    echo "Frontend already running."
fi

echo ""
echo "Startup commands completed."
echo "Backend:  http://localhost:8000/docs"
echo "Frontend: http://127.0.0.1:5500"
echo "Superset: http://localhost:8088"
