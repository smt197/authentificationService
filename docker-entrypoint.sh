#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Laravel application..."

# Wait for database to be ready
echo "⏳ Waiting for database connection..."
RETRY_COUNT=0
MAX_RETRIES=30

until php artisan tinker --execute="DB::connection()->getPdo(); echo 'Connected';" > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))

    if [ $RETRY_COUNT -gt $MAX_RETRIES ]; then
        echo "❌ Database connection failed after $MAX_RETRIES attempts"
        echo "Testing with manual connection..."
        php artisan tinker --execute="try { DB::connection()->getPdo(); echo 'DB Connected'; } catch(Exception \$e) { echo 'DB Error: ' . \$e->getMessage(); }"
        exit 1
    fi

    echo "Database not ready (attempt $RETRY_COUNT/$MAX_RETRIES), waiting 5 seconds..."
    sleep 5
done
echo "✅ Database connection established"

# Run migrations (skip if already exist)
echo "🔄 Running database migrations..."
php artisan migrate --force --no-interaction || echo "⚠️ Some migrations already exist, continuing..."

# Create cache table if using database cache
if [ "${CACHE_DRIVER:-file}" = "database" ]; then
    echo "📦 Creating cache table..."
    php artisan cache:table || echo "⚠️ Cache table creation skipped"
    php artisan migrate --force --no-interaction || echo "⚠️ Cache table migration failed"
fi

# Skip octane:install since FrankenPHP is already installed in the Docker image
echo "⚠️ Skipping octane:install - using pre-installed FrankenPHP binary"

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