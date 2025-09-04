#!/bin/bash

# ===========================================================================
# Maybe Finance Deployment Script
# ===========================================================================
#
# This script deploys the Maybe Finance application in either development
# or production mode with appropriate service configurations.
#
# Usage:
#   ./deploy.sh [dev|prod] [domain_name]
#
# Examples:
#   ./deploy.sh dev                    # Development mode (no nginx/certbot)
#   ./deploy.sh prod example.com       # Production mode with SSL
#   ./deploy.sh prod                   # Production mode, will prompt for domain
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate domain name
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Function to check if domain resolves to this server
check_domain_resolution() {
    local domain=$1
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "")
    
    if [[ -z "$server_ip" ]]; then
        print_warning "Could not determine server IP address"
        return 0
    fi
    
    local domain_ip=$(dig +short "$domain" | tail -n1)
    
    if [[ "$domain_ip" == "$server_ip" ]]; then
        print_success "Domain $domain correctly resolves to this server ($server_ip)"
        return 0
    else
        print_warning "Domain $domain resolves to $domain_ip, but this server is $server_ip"
        print_warning "Make sure your domain DNS is correctly configured"
        return 1
    fi
}

# Function to setup SSL certificates
setup_ssl() {
    local domain=$1
    local email=$2
    
    print_status "Setting up SSL certificates for domain: $domain"
    
    # Create necessary directories
    mkdir -p data/certbot/conf
    mkdir -p data/certbot/www
    mkdir -p data/nginx/conf.d
    mkdir -p data/www
    
    # Create nginx configuration for SSL
    cat > data/nginx/conf.d/default.conf << EOF
server {
    listen 80;
    server_name $domain;
    
    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $domain;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    
    # SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Proxy to Rails application
    location / {
        proxy_pass http://host.docker.internal:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
    }
}
EOF
    
    print_success "Nginx configuration created"
    
    # Start nginx temporarily for certificate generation
    print_status "Starting nginx for certificate generation..."
    docker compose -f compose.prod.yml up -d nginx
    
    # Wait for nginx to be ready
    sleep 5
    
    # Generate Let's Encrypt certificate
    print_status "Generating Let's Encrypt certificate..."
    docker compose -f compose.prod.yml run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$email" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "$domain"
    
    if [[ $? -eq 0 ]]; then
        print_success "SSL certificate generated successfully"
        
        # Restart nginx with SSL configuration
        print_status "Restarting nginx with SSL configuration..."
        docker compose -f compose.prod.yml restart nginx
        
        # Setup automatic renewal
        print_status "Setting up automatic certificate renewal..."
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/docker compose -f $(pwd)/compose.prod.yml run --rm certbot renew --quiet && /usr/bin/docker compose -f $(pwd)/compose.prod.yml restart nginx") | crontab -
        
        print_success "SSL setup completed successfully"
        print_success "Your application is now available at: https://$domain"
    else
        print_error "Failed to generate SSL certificate"
        print_error "Please check your domain configuration and try again"
        exit 1
    fi
}

# Function to create production environment file
create_prod_env() {
    if [[ ! -f .env.production ]]; then
        print_status "Creating production environment file..."
        cp sample.env .env.production
        
        # Generate new secret key
        local secret_key=$(docker run --rm ruby:3.2-alpine ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
        sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$secret_key/" .env.production
        
        # Set production SSL settings
        sed -i 's/RAILS_FORCE_SSL: "false"/RAILS_FORCE_SSL: "true"/' .env.production
        sed -i 's/RAILS_ASSUME_SSL: "false"/RAILS_ASSUME_SSL: "true"/' .env.production
        
        print_warning "Please edit .env.production and configure your environment variables"
        print_warning "Especially important: database passwords, API keys, and email settings"
    fi
}

# Function to deploy in development mode
deploy_dev() {
    print_status "Deploying in development mode..."
    
    # Use the example compose file (no nginx/certbot)
    docker compose -f compose.example.yml down --remove-orphans
    docker compose -f compose.example.yml up -d --build
    
    print_success "Development deployment completed"
    print_success "Application is available at: http://localhost:3000"
    print_warning "No SSL/HTTPS configured for development mode"
}

# Function to deploy in production mode
deploy_prod() {
    local domain=$1
    
    print_status "Deploying in production mode..."
    
    # Create production environment file
    create_prod_env
    
    # Check if domain is provided
    if [[ -z "$domain" ]]; then
        echo -n "Enter your domain name (e.g., example.com): "
        read -r domain
        
        if [[ -z "$domain" ]]; then
            print_error "Domain name is required for production deployment"
            exit 1
        fi
    fi
    
    # Validate domain name
    if ! validate_domain "$domain"; then
        print_error "Invalid domain name format: $domain"
        exit 1
    fi
    
    # Check domain resolution
    check_domain_resolution "$domain"
    
    # Get email for Let's Encrypt
    echo -n "Enter your email address for Let's Encrypt notifications: "
    read -r email
    
    if [[ -z "$email" ]]; then
        print_error "Email address is required for Let's Encrypt"
        exit 1
    fi
    
    # Validate email format
    if [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Invalid email address format: $email"
        exit 1
    fi
    
    # Stop any existing containers
    docker compose -f compose.prod.yml down --remove-orphans
    
    # Start core services first
    print_status "Starting core services..."
    docker compose -f compose.prod.yml up -d --build db redis
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    sleep 10
    
    # Start web and worker services
    print_status "Starting web and worker services..."
    docker compose -f compose.prod.yml up -d --build web worker
    
    # Setup SSL certificates
    setup_ssl "$domain" "$email"
    
    print_success "Production deployment completed"
    print_success "Application is available at: https://$domain"
    print_warning "Make sure to configure your .env.production file with proper settings"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [dev|prod] [domain_name]"
    echo ""
    echo "Modes:"
    echo "  dev     - Development mode (no nginx/certbot, uses compose.example.yml)"
    echo "  prod    - Production mode (with nginx/certbot, uses compose.prod.yml)"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Development mode"
    echo "  $0 prod example.com       # Production mode with domain"
    echo "  $0 prod                   # Production mode (will prompt for domain)"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker and Docker Compose installed"
    echo "  - For production: domain name pointing to this server"
    echo "  - For production: ports 80 and 443 open"
}

# Main script logic
main() {
    # Check if Docker is installed
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Parse arguments
    local mode=$1
    local domain=$2
    
    case $mode in
        "dev")
            deploy_dev
            ;;
        "prod")
            deploy_prod "$domain"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Invalid mode: $mode"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"