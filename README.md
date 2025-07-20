# Cache AWS EKS Token

This is a script that is used to get a cached AWS EKS token. This speeds up all `kubectl` commands.
The speed increase for `kubectl get pods` is ~73%. It's really noticeable.

The default way is to use `aws eks get-token` command, but it is not cached and it is not very fast.
It's slow because:
1. Every kubectl command will do a `aws eks get-token` which makes an api call to AWS
2. `aws` is python. When running kubectl in a script, you can very clearly see how much performance is lost generating tokens for each kubectl invocation in Activity Monitor.


# How to use
Simply replace the `command: aws` with `command: ../cache-eks-token/cached-aws-eks-token.sh`, or whatever is the location of the script in your `~/.kube/config` files.

## How it works
This script will caches the token in a file based on cluster name in the $HOME/.kube/cache directory.
AWS issues token for at-most 15 mins. This script will check the expiry and return exisiting token.
The token will be refreshed if it's expiring within 30 seconds

## Errors

1. If you get error like `Unable to connect to the server: getting credentials: exec: fork/exec /Users/moulick.aggarwal/cache-eks-token/cached-aws-eks-token.sh: permission denied`, simply run `chmod +x cached-aws-eks-token.sh`
2. If error like `Unable to connect to the server: getting credentials: exec: fork/exec /Users/moulick.aggarwal/.kube/cache-eks-token/cached-aws-eks-token.sh: no such file or directory`, make sure to make the command path be relative to where ever the script exists. You can use `../` in the `command` to move up directories.

## Dependencies
1. jq (brew install jq)

## Limitations
Currently the script works only for MacOS aka Darwin due to the flags used for `date`. If linux support is needed, feel free to open a issue or PR.
