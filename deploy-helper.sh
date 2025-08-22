#!/usr/bin/env bash
set -euo pipefail

# Helper script to manually trigger deploy workflows
# This temporarily makes the infra-workflows repo public to allow reusable workflows to work on GitHub free plan

REPO="drybrushgames/infra-workflows"
SERVICE="${1:-}"

if [ -z "$SERVICE" ]; then
  echo "Usage: $0 <service-name>"
  echo "  service-name: Name of the service repository (e.g., menagerie, pirateplunder, quietpm)"
  echo ""
  echo "Example: $0 menagerie"
  echo ""
  echo "Note: Deployments normally happen automatically on push to main branch."
  echo "      This script is for manual deployment triggers only."
  exit 1
fi

echo "🔓 Making infra-workflows public temporarily..."
gh api -X PATCH "repos/$REPO" -f private=false > /dev/null

echo "⏳ Waiting for GitHub to process visibility change..."
sleep 3

echo "🚀 Triggering deploy workflow for $SERVICE..."
gh workflow run deploy.yml --repo "drybrushgames/$SERVICE"

echo "⏳ Waiting for workflow to start..."
sleep 15

echo "📊 Checking workflow status..."
RUN_ID=$(gh run list --repo "drybrushgames/$SERVICE" --workflow=deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -n "$RUN_ID" ]; then
  echo "✅ Workflow started with run ID: $RUN_ID"
  echo "📎 View at: https://github.com/drybrushgames/$SERVICE/actions/runs/$RUN_ID"
  
  echo "⏳ Waiting for workflow to complete (max 3 minutes)..."
  for i in {1..18}; do
    STATUS=$(gh run view "$RUN_ID" --repo "drybrushgames/$SERVICE" --json status --jq '.status' 2>/dev/null || echo "unknown")
    if [ "$STATUS" = "completed" ]; then
      CONCLUSION=$(gh run view "$RUN_ID" --repo "drybrushgames/$SERVICE" --json conclusion --jq '.conclusion')
      if [ "$CONCLUSION" = "success" ]; then
        echo "✅ Deployment completed successfully!"
      else
        echo "❌ Deployment failed with conclusion: $CONCLUSION"
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