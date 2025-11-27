#!/bin/bash

# This script finds the latest successful workflow run artifacts for a PR commit.
# 
# Required environment variables:
#   REPO: GitHub repository (e.g., owner/repo)
#   HEAD_SHA: The PR head commit SHA
#   CURRENT_RUN_ID: The current workflow run ID
#   ARTIFACT_NAME_PATTERN: Pattern to match artifact names (e.g., "codecov-pr-build")
#   WORKFLOW_PATHS: Comma-separated list of workflow file paths to filter by (e.g., ".github/workflows/router-ci.yaml,.github/workflows/cli-ci.yaml")
#   GITHUB_TOKEN: Required for API authentication
#
# Outputs (to $GITHUB_OUTPUT):
#   artifacts_json: JSON array of objects with run_id, artifact_id, and artifact_name
#
REPO="${REPO:?REPO environment variable is required}"
HEAD_SHA="${HEAD_SHA:?HEAD_SHA environment variable is required}"
CURRENT_RUN_ID="${CURRENT_RUN_ID:?CURRENT_RUN_ID environment variable is required}"
ARTIFACT_NAME_PATTERN="${ARTIFACT_NAME_PATTERN:?ARTIFACT_NAME_PATTERN environment variable is required}"
WORKFLOW_PATHS="${WORKFLOW_PATHS:?WORKFLOW_PATHS environment variable is required}"

echo "Head SHA: $HEAD_SHA"
echo "Current run id: $CURRENT_RUN_ID"
echo "Artifact pattern: $ARTIFACT_NAME_PATTERN"
echo "Workflow paths: $WORKFLOW_PATHS"

# Get all PR runs for this commit (since its runs per SHA 500 should be enough for now)
json=$(curl -sf \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/actions/runs?head_sha=$HEAD_SHA&event=pull_request&per_page=500")

if [ $? -ne 0 ]; then
  echo "Failed to fetch workflow runs" >&2
  exit 1
fi

# Convert comma-separated workflow paths to JSON array for jq
workflow_paths_array=$(echo "$WORKFLOW_PATHS" | jq -Rc 'split(",")')

echo "Finding runs for workflows: $workflow_paths_array"

# Find all completed & successful runs that are NOT this run and match our workflow paths
run_ids=$(echo "$json" | jq -r --arg cur "$CURRENT_RUN_ID" --argjson workflows "$workflow_paths_array" '
  .workflow_runs
  | map(select(
    .id != ($cur|tonumber)
    and .status == "completed"
    and .conclusion == "success"
    and ([.path] | inside($workflows))
  ))
  | map(.id)
  | unique
  | .[]
')

if [ -z "$run_ids" ]; then
  echo "No previous successful PR runs found for $HEAD_SHA matching specified workflows" >&2
  exit 1
fi

echo "Found run IDs: $run_ids"

# Collect all matching artifacts from all runs
all_artifacts="[]"

for run_id in $run_ids; do
  echo "Fetching artifacts for run id: $run_id"
  
  # Get artifacts for that run
  artifacts_json=$(curl -s \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/actions/runs/$run_id/artifacts")
  
  # Find all artifacts matching the pattern
  matching_artifacts=$(echo "$artifacts_json" | jq --arg pattern "$ARTIFACT_NAME_PATTERN" --arg run "$run_id" '
    .artifacts
    | map(select((.name | contains($pattern)) and .expired == false))
    | map({
        run_id: ($run | tonumber),
        artifact_id: .id,
        artifact_name: .name,
        created_at: .created_at
      })
  ')
  
  # Merge with collected artifacts
  all_artifacts=$(echo "$all_artifacts" | jq --argjson new "$matching_artifacts" '. + $new')
done

# Sort by created_at and ensure we have at least one artifact
artifact_count=$(echo "$all_artifacts" | jq 'length' 2>/dev/null || echo "0")

if [ -z "$artifact_count" ] || [ "$artifact_count" -eq 0 ]; then
  echo "No non-expired artifacts matching pattern '$ARTIFACT_NAME_PATTERN' found" >&2
  echo "All artifacts JSON: $all_artifacts" >&2
  exit 1
fi

echo "Found $artifact_count matching artifacts"

# Output the JSON array
echo "$all_artifacts" | jq -c 'sort_by(.created_at)'

# Write to GitHub output as a single-line JSON string
artifacts_output=$(echo "$all_artifacts" | jq -c 'sort_by(.created_at)')
echo "artifacts_json=$artifacts_output" >> "$GITHUB_OUTPUT"
