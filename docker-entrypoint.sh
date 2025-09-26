#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Laravel application..."

# Wait for database connection with retry logic
echo "⏳ Waiting for database connection..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if php artisan tinker --execute="DB::connection()->getPdo();" 2>/dev/null; then
        echo "✅ Database connection established"
        break
    fi

    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts: Waiting for database..."

    if [ $attempt -eq $max_attempts ]; then
        echo "❌ Failed to connect to database after $max_attempts attempts"
        echo "🔧 Trying to create user with proper permissions..."

        # Try to connect as root and create/fix user permissions
        mysql -h${DB_HOST} -uroot -p${DB_PASSWORD} -e "
            CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
            GRANT ALL PRIVILEGES ON ${DB_DATABASE}.* TO '${DB_USERNAME}'@'%';
            ALTER USER 'root'@'%' IDENTIFIED BY '${DB_PASSWORD}';
            FLUSH PRIVILEGES;
        " 2>/dev/null || true

        # Final attempt
        php artisan tinker --execute="DB::connection()->getPdo();" || {
            echo "❌ Database connection failed permanently"
            exit 1
        }
        echo "✅ Database connection established after fixing permissions"
        break
    fi

    sleep 2
done

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
