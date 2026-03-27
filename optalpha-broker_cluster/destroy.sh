echo "Cleaning ..."

# Navigate to the deployment directory
# Note: Ensure this directory exists relative to where you run the script
cd optalpha-broker_cluster || { echo "Directory not found! Exiting."; exit 1; }

# Delete Kubernetes configurations
kubectl delete -f Broker

kubectl delete -f Redis

kubectl delete -f another-autoscaler.yml

kubectl delete -f optalpha-deployment.yml

cd ..

# Remove the deployment directory
rm -rf /root/optalpha-broker_cluster

# Uninstall K3s
/usr/local/bin/k3s-uninstall.sh

echo "Cleaning complete!"