const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;
const appVersion = process.env.APP_VERSION || '2.0.0';

// Create data directory if it doesn't exist
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
  
  // Log access to persistent storage if available
  try {
    const logFile = path.join(dataDir, 'access.log');
    fs.appendFileSync(logFile, `${timestamp} - Access from ${req.ip}\n`);
  } catch (err) {
    console.log('Could not write to persistent storage');
  }

  res.json({
    message: '🚀 Enhanced Sample Web Application v2.0.0',
    version: appVersion,
    timestamp: timestamp,
    hostname: require('os').hostname(),
    uptime: process.uptime(),
    features: ['Enhanced UI', 'Better logging', 'Improved performance', 'Logs endpoint'],
    status: 'running'
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    version: appVersion,
    timestamp: new Date().toISOString(),
    checks: {
      memory: process.memoryUsage(),
      uptime: process.uptime()
    }
  });
});

app.get('/version', (req, res) => {
  res.json({
    version: appVersion,
    build_time: new Date().toISOString(),
    release_notes: 'Version 2.0.0 - Enhanced features and improved performance'
  });
});

// New endpoint for v2.0.0
app.get('/logs', (req, res) => {
  try {
    const logFile = path.join(dataDir, 'access.log');
    if (fs.existsSync(logFile)) {
      const logs = fs.readFileSync(logFile, 'utf8').split('\n').filter(line => line.trim());
      res.json({
        version: appVersion,
        total_requests: logs.length,
        recent_logs: logs.slice(-10)
      });
    } else {
      res.json({
        version: appVersion,
        total_requests: 0,
        message: 'No logs available yet'
      });
    }
  } catch (err) {
    res.status(500).json({
      error: 'Failed to read logs',
      version: appVersion
    });
  }
});

app.listen(port, () => {
  console.log(`🚀 Enhanced Sample Web App v${appVersion} listening on port ${port}`);
  console.log(`📊 New features: Enhanced logging, performance monitoring, logs endpoint`);
});