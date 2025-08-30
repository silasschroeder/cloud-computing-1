source env.sh
tofu init
tofu apply -auto-approve

############################################################
#                        Prometheus                        #
############################################################

sudo kubectl port-forward --address 0.0.0.0 svc/prometheus-server 8888:80

# open master_ip:8888 in browser
# switch to "Graph" tab
# enter query: kube_deployment_status_replicas{deployment="stateful-app"} + press enter

############################################################
#                  horizontal scalability                  #
############################################################

# check horizontal scalability
sudo kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.0001; do wget -q -O- http://$(ip -o -4 addr show dev ens3 | awk '{print $4}' | cut -d/ -f1); done"

# in another terminal

watch sudo kubectl get hpa # check stress level
watch sudo kubectl get pods # check pod count 
# press "Enter" within prometheus behind the added query to update the graph (3 -> 4)

