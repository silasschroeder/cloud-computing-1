const express = require('express');
const fs = require('fs');
const path = require('path');
const os = require('os');

const app = express();
const port = 3000;

// Pfad für Counter-Datei
const counterFile = '/app/data/counter.txt';

// Funktion zum Lesen des Counters
function getCounter() {
    try {
        if (fs.existsSync(counterFile)) {
            const counter = fs.readFileSync(counterFile, 'utf8');
            return parseInt(counter) || 0;
        }
    } catch (error) {
        console.log('Counter file not found, starting from 0');
    }
    return 0;
}

// Funktion zum Speichern des Counters
function saveCounter(count) {
    try {
        // Stelle sicher, dass das Verzeichnis existiert
        const dir = path.dirname(counterFile);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        fs.writeFileSync(counterFile, count.toString());
    } catch (error) {
        console.error('Error saving counter:', error);
    }
}

// Middleware für statische Dateien
app.use(express.static('public'));

// Hauptroute
app.get('/', (req, res) => {
    // Counter erhöhen
    let counter = getCounter();
    counter++;
    saveCounter(counter);
    
    // Pod/Container Informationen
    const podName = process.env.HOSTNAME || 'unknown-pod';
    const nodeName = process.env.NODE_NAME || 'unknown-node';
    const podIP = process.env.POD_IP || 'unknown-ip';
    const appVersion = process.env.APP_VERSION || '1.0.0';
    
    // HTML Response
    const html = `
    <!DOCTYPE html>
    <html lang="de">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Simple Counter App</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                text-align: center;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                padding: 30px;
                border-radius: 15px;
                backdrop-filter: blur(10px);
                box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            }
            .counter {
                font-size: 4em;
                font-weight: bold;
                color: #FFD700;
                margin: 20px 0;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.5);
            }
            .info {
                background: rgba(0, 0, 0, 0.2);
                padding: 15px;
                border-radius: 10px;
                margin: 20px 0;
                text-align: left;
            }
            .info-item {
                margin: 8px 0;
                padding: 5px;
                background: rgba(255, 255, 255, 0.1);
                border-radius: 5px;
            }
            .refresh-btn {
                background: #4CAF50;
                color: white;
                padding: 12px 24px;
                border: none;
                border-radius: 25px;
                cursor: pointer;
                font-size: 16px;
                margin-top: 20px;
                transition: background 0.3s;
            }
            .refresh-btn:hover {
                background: #45a049;
            }
            .timestamp {
                font-size: 0.9em;
                opacity: 0.8;
                margin-top: 20px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Simple Counter App</h1>
            <h2>Version ${appVersion}</h2>
            
            <div class="counter">${counter}</div>
            <p>Gesamtanzahl der Aufrufe</p>
            
            <div class="info">
                <h3>📍 Container Informationen:</h3>
                <div class="info-item"><strong>Pod Name:</strong> ${podName}</div>
                <div class="info-item"><strong>Node Name:</strong> ${nodeName}</div>
                <div class="info-item"><strong>Pod IP:</strong> ${podIP}</div>
                <div class="info-item"><strong>App Version:</strong> ${appVersion}</div>
            </div>
            
            <button class="refresh-btn" onclick="window.location.reload()">
                🔄 Seite aktualisieren
            </button>
            
            <div class="timestamp">
                Letzter Aufruf: ${new Date().toLocaleString('de-DE')}
            </div>
        </div>
        
        <script>
            // Auto-refresh alle 5 Sekunden
            setTimeout(() => {
                window.location.reload();
            }, 5000);
        </script>
    </body>
    </html>
    `;
    
    res.send(html);
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        counter: getCounter(),
        pod: process.env.HOSTNAME || 'unknown-pod',
        version: process.env.APP_VERSION || '1.0.0',
        timestamp: new Date().toISOString()
    });
});

// API endpoint für Counter
app.get('/api/counter', (req, res) => {
    res.json({
        counter: getCounter(),
        pod: process.env.HOSTNAME || 'unknown-pod',
        node: process.env.NODE_NAME || 'unknown-node',
        version: process.env.APP_VERSION || '1.0.0'
    });
});

// Server starten
app.listen(port, '0.0.0.0', () => {
    console.log(`Counter App v${process.env.APP_VERSION || '1.0.0'} running on port ${port}`);
    console.log(`Pod: ${process.env.HOSTNAME || 'unknown-pod'}`);
    console.log(`Node: ${process.env.NODE_NAME || 'unknown-node'}`);
    console.log(`Current counter: ${getCounter()}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});