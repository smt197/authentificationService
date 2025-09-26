#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Laravel application..."

# Wait for MySQL to be ready first
echo "⏳ Waiting for MySQL server to be ready..."
until nc -z "${DB_HOST}" "${DB_PORT}"; do
    echo "MySQL is unavailable - sleeping"
    sleep 2
done
echo "✅ MySQL server is ready"

# Now try to fix database permissions using PHP
echo "🔧 Setting up database permissions..."
php -r "
try {
    \$pdo = new PDO('mysql:host=${DB_HOST};port=${DB_PORT}', 'root', '${DB_PASSWORD}');
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    \$pdo->exec(\"CREATE DATABASE IF NOT EXISTS \\\`${DB_DATABASE}\\\`\");
    \$pdo->exec(\"CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}'\");
    \$pdo->exec(\"GRANT ALL PRIVILEGES ON \\\`${DB_DATABASE}\\\`.* TO '${DB_USERNAME}'@'%'\");
    \$pdo->exec(\"ALTER USER 'root'@'%' IDENTIFIED BY '${DB_PASSWORD}'\");
    \$pdo->exec(\"FLUSH PRIVILEGES\");

    echo \"Database permissions configured successfully\n\";
} catch (Exception \$e) {
    echo \"Warning: Could not configure permissions: \" . \$e->getMessage() . \"\n\";
}
"

echo "✅ Database permissions setup completed"

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
php artisan migrate:status

# Check if sessions table exists but migration is pending and drop it
if php -r "
\$pdo = new PDO('mysql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_DATABASE}', '${DB_USERNAME}', '${DB_PASSWORD}');
\$result = \$pdo->query(\"SHOW TABLES LIKE 'sessions'\")->rowCount();
if (\$result > 0) {
    echo 'sessions_exists';
}
" | grep -q "sessions_exists"; then
    echo "⚠️ Sessions table exists but migration is pending, dropping existing table..."
    php -r "
    \$pdo = new PDO('mysql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_DATABASE}', '${DB_USERNAME}', '${DB_PASSWORD}');
    \$pdo->exec('DROP TABLE IF EXISTS sessions');
    echo 'Sessions table dropped';
    "
fi

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
