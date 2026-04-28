FROM php:7.4-apache

# 필요한 패키지 설치 및 PHP 확장 설치
RUN apt-get update && apt-get install -y \
    unzip \
    curl \
    gnupg \
    ca-certificates \
    libzip-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install mysqli pdo pdo_mysql zip gd

# Apache rewrite 모듈 활성화
RUN a2enmod rewrite

# 내 설정으로 Apache 설정 덮어쓰기
COPY apache.conf /etc/apache2/sites-available/000-default.conf

# Composer 설치 (PHP 7.4 호환 버전: Composer 2.2.x)
RUN curl -sS https://getcomposer.org/download/2.2.21/composer.phar -o /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

# 퍼미션 정리
# RUN chown -R www-data:www-data /home/illu0423order/www/
RUN chown -h www-data:www-data /var/www/html
