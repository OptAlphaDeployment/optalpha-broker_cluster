#!/bin/bash

# Update and clean the system
echo "Updating system packages..."
sudo apt update -y && sudo apt upgrade -y
sudo apt autoremove -y

# Configure Firewall
echo "Disabling UFW..."
sudo ufw disable
sudo ufw status

# Wait a moment
sleep 10

# Install K3s (Version v1.33.9+k3s1)
echo "Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.33.9+k3s1" sh -

# Wait a moment for K3s to initialize and generate the node token/config
sleep 10

# Navigate to the deployment directory
# Note: Ensure this directory exists relative to where you run the script
cd optalpha-broker_cluster || { echo "Directory not found! Exiting."; exit 1; }

# Apply Kubernetes configurations
echo "Applying Kubernetes deployments..."
kubectl apply -f optalpha-deployment.yml
kubectl apply -f another-autoscaler.yml
kubectl apply -f Redis
kubectl apply -f Broker

echo "Deployment complete!"