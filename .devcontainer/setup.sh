#!/bin/bash

# Maybe Development Environment Setup Script
# This script sets up the development environment and fixes common issues

set -e

echo "🚀 Setting up Maybe development environment..."

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: Please run this script from the .devcontainer directory"
    exit 1
fi

echo "📦 Starting Docker containers..."
docker compose up -d

echo "⏳ Waiting for containers to be ready..."
sleep 60

echo "🗄️  Creating and migrating database..."
docker compose exec app bash -c "cd /workspace && bundle exec rails db:create db:migrate"

echo "🎨 Precompiling assets..."
docker compose exec app bash -c "cd /workspace && bundle exec rails assets:precompile"

echo "🌐 Starting Rails server..."
docker compose exec app bash -c "cd /workspace && bundle exec rails server -b 0.0.0.0 -p 3000 -d"

echo "✅ Setup complete!"
echo ""
echo "📋 Verification:"
echo "  - Application: http://127.0.0.1:3000"
echo "  - Login page: http://127.0.0.1:3000/sessions/new"
echo ""
echo "🔧 Useful commands:"
echo "  - View logs: docker compose logs -f [service_name]"
echo "  - Stop services: docker compose down"
echo "  - Restart: docker compose restart"
echo ""
echo "🐛 If you encounter issues, see DEV_SETUP.md for troubleshooting" 