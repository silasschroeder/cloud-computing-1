############################################################
#                          TASK 1                          #
############################################################
# ON LOCAL MACHINE

source env.sh
tofu init
tofu apply -auto-approve

############################################################
#                          TASK 2                          #
############################################################
# ON LOCAL MACHINE

# TODO

############################################################
#                          TASK 3                          #
############################################################
# ON MASTER NODE

# ---------------------- Prometheus ------------------------

# ADD PROMETHEUS REPO
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# CONFIG HELM ACCESS
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
source ~/.bashrc

# INSTALL PROMETHEUS
helm install prometheus prometheus-community/prometheus

# PORT FORWARD PROMETHEUS
sudo kubectl port-forward --address 0.0.0.0 svc/prometheus-server 8888:80

# open master_ip:8888 in browser
# switch to "Graph" tab
# enter query: kube_deployment_status_replicas{deployment="stateful-app"} + press enter
# press "Enter" again to update the graph
# watch in combination with the stress test below to see the number of replicas increase

# ---------------- Horizontal Scalability ------------------

# START STRESS TEST
sudo kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.0001; do wget -q -O- http://$(ip -o -4 addr show dev ens3 | awk '{print $4}' | cut -d/ -f1); done"

# IN ANOTHER TERMINAL ON MASTER NODE
watch sudo kubectl get hpa # CHECK STRESS LEVEL
watch sudo kubectl get pods # CHECK NUMBER OF PODSh