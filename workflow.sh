source env.sh
tofu init
tofu apply
# wait 5 minutes
ssh ubuntu@$IP
# watch sudo salt-key -L
sudo salt '*' state.apply install_packages

ssh ubuntu@$worker_ip
sudo kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.001; do wget -q -O- http://141.72.12.185; done"
sudo kubectl port-forward svc/prometheus-server 8888:80
# local
ssh -L 8888:localhost:8888 ubuntu@$worker_ip
# open http://localhost:8888 in browser
# prometheus: kube_deployment_status_replicas{deployment="stateful-app"}

# for later: k3sup install --ip 141.72.13.201 --user ubuntu --ssh-key ~/.ssh/id_rsa --k3s-extra-args '--write-kubeconfig-mode 644'