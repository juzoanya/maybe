# SSL Setup Guide for Maybe Finance Production

## Overview

This guide explains how to enable SSL/HTTPS for your Maybe Finance production environment when using `RAILS_FORCE_SSL: "true"` and `RAILS_ASSUME_SSL: "true"`.

## Why SSL Termination at Nginx?

When Rails is configured with `RAILS_FORCE_SSL: "true"`, it expects all requests to come over HTTPS. However, Rails itself doesn't handle SSL certificates. The solution is **SSL termination** at the reverse proxy level (Nginx), where:

1. **Nginx** handles SSL certificates and HTTPS connections from clients
2. **Rails** runs on HTTP internally (port 3000)
3. **Nginx** proxies requests to Rails and adds security headers

## Files Created

- `compose.prod.ssl.yml` - Production compose file with Nginx SSL termination
- `nginx/nginx.conf` - Main Nginx configuration
- `nginx/sites-enabled/maybe.conf` - Site-specific SSL configuration
- `nginx/generate-ssl.sh` - Script to generate self-signed certificates
- `nginx/README.md` - Detailed Nginx configuration documentation

## Quick Start

### 1. Generate SSL Certificates

```bash
cd nginx
./generate-ssl.sh
```

This creates self-signed certificates in `nginx/ssl/`:
- `cert.pem` - SSL certificate
- `key.pem` - Private key

### 2. Start SSL-Enabled Services

```bash
docker compose -f compose.prod.ssl.yml up -d
```

### 3. Access Your App

- **HTTPS**: `https://localhost` (accept self-signed certificate warning)
- **HTTP**: `http://localhost` (automatically redirects to HTTPS)

## Production SSL Setup

### Option 1: Let's Encrypt (Recommended)

```bash
# Install certbot
sudo apt install certbot

# Generate certificate for your domain
sudo certbot certonly --standalone -d yourdomain.com

# Copy certificates to nginx/ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/key.pem

# Set proper permissions
sudo chown $USER:$USER nginx/ssl/*
```

### Option 2: Commercial SSL Certificate

1. Purchase certificate from your SSL provider
2. Place `cert.pem` and `key.pem` in `nginx/ssl/`
3. Ensure proper file permissions (600 for key, 644 for cert)

## Key Differences from Non-SSL Setup

| Aspect | Non-SSL | SSL-Enabled |
|--------|---------|-------------|
| **Ports** | 8080 (Rails) | 80 (HTTP), 443 (HTTPS) |
| **SSL** | None | Nginx termination |
| **Rails** | Direct access | Proxied through Nginx |
| **Security** | Basic | HSTS, security headers |
| **Redirects** | None | HTTP → HTTPS automatic |

## Environment Variables

When using SSL, ensure these are set:

```bash
RAILS_FORCE_SSL=true      # Rails expects HTTPS requests
RAILS_ASSUME_SSL=true     # Rails assumes HTTPS context
```

## Security Features

The SSL configuration includes:

- **HSTS**: Strict Transport Security headers
- **XSS Protection**: Cross-site scripting protection
- **Frame Options**: Clickjacking protection
- **Content Type Options**: MIME type sniffing protection
- **Referrer Policy**: Control referrer information
- **Modern SSL**: TLS 1.2/1.3 with secure ciphers

## Troubleshooting

### Common Issues

1. **SSL Certificate Errors**
   - Ensure certificates are in `nginx/ssl/` with correct names
   - Check file permissions (600 for key, 644 for cert)

2. **Permission Denied**
   - Run: `sudo chown $USER:$USER nginx/ssl/*`

3. **Port Conflicts**
   - Ensure ports 80 and 443 are available
   - Check: `sudo netstat -tlnp | grep :80`

4. **Rails App Not Loading**
   - Check web service health: `docker compose -f compose.prod.ssl.yml ps`
   - Check Nginx logs: `docker compose -f compose.prod.ssl.yml logs nginx`

### Health Checks

```bash
# Check all services
docker compose -f compose.prod.ssl.yml ps

# Check Nginx logs
docker compose -f compose.prod.ssl.yml logs nginx

# Test SSL connection
curl -k -I https://localhost

# Test HTTP redirect
curl -I http://localhost
```

## Performance Considerations

- **Asset Caching**: Static assets are cached with 1-year expiration
- **Gzip Compression**: Enabled for text-based content types
- **Keepalive**: Connection pooling for better performance
- **Buffer Optimization**: Optimized proxy buffer settings

## Monitoring

- **Health Endpoint**: `https://localhost/health`
- **Nginx Status**: Check container logs and status
- **SSL Certificate Expiry**: Monitor certificate expiration dates

## Migration from Non-SSL

1. Stop current services: `docker compose -f compose.prod.yml down`
2. Generate SSL certificates: `cd nginx && ./generate-ssl.sh`
3. Start SSL services: `docker compose -f compose.prod.ssl.yml up -d`
4. Update any external references from port 8080 to HTTPS

## Next Steps

1. **Domain Setup**: Configure your domain to point to your server
2. **SSL Renewal**: Set up automatic renewal for Let's Encrypt certificates
3. **Monitoring**: Implement SSL certificate monitoring and alerts
4. **Backup**: Backup SSL certificates and Nginx configurations

## Support

For issues specific to SSL setup:
1. Check Nginx logs: `docker compose -f compose.prod.ssl.yml logs nginx`
2. Verify certificate validity: `openssl x509 -in nginx/ssl/cert.pem -text -noout`
3. Test SSL configuration: `nginx -t` (if Nginx is installed locally) 