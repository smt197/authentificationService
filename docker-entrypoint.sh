#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Laravel application..."

# Wait for MySQL to be ready first
echo "⏳ Waiting for MySQL server to be ready..."
until mysqladmin ping -h"${DB_HOST}" --silent; do
    echo "MySQL is unavailable - sleeping"
    sleep 2
done
echo "✅ MySQL server is ready"

# Now try to fix database permissions
echo "🔧 Setting up database permissions..."
mysql -h"${DB_HOST}" -uroot -p"${DB_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_DATABASE}\`.* TO '${DB_USERNAME}'@'%';
ALTER USER 'root'@'%' IDENTIFIED BY '${DB_PASSWORD}';
FLUSH PRIVILEGES;
EOF

echo "✅ Database permissions configured"

# Test the connection with Laravel
echo "⏳ Testing Laravel database connection..."
if php artisan tinker --execute="DB::connection()->getPdo(); echo 'Connection OK';" 2>&1; then
    echo "✅ Laravel database connection successful"
else
    echo "❌ Laravel database connection failed"
    exit 1
fi

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
