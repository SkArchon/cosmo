#!/bin/bash

json=$(curl -s \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/SkArchon/cosmo/actions/runs?head_sha=420d7ade7b9687c22e931be68f43a6b2114dfb72&event=pull_request&per_page=50")

CURRENT_RUN_ID=6767

run_id=$(echo "$json" | jq -r --arg cur "$CURRENT_RUN_ID" '
  .workflow_runs
  | map(select(
      .id != ($cur|tonumber)
      and .status == "completed"
      and .conclusion == "success"
      and .path == ".github/workflows/cli-ci.yaml"
    ))
  | sort_by(.created_at)
  | last
  | .id
')

echo "Current run ID: $run_id"