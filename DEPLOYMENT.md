# Maybe Finance Deployment Guide

This guide explains how to deploy the Maybe Finance application using the provided deployment script.

## Prerequisites

### For Development
- Docker and Docker Compose installed
- No additional requirements

### For Production
- Docker and Docker Compose installed
- Domain name pointing to your server
- Ports 80 and 443 open and accessible
- Valid email address for Let's Encrypt notifications

## Quick Start

### Development Deployment
```bash
./deploy.sh dev
```
This will:
- Use `compose.example.yml` (no nginx/certbot services)
- Start all core services (web, worker, db, redis)
- Make the application available at `http://localhost:3000`

### Production Deployment
```bash
./deploy.sh prod yourdomain.com
```
Or without domain (will prompt you):
```bash
./deploy.sh prod
```

This will:
- Use `compose.prod.yml` with all services including nginx and certbot
- Prompt for your email address for Let's Encrypt
- Generate SSL certificates automatically
- Configure nginx with SSL termination
- Set up automatic certificate renewal
- Make the application available at `https://yourdomain.com`

## Environment Configuration

### Development
The development mode uses default values from `compose.example.yml` and doesn't require additional configuration.

### Production
The script will create a `.env.production` file based on `sample.env`. You should edit this file to configure:

- Database passwords
- API keys (OpenAI, Stripe, Plaid)
- Email settings
- Other production-specific settings

## SSL Certificate Management

### Automatic Setup
The deployment script automatically:
- Generates Let's Encrypt SSL certificates
- Configures nginx for SSL termination
- Sets up automatic certificate renewal via cron

### Manual Certificate Renewal
If needed, you can manually renew certificates:
```bash
docker compose -f compose.prod.yml run --rm certbot renew
docker compose -f compose.prod.yml restart nginx
```

## Troubleshooting

### Domain Resolution Issues
If your domain doesn't resolve to your server:
1. Check your DNS settings
2. Wait for DNS propagation (can take up to 48 hours)
3. Verify with: `dig yourdomain.com`

### SSL Certificate Issues
If SSL certificate generation fails:
1. Ensure ports 80 and 443 are open
2. Check that your domain resolves to this server
3. Verify the email address is valid
4. Check Docker logs: `docker compose -f compose.prod.yml logs certbot`

### Service Issues
To check service status:
```bash
docker compose -f compose.prod.yml ps
docker compose -f compose.prod.yml logs [service_name]
```

## Stopping the Application

### Development
```bash
docker compose -f compose.example.yml down
```

### Production
```bash
docker compose -f compose.prod.yml down
```

## Updating the Application

To update the application:
1. Pull the latest changes: `git pull`
2. Re-run the deployment script: `./deploy.sh [dev|prod] [domain]`

The script will rebuild containers with the latest code.

## Security Considerations

### Production Security
- Always use strong passwords in `.env.production`
- Keep your server updated
- Monitor logs regularly
- Use a firewall to restrict access
- Consider using a reverse proxy like Cloudflare

### SSL Security
- Certificates automatically renew every 90 days
- The script configures modern SSL settings
- Security headers are automatically added

## Support

If you encounter issues:
1. Check the logs: `docker compose -f compose.prod.yml logs`
2. Verify your domain configuration
3. Ensure all prerequisites are met
4. Check the Maybe Finance documentation