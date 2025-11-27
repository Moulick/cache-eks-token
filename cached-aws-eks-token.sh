#!/usr/bin/env bash

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
    eks|get-token)
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

readonly CACHE_FILE="${HOME}/.kube/cache/eks-${CLUSTER_NAME}-${REGION:-${AWS_REGION:-${AWS_DEFAULT_REGION:-default}}}-${AWS_PROFILE:-default}.token.json"
[[ -d "${HOME}/.kube/cache" ]] || mkdir -p "${HOME}/.kube/cache"

# Regenerate the token if the token is going to expire in less than 30 seconds

if [ -s "$CACHE_FILE" ]; then

  EXPIRATION=$(jq -r .status.expirationTimestamp "$CACHE_FILE")

  if [[ "$OSTYPE" == "darwin"* ]]; then
    TIME_REFRESH=$(date -u -v+30S +%Y-%m-%dT%H:%M:%SZ) # macOS/BSD syntax
  else
    TIME_REFRESH=$(date -u -d '+30 seconds' +%Y-%m-%dT%H:%M:%SZ) # Linux/GNU syntax
  fi

  if [[ $EXPIRATION > $TIME_REFRESH ]]; then
    cat "${CACHE_FILE}"
    exit 0
  fi
fi

aws --region "$REGION" "$SUBCOMMAND" "$ACTION" --cluster-name "$CLUSTER_NAME" --output "$OUTPUT" | tee "$CACHE_FILE"
