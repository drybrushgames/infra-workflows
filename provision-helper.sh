#!/usr/bin/env bash
set -euo pipefail

# Helper script to run provision workflows
# This temporarily makes the infra-workflows repo public to allow reusable workflows to work on GitHub free plan

REPO="drybrushgames/infra-workflows"
SERVICE="${1:-}"
TYPE="${2:-}"
MODE="${3:-tcp}"
PORT="${4:-8080}"

if [ -z "$SERVICE" ] || [ -z "$TYPE" ]; then
  echo "Usage: $0 <service-name> <type> [mode] [port]"
  echo "  service-name: Name of the service repository (e.g., menagerie, pirateplunder)"
  echo "  type: Service type (node|go|python)"
  echo "  mode: Connection mode (tcp|socket) - default: tcp"
  echo "  port: Service port if mode=tcp - default: 8080"
  echo ""
  echo "Example: $0 menagerie go tcp 8080"
  exit 1
fi

echo "🔓 Making infra-workflows public temporarily..."
gh api -X PATCH "repos/$REPO" -f private=false > /dev/null

echo "⏳ Waiting for GitHub to process visibility change..."
sleep 3

echo "🚀 Triggering provision workflow for $SERVICE..."
gh workflow run provision.yml \
  --repo "drybrushgames/$SERVICE" \
  -f "type=$TYPE" \
  -f "mode=$MODE" \
  -f "port=$PORT"

echo "⏳ Waiting for workflow to start..."
sleep 15

echo "📊 Checking workflow status..."
RUN_ID=$(gh run list --repo "drybrushgames/$SERVICE" --workflow=provision.yml --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -n "$RUN_ID" ]; then
  echo "✅ Workflow started with run ID: $RUN_ID"
  echo "📎 View at: https://github.com/drybrushgames/$SERVICE/actions/runs/$RUN_ID"
  
  echo "⏳ Waiting for workflow to complete (max 5 minutes)..."
  for i in {1..30}; do
    STATUS=$(gh run view "$RUN_ID" --repo "drybrushgames/$SERVICE" --json status --jq '.status' 2>/dev/null || echo "unknown")
    if [ "$STATUS" = "completed" ]; then
      CONCLUSION=$(gh run view "$RUN_ID" --repo "drybrushgames/$SERVICE" --json conclusion --jq '.conclusion')
      if [ "$CONCLUSION" = "success" ]; then
        echo "✅ Workflow completed successfully!"
      else
        echo "❌ Workflow failed with conclusion: $CONCLUSION"
        echo "Check logs at: https://github.com/drybrushgames/$SERVICE/actions/runs/$RUN_ID"
      fi
      break
    fi
    echo -n "."
    sleep 10
  done
  echo ""
else
  echo "⚠️ Could not find workflow run ID"
fi

echo "🔒 Making infra-workflows private again..."
gh api -X PATCH "repos/$REPO" -f private=true > /dev/null

echo "✅ Done! Repository is private again."