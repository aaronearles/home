# API Menu - Home Automation Interface

A responsive web application that provides a mobile-friendly interface for home automation API calls with customizable buttons and toggles.

## Features

- **Dynamic UI Elements**: Add/remove buttons and toggles on the fly
- **Customizable Controls**: Configure label, API endpoint, HTTP method, headers, and request body for each control
- **Async Status Indicators**: Visual feedback for toggle states and API call progress with LED-style indicators
- **Persistent Storage**: Browser localStorage automatically saves your configuration
- **Mobile-First Design**: Responsive interface optimized for mobile devices
- **Export/Import**: Save and share your configuration as JSON files

## Control Types

### Buttons
- One-shot API calls (e.g., "Open Garage Door")
- Visual loading feedback during API execution
- Success/error status notifications

### Toggles
- State-aware switches (e.g., "Exterior Lights")
- Automatic status polling every 30 seconds
- Visual LED indicators (Green=On, Red=Off, Orange=Loading)
- Optional status check URL for real-time state updates

## Configuration

Each control can be configured with:

- **Label**: Display name for the control
- **API URL**: Endpoint to call when activated
- **HTTP Method**: GET, POST, PUT, or DELETE
- **Status URL**: (Toggles only) URL to check current state
- **Custom Headers**: JSON object for authentication or other headers
- **Request Body**: JSON payload for POST/PUT requests

### Example Configurations

#### Garage Door Button
```json
{
  "label": "Garage Door",
  "apiUrl": "http://192.168.1.100:8080/garage/toggle",
  "method": "POST",
  "headers": "{\"Authorization\": \"Bearer your-token\"}",
  "body": "{\"action\": \"toggle\"}"
}
```

#### Smart Light Toggle
```json
{
  "label": "Living Room Lights",
  "apiUrl": "http://192.168.1.101:8080/lights/living-room/toggle",
  "method": "POST",
  "statusUrl": "http://192.168.1.101:8080/lights/living-room/status",
  "headers": "{\"Content-Type\": \"application/json\"}",
  "body": "{\"toggle\": true}"
}
```

## Status Response Format

For toggles with status URLs, the application expects one of these response formats:

```json
// Direct boolean
true

// Object with status field
{"status": true}
{"status": "on"}

// Object with state field  
{"state": true}
{"state": "on"}

// Object with value field
{"value": true}
{"value": "on"}
```

## Development

### Local Testing
```bash
# Navigate to the src directory
cd custom_containers/api-menu/src

# Serve with any static file server
python3 -m http.server 8000
# or
npx serve .
```

### Docker Deployment
```bash
# Build and run with Docker Compose
cd custom_containers/api-menu
docker-compose up -d

# Access at: https://api-menu.lab.earles.io (via Traefik)
```

## Security Considerations

- **CORS**: Ensure your APIs support cross-origin requests from the web interface
- **Authentication**: Use the headers field to include API keys or tokens
- **HTTPS**: Always use HTTPS for production deployments
- **Network Access**: Ensure the container can reach your home automation APIs

## Browser Compatibility

- Chrome/Edge 80+
- Firefox 75+
- Safari 13+
- Mobile browsers (iOS Safari, Chrome Mobile)

## Architecture

- **Frontend**: Vanilla HTML5, CSS3, JavaScript (ES6+)
- **Storage**: Browser localStorage for configuration persistence
- **API Communication**: Fetch API with async/await
- **Container**: Nginx-based Docker container with Traefik integration

## Configuration Management

- **Export**: Download your entire configuration as a JSON file
- **Import**: Upload a configuration file to restore settings
- **Backup**: Configuration is automatically saved to browser localStorage
- **Sharing**: Export configurations to share between devices or users