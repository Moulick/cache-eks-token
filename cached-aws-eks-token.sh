#!/usr/bin/env bash

# Wrapper for `aws eks get-token` that caches Kubernetes exec credentials per EKS cluster, region, and AWS profile.
# This avoids repeatedly generating fresh tokens and significantly increase kubectl performance.
# This script preserves kubectl-compatible cache directory permissions and owner-only token file permissions.

# Initialize variables
declare REGION=""
declare CLUSTER_NAME=""
declare OUTPUT=""
declare SUBCOMMAND=""
declare ACTION=""

# Loop through arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)
      REGION="$2"
      shift 2
      ;;
    --cluster-name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    eks | get-token)
      # Save positional/subcommand arguments
      if [[ -z "$SUBCOMMAND" ]]; then
        SUBCOMMAND="$1"
      else
        ACTION="$1"
      fi
      shift
      ;;
    *)
      echo "Unknown option or argument: $1"
      exit 1
      ;;
  esac
done

# echo "Region: $REGION"
# echo "Cluster Name: $CLUSTER_NAME"
# echo "Output: $OUTPUT"
# echo "Subcommand: $SUBCOMMAND"
# echo "Action: $ACTION"


readonly CACHE_DIR="${HOME}/.kube/cache"
readonly CACHE_FILE="${CACHE_DIR}/eks-${CLUSTER_NAME}-${REGION}-${AWS_PROFILE:-default}.token.json"

# If the cache directory does not exist, create it with the correct permissions, same as kubectl
if [[ ! -d "$CACHE_DIR" ]]; then
  mkdir -m 750 "$CACHE_DIR" || exit 1
else
  # For machines that made the folder with an older version of this script, change the permissions to 750, same as kubectl default.
  # Try darwin then linux `stat` command
  CACHE_DIR_PERMISSIONS=$(stat -f "%Lp" "$CACHE_DIR" 2>/dev/null || stat -c "%a" "$CACHE_DIR") || exit 1
  if [[ "$CACHE_DIR_PERMISSIONS" != "750" ]]; then
    chmod 750 "$CACHE_DIR" || exit 1
  fi
fi

# Regenerate the token if the token is going to expire in less than 30 seconds
# If the cache file is a symlink, do not use it for security reasons, open a github issue if this is a problem for you.
if [[ -f "$CACHE_FILE" && ! -L "$CACHE_FILE" && -s "$CACHE_FILE" ]]; then
  EXPIRATION=$(jq -r .status.expirationTimestamp "$CACHE_FILE")
  case "$OSTYPE" in
    darwin*)
      TIME_REFRESH=$(date -u -v+30S +%Y-%m-%dT%H:%M:%SZ) # macOS/BSD syntax
      ;;
    linux*)
      TIME_REFRESH=$(date -u -d '+30 seconds' +%Y-%m-%dT%H:%M:%SZ) # Linux/GNU syntax
      ;;
    *)
      echo "Unsupported OSTYPE: $OSTYPE" >&2
      exit 1
      ;;
  esac

  # If the token is not going to expire in less than 30 seconds, cat the cached token to caller right away.
  if [[ $EXPIRATION > $TIME_REFRESH ]]; then
    cat "${CACHE_FILE}"
    exit 0
  fi
fi

# Change the permissions of the cache file to rw------- before refreshing it.
# This is needed for token files created with an older version of this script.
if [[ -f "$CACHE_FILE" && ! -L "$CACHE_FILE" ]]; then
  CACHE_FILE_PERMISSIONS=$(stat -f "%Lp" "$CACHE_FILE" 2>/dev/null || stat -c "%a" "$CACHE_FILE") || exit 1
  if [[ "$CACHE_FILE_PERMISSIONS" != "600" ]]; then
    chmod 600 "$CACHE_FILE" || exit 1
  fi
fi

# Run the aws cli, write the token to the token cache file with rw------- permissions and also return it to caller right away.
aws --region "$REGION" "$SUBCOMMAND" "$ACTION" --cluster-name "$CLUSTER_NAME" --output "$OUTPUT" | (umask 077; tee "$CACHE_FILE")
