---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sample-app-pv
  labels:
    type: nfs
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  nfs:
    path: /mnt/data
    server: ${master_ip} # Will be replaced by Terraform
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sample-app-data-pvc
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-web-app
  labels:
    app: sample-web-app
    version: ${app_version}
spec:
  replicas: ${app_replicas}
  selector:
    matchLabels:
      app: sample-web-app
  template:
    metadata:
      labels:
        app: sample-web-app
        version: ${app_version}
    spec:
      containers:
        - name: sample-web-app
          image: node:16-alpine
          ports:
            - containerPort: 3000
          env:
            - name: APP_VERSION
              value: "${app_version}"
            - name: PORT
              value: "3000"
          command:
            - /bin/sh
            - -c
            - |
              cd /app
              echo '{"name":"sample-web-app","version":"${app_version}","main":"app.js","scripts":{"start":"node app.js"},"dependencies":{"express":"^4.18.2"}}' > package.json
              npm install --only=production
              cat << 'EOF' > app.js
              const express = require('express');
              const fs = require('fs');
              const path = require('path');
              
              const app = express();
              const port = process.env.PORT || 3000;
              const appVersion = process.env.APP_VERSION || '${app_version}';
              
              const dataDir = '/app/data';
              if (!fs.existsSync(dataDir)) {
                try {
                  fs.mkdirSync(dataDir, { recursive: true });
                } catch (err) {
                  console.log('Data directory already exists or cannot be created');
                }
              }
              
              app.get('/', (req, res) => {
                const timestamp = new Date().toISOString();
                
                try {
                  const logFile = path.join(dataDir, 'access.log');
                  fs.appendFileSync(logFile, timestamp + ' - Access from ' + req.ip + '\n');
                } catch (err) {
                  console.log('Could not write to persistent storage');
                }
              
                res.json({
                  message: 'Sample Web Application - Version ${app_version}',
                  version: appVersion,
                  timestamp: timestamp,
                  hostname: require('os').hostname(),
                  uptime: process.uptime()
                });
              });
              
              app.get('/health', (req, res) => {
                res.json({
                  status: 'healthy',
                  version: appVersion,
                  timestamp: new Date().toISOString()
                });
              });
              
              app.get('/version', (req, res) => {
                res.json({
                  version: appVersion,
                  build_time: new Date().toISOString()
                });
              });
              
              app.listen(port, () => {
                console.log('Sample Web App v' + appVersion + ' listening on port ' + port);
              });
              EOF
              npm start
          volumeMounts:
            - name: app-data
              mountPath: /app/data
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "200m"
              memory: "256Mi"
      volumes:
        - name: app-data
          persistentVolumeClaim:
            claimName: sample-app-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: sample-web-app-service
spec:
  selector:
    app: sample-web-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: LoadBalancer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-web-app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host:
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: sample-web-app-service
                port:
                  number: 80
---
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: sample-web-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sample-web-app
  minReplicas: ${min_replicas}
  maxReplicas: ${max_replicas}
  targetCPUUtilizationPercentage: 70