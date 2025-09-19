#!/bin/sh
set -e

echo "[INFO] Starting Zabbix original entrypoint in background..."
/usr/bin/docker-entrypoint.sh "$@" &

# Wait for Zabbix Web UI to be ready
echo "[INFO] Waiting for Zabbix Web to be ready..."
until curl -s http://localhost:8080/ > /dev/null; do
  sleep 5
done
echo "[INFO] Zabbix Web is up."

# Authenticate to Zabbix API (user.login)
API_URL="http://localhost:8080/api_jsonrpc.php"
AUTH=""

echo "[INFO] Authenticating to Zabbix API..."
until [ -n "$AUTH" ] && [ "$AUTH" != "null" ]; do
  AUTH=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{
          "jsonrpc": "2.0",
          "method": "user.login",
          "params": {
            "username": "Admin",
            "password": "zabbix"
          },
          "id": 1
        }' "$API_URL" | jq -r '.result')
  if [ -z "$AUTH" ] || [ "$AUTH" = "null" ]; then
    echo "[INFO] Waiting for API auth..."
    sleep 5
  fi
done
echo "[INFO] Got API token: $AUTH"

# Prepare minimal dashboard payload
DASHBOARD_PAYLOAD=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "method": "dashboard.create",
  "params": {
    "name": "Custom Monitoring Dashboard",
    "display_period": 30,
    "auto_start": 1,
    "pages": [
      {
        "widgets": [
          {
            "type": "problems",
            "x": 0,
            "y": 0,
            "width": 36,
            "height": 5,
            "view_mode": 0
          }
        ]
      }
    ]
  },
  "id": 1
}
EOF
)

# Create dashboard using Bearer token
echo "[INFO] Creating custom dashboard..."
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH" \
  -d "$DASHBOARD_PAYLOAD" \
  "$API_URL")
echo "[INFO] Dashboard creation response: $RESPONSE"

# Check if dashboard creation succeeded
if echo "$RESPONSE" | jq -e '.result.dashboardids[0]' > /dev/null 2>&1; then
  DASHBOARD_ID=$(echo "$RESPONSE" | jq -r '.result.dashboardids[0]')
  echo "[SUCCESS] Dashboard created with ID: $DASHBOARD_ID"
else
  echo "[ERROR] Failed to create dashboard: $RESPONSE"
fi

# Wait for the original entrypoint process to keep container alive
wait
