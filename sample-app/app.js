const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;
const appVersion = process.env.APP_VERSION || '1.0.0';

// Create data directory if it doesn't exist
const dataDir = '/app/data';
if (fs.existsSync(dataDir)) {
  try {
    fs.mkdirSync(dataDir, { recursive: true });
  } catch (err) {
    console.log('Data directory already exists or cannot be created');
  }
}

app.get('/', (req, res) => {
  const timestamp = new Date().toISOString();
  
  // Log access to persistent storage if available
  try {
    const logFile = path.join(dataDir, 'access.log');
    fs.appendFileSync(logFile, `${timestamp} - Access from ${req.ip}\n`);
  } catch (err) {
    console.log('Could not write to persistent storage');
  }

  res.json({
    message: 'Sample Web Application',
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
  console.log(`Sample Web App v${appVersion} listening on port ${port}`);
});