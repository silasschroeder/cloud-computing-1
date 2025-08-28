# Global Counter Application

Eine Node.js Express-Anwendung für Kubernetes-Deployment mit globalem Counter über NFS-Shared Storage.

## 📁 Struktur

- `server.js` - Haupt-Express-Server mit Counter-Logik
- `package.json` - NPM-Dependencies und Scripts
- `Dockerfile` - Container-Definition für Kubernetes

## 🚀 Features

- **Globaler Counter**: Shared Storage zwischen allen Pods
- **Health Checks**: `/health` und Kubernetes Probes
- **API Endpoints**: `/api/counter` für JSON-Daten
- **Reset Funktion**: Counter zurücksetzen über `/reset`
- **Responsive UI**: Moderne Web-Oberfläche mit Auto-Refresh

## 🔧 Environment Variables

- `PORT` - Server Port (default: 3000)
- `DATA_DIR` - Shared Data Directory (default: /shared-data)
- `APP_VERSION` - Application Version (injected by deployment)

## 📊 Endpoints

- `GET /` - Haupt-Counter-Seite
- `GET /health` - Health Check (JSON)
- `GET /api/counter` - Counter API (JSON)
- `GET /reset` - Counter zurücksetzen

## 🛠️ Development

```bash
# Dependencies installieren
npm install

# Server starten
npm start

# oder direkt
node server.js
```

## 🐳 Docker

```bash
# Build
docker build -t global-counter-app .

# Run
docker run -p 3000:3000 -v /shared-data:/shared-data global-counter-app
```

## ☸️ Kubernetes

Die App wird automatisch über das `deploy_version.sh` Script deployt, welches:
- ConfigMap mit App-Source erstellt
- NFS-Volume für shared storage mountet
- Health Checks konfiguriert
- Environment Variables setzt