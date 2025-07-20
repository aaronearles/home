const express = require('express');
const fetch = require('node-fetch');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(cors());

// Serve static files from the public directory
app.use(express.static(path.join(__dirname, 'public')));

// API proxy endpoint
app.post('/api/proxy', async (req, res) => {
    try {
        const { url, method, headers, body } = req.body;

        // Validate required fields
        if (!url || !method) {
            return res.status(400).json({
                error: 'Missing required fields: url and method'
            });
        }

        // Prepare fetch options
        const fetchOptions = {
            method: method.toUpperCase(),
            headers: {
                'User-Agent': 'API-Menu-Proxy/1.0',
                ...headers
            }
        };

        // Add body for POST/PUT requests
        if (['POST', 'PUT', 'PATCH'].includes(method.toUpperCase()) && body) {
            fetchOptions.body = typeof body === 'string' ? body : JSON.stringify(body);
            
            // Ensure Content-Type is set if not provided
            if (!fetchOptions.headers['Content-Type'] && !fetchOptions.headers['content-type']) {
                fetchOptions.headers['Content-Type'] = 'application/json';
            }
        }

        console.log(`[${new Date().toISOString()}] Proxying ${method.toUpperCase()} ${url}`);

        // Make the API call
        const response = await fetch(url, fetchOptions);
        
        // Get response headers
        const responseHeaders = {};
        for (const [key, value] of response.headers.entries()) {
            responseHeaders[key] = value;
        }

        // Get response body
        let responseBody;
        const contentType = response.headers.get('content-type') || '';
        
        try {
            if (contentType.includes('application/json')) {
                responseBody = await response.json();
            } else {
                responseBody = await response.text();
            }
        } catch (bodyError) {
            console.error('Error parsing response body:', bodyError);
            responseBody = 'Error parsing response body';
        }

        // Send response back to client
        res.status(response.status).json({
            status: response.status,
            statusText: response.statusText,
            headers: responseHeaders,
            body: responseBody,
            ok: response.ok
        });

    } catch (error) {
        console.error('Proxy error:', error);
        
        // Determine error type and provide helpful message
        let errorResponse = {
            error: 'Request failed',
            message: error.message,
            type: error.name || 'UnknownError'
        };

        if (error.code === 'ENOTFOUND') {
            errorResponse.message = 'Host not found - check if the URL is correct and the server is reachable';
            errorResponse.type = 'DNSError';
        } else if (error.code === 'ECONNREFUSED') {
            errorResponse.message = 'Connection refused - the server may be down or unreachable';
            errorResponse.type = 'ConnectionError';
        } else if (error.code === 'ETIMEDOUT') {
            errorResponse.message = 'Request timed out - the server took too long to respond';
            errorResponse.type = 'TimeoutError';
        }

        res.status(500).json(errorResponse);
    }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Catch-all handler for SPA routing
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Server error:', err);
    res.status(500).json({
        error: 'Internal server error',
        message: err.message
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`API Menu server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/api/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('Received SIGTERM, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('Received SIGINT, shutting down gracefully');
    process.exit(0);
});