# Image de base PHP avec extensions nécessaires
FROM php:8.3-fpm

# Installer les dépendances système et les dépendances pour Swoole
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    supervisor \
    libbrotli-dev \
    pkg-config \
    libssl-dev \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# Installer les extensions PHP nécessaires pour Laravel et MySQL
RUN docker-php-ext-install pdo_mysql mysqli mbstring xml zip bcmath gd pcntl sockets intl

# Installer Swoole avec configuration simplifiée pour éviter les erreurs de compilation
RUN pecl install --configureoptions 'enable-sockets="no" enable-openssl="no" enable-http2="no" enable-mysqlnd="no" enable-swoole-curl="no" enable-cares="no" enable-brotli="no"' swoole \
    && pecl install redis \
    && docker-php-ext-enable swoole redis


# Installer composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Installer Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*


# Définir le répertoire de travail
WORKDIR /app


# Copier TOUT le projet Laravel
COPY . /app

# Installer les dépendances PHP
RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs || \
    composer install --no-dev --optimize-autoloader

# Install Octane with Swoole
RUN php artisan octane:install --server=swoole --no-interaction || echo "Octane install will be done at runtime"


# Installer les dépendances npm et compiler les assets (optionnel)
# RUN if [ -f package.json ]; then \
#         echo "Installing npm dependencies..." && \
#         npm ci && \
#         echo "Building assets..." && \
#         (npm run build || echo "npm build failed, continuing..."); \
#     else \
#         echo "No package.json found, skipping npm build"; \
#     fi

# Créer les répertoires nécessaires et définir les permissions
RUN mkdir -p /app/public /app/storage /app/bootstrap/cache && \
    chown -R www-data:www-data /app && \
    chmod -R 775 /app/storage /app/bootstrap/cache /app/public



# Copier la configuration supervisor
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copier et configurer le script de démarrage
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Exposer le port Swoole
EXPOSE 80


# Utiliser le script de démarrage qui lance supervisor
CMD ["/usr/local/bin/docker-entrypoint.sh"]


