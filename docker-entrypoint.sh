#!/bin/bash

# Exit on any error
set -e

# Run migrations first
echo "🔄 Running database migrations..."
php artisan migrate --force --no-interaction

# Run additional seeders if any
# echo "🚀 Running database seeder..."
# php artisan db:seed --force --no-interaction

# Create storage link if it doesn't exist
if [ ! -L /app/public/storage ]; then
    echo "🔗 Creating storage symlink..."
    php artisan storage:link --no-interaction
fi

# Set proper permissions
echo "🔒 Setting permissions..."
chown -R www-data:www-data /app/storage /app/bootstrap/cache
chmod -R 775 /app/storage /app/bootstrap/cache

# Clear caches for development
echo "🔧 Clearing caches for development..."
php artisan config:clear --no-interaction
php artisan route:clear --no-interaction
php artisan view:clear --no-interaction


echo "✅ Laravel application ready!"

# Start supervisor to manage processes
echo "🚀 Starting supervisor..."
# Find supervisord binary location
SUPERVISORD_PATH=$(which supervisord || find /usr -name supervisord 2>/dev/null | head -1 || echo "/usr/bin/supervisord")
echo "Using supervisord at: $SUPERVISORD_PATH"
exec $SUPERVISORD_PATH -c /etc/supervisor/conf.d/supervisord.conf
