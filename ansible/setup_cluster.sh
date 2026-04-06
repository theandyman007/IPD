#!/bin/bash

# FORGE Cluster Infrastructure Setup
# Prerequisites: See main.yml header for requirements
# Notes: 
#   - The -K prompts the user for a BECOME password; this is the user's SUDO password
#   - Add a --check flag to the command to execute WITHOUT making changes

echo "=== FORGE Cluster Infrastructure Setup ==="

echo "Step 1: Configuring /etc/hosts..."
ansible-playbook -K -i inventory.ini manage_hosts.yml

echo "Step 2: Installing Docker, NVIDIA Toolkit, and K3s..."
ansible-playbook -K -i inventory.ini main.yml

echo "=== Infrastructure setup complete ==="