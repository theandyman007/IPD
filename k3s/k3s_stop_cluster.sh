#!/bin/bash
#*******************************************************************************
# Stop Forge Lightweight Kubernetes (K3s) cluster pods
# 
# Purpose:  Shuts down all running K3s cluster pods
# Usage:    ./k3s_stop_cluster.sh
#
# Author:
#   Emily D. Carpenter
#   Anderson College of Business and Computing, Regis University
#   MSDS 696/S71: Data Science Practicum II
#   Dr. Douglas Hart, Dr. Kellen Sorauf
#   Practicum II, February-May 2026
#*******************************************************************************

# Change directory to script folder
cd "$(dirname "$0")"

echo "=== Stopping FORGE containers ==="
kubectl delete -f manifests/forge-db.yml
kubectl delete -f manifests/forge-db-storage.yml
echo ""

echo "Stopping Ollama containers..."
kubectl delete -f manifests/ollama-copper.yml 2>/dev/null
kubectl delete -f manifests/ollama-iron.yml 2>/dev/null
kubectl delete -f manifests/ollama-nickel.yml 2>/dev/null
kubectl delete -f manifests/ollama-platinum.yml 2>/dev/null
kubectl delete -f manifests/ollama-tungsten.yml 2>/dev/null
kubectl delete -f manifests/ollama-zinc.yml 2>/dev/null

kubectl get pods
echo "=== FORGE containers stopped ==="

echo "NOTE: PostgreSQL data is preserved/retained at /var/lib/forge/postgres."