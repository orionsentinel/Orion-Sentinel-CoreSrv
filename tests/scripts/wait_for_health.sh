#!/usr/bin/env bash
# wait_for_health.sh - Wait for Docker containers to become healthy
#
# Usage: wait_for_health.sh <compose-file> <timeout-seconds>

set -euo pipefail

COMPOSE_FILE="${1:-docker-compose.yml}"
TIMEOUT="${2:-300}"
CHECK_INTERVAL=5

echo "⏳ Waiting for containers to become healthy..."
echo "   Compose file: $COMPOSE_FILE"
echo "   Timeout: ${TIMEOUT}s"
echo ""

start_time=$(date +%s)

# Get list of running containers from this compose file
get_running_containers() {
    docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null | \
        jq -r 'select(.State == "running") | .Name' 2>/dev/null || true
}

# Check if a container is healthy
check_container_health() {
    local container="$1"
    local health_status
    
    # Get health status - if no healthcheck, consider it healthy
    health_status=$(docker inspect "$container" --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' 2>/dev/null || echo "unknown")
    
    echo "$health_status"
}

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $TIMEOUT ]; then
        echo ""
        echo "❌ Timeout after ${TIMEOUT}s"
        echo ""
        echo "Container status:"
        docker compose -f "$COMPOSE_FILE" ps
        exit 1
    fi
    
    containers=$(get_running_containers)
    
    if [ -z "$containers" ]; then
        echo "⚠️  No running containers found"
        sleep $CHECK_INTERVAL
        continue
    fi
    
    all_healthy=true
    unhealthy_count=0
    healthy_count=0
    no_healthcheck_count=0
    
    while IFS= read -r container; do
        if [ -z "$container" ]; then
            continue
        fi
        
        status=$(check_container_health "$container")
        
        case "$status" in
            healthy)
                healthy_count=$((healthy_count + 1))
                ;;
            no-healthcheck)
                # Containers without healthchecks are considered OK if running
                no_healthcheck_count=$((no_healthcheck_count + 1))
                ;;
            starting)
                all_healthy=false
                unhealthy_count=$((unhealthy_count + 1))
                ;;
            unhealthy)
                all_healthy=false
                unhealthy_count=$((unhealthy_count + 1))
                echo "  ⚠️  $container is unhealthy"
                ;;
            *)
                all_healthy=false
                unhealthy_count=$((unhealthy_count + 1))
                ;;
        esac
    done <<< "$containers"
    
    if $all_healthy; then
        echo ""
        echo "✅ All containers are healthy!"
        echo "   Healthy: $healthy_count"
        echo "   No healthcheck: $no_healthcheck_count"
        echo "   Elapsed: ${elapsed}s"
        exit 0
    fi
    
    echo "⏳ ${elapsed}s | Healthy: $healthy_count | No HC: $no_healthcheck_count | Waiting: $unhealthy_count"
    sleep $CHECK_INTERVAL
done
