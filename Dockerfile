# --- 1. Stage 'base' ---
FROM php:8.2-fpm-alpine as base
RUN apk add --no-cache supervisor nginx
WORKDIR /var/www

# --- 2. Stage 'vendor' ---
FROM base as vendor
RUN apk add --no-cache git curl unzip
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --optimize-autoloader

# --- 3. Stage 'app' ---
FROM base as app
RUN apk add --no-cache libpng-dev oniguruma-dev libxml2-dev \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Copier le code applicatif
COPY . .

# Copier vendor après coup
COPY --from=vendor /var/www/vendor/ ./vendor/

COPY nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache
RUN chmod -R 775 /var/www/storage /var/www/bootstrap/cache

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
