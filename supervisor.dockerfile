# Image de base FrankenPHP
FROM dunglas/frankenphp:latest-php8.3

# Fix FrankenPHP permissions and backup prevention
RUN chmod +x /usr/local/bin/frankenphp && \
    rm -f /usr/local/bin/frankenphp.backup
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
   sockets


# Installer composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Installer Node.js et supervisor
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs supervisor \
    && rm -rf /var/lib/apt/lists/*


# Définir le répertoire de travail
WORKDIR /app


# Copier TOUT le projet Laravel
COPY . /app

# Install PHP extensions
RUN pecl install xdebug

# Installer les dépendances PHP
RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs || \
    composer install --no-dev --optimize-autoloader

# Pre-install Octane to avoid runtime permission issues
RUN php artisan octane:install --server=frankenphp --no-interaction || echo "Octane install failed, will retry at runtime"


# Enable PHP extensions
RUN docker-php-ext-enable xdebug


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

# Exposer les ports
EXPOSE 80 443 2019


# Utiliser le script de démarrage qui lance supervisor
CMD ["/usr/local/bin/docker-entrypoint.sh"]


