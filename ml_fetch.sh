#!/bin/bash

# --- Configuration ---
# An array of the conference YAML file names (without the .yml extension)
CONFS=("iclr" "icml" "nips")
BASE_URL="https://raw.githubusercontent.com/ccfddl/ccf-deadlines/refs/heads/main/conference/AI"

# File paths
CACHE_DIR="./ML_Big3_Countdown"
CACHE_FILE="$CACHE_DIR/ml_data.json"
TMP_FILE=$(mktemp)

# Path to your yq executable. Change this if 'yq' is not in your system's PATH.
YQ_PATH="/opt/homebrew/bin/yq"

# --- Sanity Checks ---
# 1. Ensure yq is available
if ! command -v "$YQ_PATH" &> /dev/null; then
    # Fallback to checking if yq is in the standard PATH
    if command -v yq &> /dev/null; then
        YQ_PATH="yq"
    else
        echo "❌ Error: 'yq' command not found. Please install it or update the YQ_PATH variable."
        exit 1
    fi
fi

# 2. Ensure the cache directory exists
mkdir -p "$CACHE_DIR"

# --- Cache Update Logic ---
# Update the cache if it's older than 7 days or doesn't exist.
if [ ! -f "$CACHE_FILE" ] || find "$CACHE_FILE" -mtime +7 | grep -q .; then
    echo "Cache is old or missing. Fetching new conference data... ⏳"

    # Clear the temporary file before use
    > "$TMP_FILE"

    # Loop through each conference, fetch its data, and process it.
    for conf_name in "${CONFS[@]}"; do
        echo "  -> Fetching and processing ${conf_name}..."
        curl -sL "${BASE_URL}/${conf_name}.yml" | \
        "$YQ_PATH" -o=json | \
        jq -c '.[0] as $parent | .[0].confs[] | {name: $parent.title, year: .year, deadline: (.timeline[]? | select(has("deadline"))).deadline, date: .date, place: .place, timezone: (.timezone // "UTC"), source: "ML"} | select(.deadline != null)' >> "$TMP_FILE"
    done

    # Now, process the stream of all conference instances stored in the temp file.
    jq -s '
        group_by(.name)
        | map(sort_by(.year) | reverse | .[0])
    ' "$TMP_FILE" > "$CACHE_FILE"

    # --- Cleanup ---
    rm "$TMP_FILE"
    echo "✅ Cache updated successfully!"
fi

# --- Output ---
# Display the final, cached JSON data.
cat "$CACHE_FILE"