#!/bin/bash
set -euo pipefail

REPO="drybrushgames/infra-workflows"
SERVICE="${1:-}"

if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service-name>"
    echo "Example: $0 menagerie"
    exit 1
fi

echo "🔓 Making infra-workflows public temporarily..."
gh api -X PATCH "repos/$REPO" -f private=false > /dev/null

echo "⏳ Waiting for GitHub to process visibility change..."
sleep 3

echo "🚀 Triggering deploy workflow for $SERVICE..."
gh workflow run deploy.yml --repo "drybrushgames/$SERVICE"

echo "⏳ Waiting for workflow to start..."
sleep 5

echo "📊 Checking workflow status..."
RUN_ID=$(gh run list --repo "drybrushgames/$SERVICE" --workflow=deploy.yml --limit=1 --json=databaseId --jq='.[0].databaseId')
echo "✅ Workflow started with run ID: $RUN_ID"
echo "📎 View at: https://github.com/drybrushgames/$SERVICE/actions/runs/$RUN_ID"

echo "⏳ Waiting for workflow to complete (max 5 minutes)..."
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
    STATUS=$(gh run view $RUN_ID --repo "drybrushgames/$SERVICE" --json=status,conclusion --jq='.status + ":" + (.conclusion // "null")')
    
    if [[ "$STATUS" == "completed:success" ]]; then
        echo "✅ Workflow completed successfully!"
        break
    elif [[ "$STATUS" == "completed:failure" ]] || [[ "$STATUS" == "completed:cancelled" ]]; then
        echo "❌ Workflow failed with conclusion: $(echo $STATUS | cut -d: -f2)"
        echo "Check logs at: https://github.com/drybrushgames/$SERVICE/actions/runs/$RUN_ID"
        break
    else
        printf "."
        sleep 10
        elapsed=$((elapsed + 10))
    fi
done

if [ $elapsed -ge $timeout ]; then
    echo "⏰ Workflow timed out after 5 minutes"
fi

echo ""
echo "🔒 Making infra-workflows private again..."
gh api -X PATCH "repos/$REPO" -f private=true > /dev/null
echo "✅ Done! Repository is private again."