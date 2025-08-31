#####################################################################################
#                                 PREREQUISITES                                     #
# - Reduce master.sh and worker.sh to K3s cluster setup                             #
# - Run Task 1 commands again to create a k8s cluster clean of previous software    #
#####################################################################################
# ON MASTER NODE

# INSTALL HELM
wget https://get.helm.sh/helm-v3.18.3-linux-amd64.tar.gz
tar xzf helm-v3.18.3-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/sbin
rm -rf linux-amd64
rm helm-v3.18.3-linux-amd64.tar.gz

# CONFIG HELM ACCESS
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
source ~/.bashrc

# HELM REPOS
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add kedacore https://kedacore.github.io/charts
helm repo add strimzi http://strimzi.io/charts/
helm repo add dask https://helm.dask.org/
helm repo update

############################################################
#                          TASK 4                          #
############################################################
# ON MASTER NODE

# HELM INITS
helm install minio bitnami/minio -f https://raw.githubusercontent.com/silasschroeder/files/main/task_4/minio.yaml
helm install dask dask/dask -f https://raw.githubusercontent.com/silasschroeder/files/main/task_4/dask.yaml

# MC
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
mc alias set pfisterer http://localhost:32001 minioadmin minioadminpassword

# MINIO STORAGE SHOWCASE
mc ls pfisterer/
mc ls pfisterer/breastcancer-data/
mc ls pfisterer/models/

# LOAD DATA
wget https://raw.githubusercontent.com/silasschroeder/files/main/task_4/wdbc.data
mc cp wdbc.data pfisterer/breastcancer-data/

# SHOW DATA IS LOADED
mc ls pfisterer/breastcancer-data/

# DATA TRANSFORMATION (training of naive bayes model)
kubectl apply -f https://raw.githubusercontent.com/silasschroeder/files/main/task_4/job.yaml

# SHOW RESULTS
mc ls pfisterer/models/
mc cat pfisterer/models/naive_bayes_params.json

############################################################
#                          TASK 5                          #
############################################################
# ON MASTER NODE

helm install strimzi strimzi/strimzi-kafka-operator
helm install keda kedacore/keda # SCALER

kubectl apply -f https://raw.githubusercontent.com/silasschroeder/files/main/task_5/kafka.yaml
kubectl apply -f https://raw.githubusercontent.com/silasschroeder/files/main/task_5/faust.yaml
kubectl apply -f https://raw.githubusercontent.com/silasschroeder/files/main/task_5/web.yaml

kubectl apply -f https://raw.githubusercontent.com/silasschroeder/files/main/task_5/stress.yaml