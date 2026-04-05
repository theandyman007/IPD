#!/bin/bash

# Launch a FORGE code container for the current user
#
# Purpose:  Start an interactive FORGE pod with persistent results storage
# Usage:    ./forge-shell.sh

export FORGE_USER=$(whoami)

echo "Starting FORGE container for ${FORGE_USER}..."
envsubst < forge-code.yml | kubectl apply -f -

echo "Pod created. Connecting..."
kubectl exec -it forge-${FORGE_USER} -- /bin/bash

echo ""
echo "Session ended. Your results are saved in ~/forge-results/"
echo "To reconnect: kubectl exec -it forge-${FORGE_USER} -- /bin/bash"
echo "To remove:    kubectl delete pod forge-${FORGE_USER}"