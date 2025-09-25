# =========================
# IMAGE DE BASE
# =========================
FROM dunglas/frankenphp:latest-php8.3 AS base

# =========================
# UTILISATEUR ROOT POUR INSTALLATIONS
# =========================
USER root

# Installer extensions PHP nécessaires pour Laravel
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

# Installer Xdebug
RUN pecl install xdebug && docker-php-ext-enable xdebug

# Installer Composer depuis l'image officielle
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Installer Node.js et supervisor
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs supervisor git unzip \
    && rm -rf /var/lib/apt/lists/*

# Rendre FrankenPHP exécutable
RUN chmod 755 /usr/local/bin/frankenphp

# =========================
# CONFIGURATION APP
# =========================
WORKDIR /app

# Copier tout le projet Laravel
COPY . /app

# Installer les dépendances PHP
RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs || \
    composer install --no-dev --optimize-autoloader

# Définir les permissions pour Laravel
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache \
    && chmod -R 775 /app/storage /app/bootstrap/cache

# Copier le script d'entrée et le rendre exécutable
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Copier la configuration supervisor
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Exposer les ports
EXPOSE 80 443 2019

# Repasser à l'utilisateur www-data pour exécution
USER www-data

# =========================
# COMMANDE DE DÉMARRAGE
# =========================
CMD ["/usr/local/bin/docker-entrypoint.sh"]
