#!/usr/bin/env bash

# Variables
declare REGION=""
declare CLUSTER_NAME=""
declare OUTPUT=""
declare SUBCOMMAND=""
declare ACTION=""
declare OTHER_ARGS=""

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
    --)
      OTHER_ARGS="$1"
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


CACHE_FILE=${HOME}/.kube/cache/aws-${CLUSTER_NAME}.token.json
# Re genereate the token if the expiration time is less than 30 seconds
RE_AUTH_TIME=30

if [ -f "$CACHE_FILE" ]; then
  # file age in seconds = current_time - file_modification_time.
  token_expiration=$(jq -r .status.expirationTimestamp "$CACHE_FILE")
  token_expiration_epoch=$(date -u -juf "%Y-%m-%dT%H:%M:%SZ" "$token_expiration" +%s)
  token_life_remaining=$(("$token_expiration_epoch" - $(date +%s)))
  if [[ $token_life_remaining -gt $RE_AUTH_TIME ]]; then
    cat "${CACHE_FILE}"
  else
    aws --region "$REGION" "$SUBCOMMAND" "$ACTION" --cluster-name "$CLUSTER_NAME" --output "$OUTPUT" "$OTHER_ARGS" | tee "$CACHE_FILE"
  fi
else
  aws --region "$REGION" "$SUBCOMMAND" "$ACTION" --cluster-name "$CLUSTER_NAME" --output "$OUTPUT" "$OTHER_ARGS" | tee "$CACHE_FILE"
fi
