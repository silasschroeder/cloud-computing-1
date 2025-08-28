# Dockerfile für Simple Counter App
FROM node:18-alpine

# Arbeitsverzeichnis erstellen
WORKDIR /app

# Package.json kopieren und Dependencies installieren
COPY package*.json ./
RUN npm install --production

# App-Code kopieren
COPY app.js ./

# Data-Verzeichnis für persistenten Storage erstellen
RUN mkdir -p /app/data

# Port exposieren
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# User für Security
USER node

# App starten
CMD ["npm", "start"]