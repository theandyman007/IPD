#!/bin/bash

# FORGE K3s Container Deployment
# Prerequisites: Run setup_cluster.sh first

echo "=== FORGE K3s Deployment ==="

echo "Deploying ForgeDB..."
kubectl apply -f forge-db.yml
echo "=== Database deployed ==="

echo "Verifying deployment..."
kubectl get pods
kubectl get services

# Deploy Ollama nodes individually as needed:
# kubectl apply -f ollama-tungsten.yml
# kubectl apply -f ollama-iron.yml
# kubectl apply -f ollama-copper.yml

echo ""
echo "=== Deployment complete ==="

echo ""
echo "To launch a FORGE code container for interactive use:"
echo "  ./forge-shell.sh"