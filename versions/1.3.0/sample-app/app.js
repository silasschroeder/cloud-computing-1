const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    
    if (req.url === '/') {
        res.end(`
            <h1>🎉 Simple Demo App</h1>
            <p><strong>Version:</strong> 2.0.0</p>
            <p><strong>Status:</strong> Running</p>
            <p><strong>Time:</strong> ${new Date().toISOString()}</p>
            <p><strong>URL:</strong> ${req.url}</p>
        `);
    } else if (req.url === '/health') {
        res.end('{"status": "healthy"}');
    } else {
        res.end(`
            <h1>Simple Demo App</h1>
            <p>Page not found: ${req.url}</p>
            <p><a href="/">Go home</a></p>
        `);
    }
});

server.listen(port, '0.0.0.0', () => {
    console.log(`Simple server running on port ${port}`);
});