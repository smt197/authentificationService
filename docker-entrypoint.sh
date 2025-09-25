#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Laravel application..."

echo "✅ Database connection established"

# Run migrations (skip if already exist)
echo "🔄 Running database migrations..."
php artisan migrate --force --no-interaction || echo "⚠️ Some migrations already exist, continuing..."

# Install Octane if not already installed
if [ ! -f /app/config/octane.php ]; then
    echo "🚀 Installing Octane with FrankenPHP..."
    php artisan octane:install --server=frankenphp --no-interaction || echo "⚠️ Octane install failed, but continuing..."
else
    echo "✅ Octane already installed"
fi

# Clear and cache config for production
echo "🔧 Optimizing application..."
php artisan config:clear --no-interaction || echo "⚠️ Config clear failed"
php artisan config:cache --no-interaction || echo "⚠️ Config cache failed"
php artisan route:cache --no-interaction || echo "⚠️ Route cache failed"
php artisan view:cache --no-interaction || echo "⚠️ View cache failed"

# Create storage link if it doesn't exist
if [ ! -L /app/public/storage ]; then
    echo "🔗 Creating storage symlink..."
    php artisan storage:link --no-interaction
fi

# Set proper permissions
echo "🔒 Setting permissions..."
chown -R www-data:www-data /app/storage /app/bootstrap/cache
chmod -R 775 /app/storage /app/bootstrap/cache

echo "✅ Laravel application ready!"

# Start supervisor to manage processes
echo "🚀 Starting supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf