# Nginx SSL Configuration for Maybe Finance

This directory contains the Nginx configuration for running Maybe Finance with SSL termination.

## Quick Start with Self-Signed Certificates

1. Generate self-signed SSL certificates:
   ```bash
   ./generate-ssl.sh
   ```

2. Use the SSL-enabled compose file:
   ```bash
   docker compose -f compose.prod.ssl.yml up -d
   ```

3. Access your app at `https://localhost` (accept the self-signed certificate warning)

## Production SSL Setup

For production use, replace the self-signed certificates with real ones:

1. **Let's Encrypt (Recommended for production):**
   ```bash
   # Install certbot
   sudo apt install certbot
   
   # Generate certificate for your domain
   sudo certbot certonly --standalone -d yourdomain.com
   
   # Copy certificates to nginx/ssl/
   sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/cert.pem
   sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/key.pem
   ```

2. **Commercial SSL Certificate:**
   - Purchase from your SSL provider
   - Place `cert.pem` and `key.pem` in `nginx/ssl/`
   - Ensure proper file permissions (600 for key, 644 for cert)

## Configuration Files

- `nginx.conf` - Main Nginx configuration
- `sites-enabled/maybe.conf` - Site-specific configuration for Maybe Finance
- `generate-ssl.sh` - Script to generate self-signed certificates

## Key Features

- **SSL Termination**: Nginx handles SSL, Rails app runs on HTTP internally
- **HTTP to HTTPS Redirect**: All HTTP traffic automatically redirects to HTTPS
- **Security Headers**: HSTS, XSS protection, frame options, etc.
- **Asset Caching**: Static assets are cached with proper headers
- **WebSocket Support**: Turbo WebSocket connections work properly
- **Health Check**: `/health` endpoint for monitoring

## Environment Variables

When using SSL, ensure these are set in your environment:
```bash
RAILS_FORCE_SSL=true
RAILS_ASSUME_SSL=true
```

## Troubleshooting

1. **SSL Certificate Errors**: Ensure certificates are in `nginx/ssl/` with correct names
2. **Permission Denied**: Check file permissions on SSL certificates
3. **Port Conflicts**: Ensure ports 80 and 443 are available
4. **Rails App Not Loading**: Check that the web service is running and healthy

## Ports

- **80**: HTTP (redirects to HTTPS)
- **443**: HTTPS (main application)
- **3000**: Rails app (internal, not exposed) 
