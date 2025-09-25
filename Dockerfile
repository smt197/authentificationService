# --- 1. Stage 'base' ---
FROM php:8.2-fpm-alpine as base

# Installer dépendances système de base
RUN apk add --no-cache \
    supervisor nginx bash git curl unzip jq \
    libpng-dev oniguruma-dev libxml2-dev libzip-dev icu-dev zlib-dev freetype-dev libjpeg-turbo-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip intl \
    && git config --global --add safe.directory '*'

WORKDIR /var/www

# --- 2. Stage 'vendor' ---
FROM base as vendor

# Ajouter Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copier uniquement les fichiers Composer pour tirer parti du cache
COPY composer.json composer.lock ./

# Installer les dépendances PHP du projet
RUN COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --no-interaction --optimize-autoloader --prefer-dist --no-scripts

# --- 3. Stage 'app' ---
FROM base as app

# Copier tout le code applicatif
COPY . .

# Copier les fichiers de config Nginx et Supervisor
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Optimiser Laravel
RUN php artisan config:cache || true \
    && php artisan route:cache || true \
    && php artisan view:cache || true

# Créer les dossiers nécessaires et donner les permissions correctes à Laravel
RUN mkdir -p /var/www/bootstrap/cache /var/www/storage/logs \
    && chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache

COPY php/www.conf /usr/local/etc/php-fpm.d/www.conf

EXPOSE 80 9000

# Lancer Supervisor (qui gère PHP-FPM et Nginx)
CMD ["php-fpm"]