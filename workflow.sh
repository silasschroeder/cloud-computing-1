env.sh
tofu init
tofu apply -auto-approve

# wait 3-5 min

ssh ubuntu@<master_ip>

#check if initialisation is done
cat /var/log/cloud-init-output.log # should end with "Up 1XX.XX seconds"

#check if workers are connected
sudo salt-key -L
# Expected output:
    # Accepted Keys:
    # mjcs2-k8s-master
    # mjcs2-k8s-worker-0
    # mjcs2-k8s-worker-1
    # Denied Keys:
    # Unaccepted Keys:
    # Rejected Keys:

#start master configuration
sudo salt 'mjcs2-k8s-master' state.apply master_pre-worker-setup

#configure worker setup
cat master_ip.txt # get ip
cat master_token.txt # get token

# insert ip and token into <master_ip> and <k8s_token>
# Input "I": start editing, Input "Esc": stop editing, Input ":x": save and exit 
sudo vim /srv/salt/worker_setup.sls 

sudo salt 'mjcs2-k8s-worker*' state.apply worker_setup

# instert master ip
# Input "I": start editing, Input "Esc": stop editing, Input ":x": save and exit 
sudo vim k8s-entities.yaml

sudo kubectl apply -f k8s-entities.yaml
# ---- STATEFUL APP WORKS ----

# install prometheus
sudo salt 'mjcs2-k8s-master' state.apply master_post-worker-setup # wait for pods to run
sudo kubectl port-forward --address 0.0.0.0 svc/prometheus-server 8888:80

#start new terminal
ssh -L 8888:localhost:8888 ubuntu@<master_ip>

# open in browser: localhost:8888
# switch to "Graph" tab
# enter query: kube_deployment_status_replicas{deployment="stateful-app"} + press enter
# ---- PROMETHEUS WORKS ----

# check horizontal scalability
sudo kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.0001; do wget -q -O- http://${MASTER_IP}; done"

#open new terminal
ssh ubuntu@<master_ip>

watch sudo kubectl get hpa # check stress level
watch sudo kubectl get pods # check pod count 
# 4th pod should be created after a while
# press "Enter" within prometheus behind the added query to update the graph (3 -> 4)

