# Image de base FrankenPHP
FROM dunglas/frankenphp:latest-php8.3

# Installer les extensions PHP nécessaires pour Laravel
RUN install-php-extensions \
    pdo_mysql \
    mysqli \
    mbstring \
    xml \
    zip \
    bcmath \
    gd \
    redis \
    opcache \
    pcntl \
    sockets  # ← AJOUT CRITIQUE : extension sockets manquante

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs supervisor netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY composer.json composer.lock* package.json package-lock.* ./

RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs --no-interaction

COPY . .

RUN if [ "$APP_ENV" = "local" ] || [ "$APP_ENV" = "development" ]; then \
        pecl install xdebug && \
        docker-php-ext-enable xdebug; \
    fi

RUN if [ -f package.json ] && [ -s package.json ]; then \
        npm ci --no-audit --prefer-offline && \
        npm run build; \
    else \
        echo "No package.json found or empty, skipping npm build"; \
    fi

RUN mkdir -p /app/storage/logs /app/storage/framework/sessions /app/storage/framework/views /app/storage/framework/cache \
    && chown -R www-data:www-data /app/storage /app/bootstrap/cache \
    && chmod -R 775 /app/storage /app/bootstrap/cache

COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh


EXPOSE 80 2019

CMD ["/usr/local/bin/docker-entrypoint.sh"]