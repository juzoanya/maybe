# Let's Encrypt SSL Setup Guide for Maybe Finance

## Overview

This guide shows you how to replace the self-signed SSL certificates with free, trusted Let's Encrypt certificates that automatically renew every 90 days.

## Prerequisites

1. **Domain Name**: You need a domain name that points to your server
2. **Public IP**: Your server must be accessible from the internet
3. **Port Access**: Ports 80 and 443 must be open and accessible
4. **DNS Configuration**: Your domain must resolve to your server's IP address

## Quick Setup

### Step 1: Edit the Setup Script

```bash
cd nginx
nano setup-letsencrypt-simple.sh
```

Change these lines to your actual domain and email:
```bash
DOMAIN="yourdomain.com"  # CHANGE THIS TO YOUR ACTUAL DOMAIN
EMAIL="admin@yourdomain.com"  # CHANGE THIS TO YOUR ACTUAL EMAIL
```

### Step 2: Run the Setup Script

```bash
./setup-letsencrypt-simple.sh
```

The script will:
- Stop nginx temporarily
- Generate Let's Encrypt certificate
- Copy certificates to `ssl/` directory
- Restart nginx
- Test the certificate

### Step 3: Test Your Setup

```bash
# Test HTTPS connection
curl -I https://yourdomain.com

# Check certificate details
openssl x509 -in ssl/cert.pem -text -noout
```

## Manual Setup (Alternative)

If you prefer to run the commands manually:

### 1. Stop Nginx

```bash
docker compose -f compose.prod.ssl.yml stop nginx
```

### 2. Generate Certificate

```bash
sudo certbot certonly --standalone \
    --email your@email.com \
    --agree-tos \
    --no-eff-email \
    --domains yourdomain.com
```

### 3. Copy Certificates

```bash
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/key.pem
```

### 4. Set Permissions

```bash
sudo chown $USER:$USER nginx/ssl/cert.pem nginx/ssl/key.pem
chmod 644 nginx/ssl/cert.pem
chmod 600 nginx/ssl/key.pem
```

### 5. Restart Nginx

```bash
docker compose -f compose.prod.ssl.yml start nginx
```

## Automatic Renewal

Let's Encrypt certificates expire after 90 days. Set up automatic renewal:

### Option 1: Cron Job (Recommended)

```bash
sudo crontab -e
```

Add this line to run renewal twice daily:
```
0 12 * * * /usr/bin/certbot renew --quiet
```

### Option 2: Systemd Timer

The comprehensive setup script creates a systemd timer automatically.

### Option 3: Manual Renewal

```bash
cd nginx
sudo certbot renew
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ssl/key.pem
sudo chown $USER:$USER ssl/cert.pem ssl/key.pem
docker compose -f ../compose.prod.ssl.yml restart nginx
```

## Verification

### Check Certificate Status

```bash
# View certificate details
openssl x509 -in nginx/ssl/cert.pem -text -noout

# Check expiration
openssl x509 -in nginx/ssl/cert.pem -noout -enddate

# Verify certificate validity
openssl x509 -checkend 86400 -noout -in nginx/ssl/cert.pem
```

### Test SSL Connection

```bash
# Test HTTPS
curl -vI https://yourdomain.com

# Test HTTP redirect
curl -I http://yourdomain.com

# Check SSL Labs rating (external)
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com
```

### Check Nginx Status

```bash
# View all services
docker compose -f compose.prod.ssl.yml ps

# Check nginx logs
docker compose -f compose.prod.ssl.yml logs nginx

# Test nginx configuration
docker exec maybe-nginx-1 nginx -t
```

## Troubleshooting

### Common Issues

#### 1. "Domain not reachable" Error

**Problem**: Certbot can't reach your domain
**Solution**: 
- Verify DNS points to your server: `nslookup yourdomain.com`
- Check firewall settings: `sudo ufw status`
- Ensure port 80 is open: `sudo netstat -tlnp | grep :80`

#### 2. "Port 80 already in use" Error

**Problem**: Another service is using port 80
**Solution**:
```bash
# Find what's using port 80
sudo lsof -i :80

# Stop the conflicting service
sudo systemctl stop apache2  # if Apache is running
sudo systemctl stop nginx    # if system nginx is running
```

#### 3. Certificate Not Found

**Problem**: Certificates weren't copied correctly
**Solution**:
```bash
# Check if certificates exist
ls -la nginx/ssl/

# Re-copy from Let's Encrypt
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/key.pem
```

#### 4. Permission Denied

**Problem**: File permission issues
**Solution**:
```bash
sudo chown $USER:$USER nginx/ssl/*
chmod 644 nginx/ssl/cert.pem
chmod 600 nginx/ssl/key.pem
```

### Debug Commands

```bash
# Check certbot logs
sudo journalctl -u certbot

# Test domain resolution
dig yourdomain.com
nslookup yourdomain.com

# Check port accessibility
telnet yourdomain.com 80
telnet yourdomain.com 443

# Verify certificate chain
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
```

## Security Best Practices

### 1. Certificate Security

- Keep private keys secure (600 permissions)
- Monitor certificate expiration
- Use automatic renewal
- Backup certificates securely

### 2. Nginx Security

- Enable HSTS headers (already configured)
- Use modern SSL protocols (TLS 1.2/1.3)
- Implement rate limiting
- Regular security updates

### 3. Server Security

- Keep system updated: `sudo apt update && sudo apt upgrade`
- Configure firewall: `sudo ufw enable`
- Monitor logs: `sudo journalctl -f`
- Regular backups

## Monitoring

### Certificate Expiration

```bash
# Check days until expiration
openssl x509 -in nginx/ssl/cert.pem -noout -enddate | cut -d= -f2

# Set up monitoring script
echo "Certificate expires: $(openssl x509 -in nginx/ssl/cert.pem -noout -enddate | cut -d= -f2)"
```

### Renewal Status

```bash
# Check cron job
sudo crontab -l

# Check systemd timer
sudo systemctl status maybe-ssl-renewal.timer

# Test renewal manually
sudo certbot renew --dry-run
```

## Migration from Self-Signed

If you're currently using self-signed certificates:

1. **Backup current setup**:
   ```bash
   cp -r nginx/ssl nginx/ssl.backup
   ```

2. **Generate Let's Encrypt certificate** (follow steps above)

3. **Test thoroughly** before removing backup

4. **Remove backup** when confident:
   ```bash
   rm -rf nginx/ssl.backup
   ```

## Support

### Useful Commands

```bash
# Check all services
docker compose -f compose.prod.ssl.yml ps

# View logs
docker compose -f compose.prod.ssl.yml logs

# Restart services
docker compose -f compose.prod.ssl.yml restart

# Stop all services
docker compose -f compose.prod.ssl.yml down
```

### External Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot User Guide](https://eff-certbot.readthedocs.io/en/stable/)
- [SSL Labs SSL Test](https://www.ssllabs.com/ssltest/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)

## Next Steps

1. **Set up monitoring** for certificate expiration
2. **Configure backups** for SSL certificates
3. **Implement logging** for SSL-related events
4. **Set up alerts** for renewal failures
5. **Document procedures** for your team

Your Maybe Finance app now has enterprise-grade SSL with automatic renewal! 🎉 