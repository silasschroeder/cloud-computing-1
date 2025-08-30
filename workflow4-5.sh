k3sup install --ip 141.72.13.246 --user ubuntu --ssh-key ~/.ssh/id_rsa --cluster --k3s-extra-args '--write-kubeconfig-mode 644'
k3sup join --ip 141.72.13.196 --user ubuntu --ssh-key ~/.ssh/id_rsa --server-ip 141.72.13.246
k3sup join --ip 141.72.13.58 --user ubuntu --ssh-key ~/.ssh/id_rsa --server-ip 141.72.13.246

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

helm install strimzi strimzi/strimzi-kafka-operator
helm install keda kedacore/keda # SCALER

kubectl apply -f https://raw.githubusercontent.com/silasschroeder/files/main/task_5/kafka.yaml
kubectl apply -f https://raw.githubusercontent.com/silasschroeder/files/main/task_5/faust.yaml
kubectl apply -f https://raw.githubusercontent.com/silasschroeder/files/main/task_5/web.yaml

kubectl apply -f stress.yaml