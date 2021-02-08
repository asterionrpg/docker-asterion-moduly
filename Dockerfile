FROM php:8.0-fpm

ARG USER_ID=1000
ARG GROUP_ID=1000

# Install other missed extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
      mc \
      vim \
			# procps to get ps, top
      procps \
      htop \
      zlib1g-dev \
      libaio-dev \
      libxml2-dev \
      librabbitmq-dev \
      libzip-dev zip unzip \
      curl \
      gnupg \
      libyaml-0-2 libyaml-dev \
      git \
      apt-transport-https \
      sudo \
      openssh-client \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Fix debconf warnings upon build
ARG DEBIAN_FRONTEND=noninteractive

RUN pecl channel-update pecl.php.net \
# https://pecl.php.net/package/yaml (not available via docker-php-ext-install)
    && pecl install yaml-2.2.1 \
    && docker-php-ext-enable yaml \
# https://pecl.php.net/package/xdebug (not available via docker-php-ext-install)
# XDebug is enabled on-demand, see docker-compose.override.dev.yml
    && pecl install xdebug-3.0.2

# re-build www-data user with same user ID and group ID as a current host user (you)
RUN if getent passwd www-data ; then userdel -f www-data; fi \
		&& if getent group www-data ; then groupdel www-data; fi \
		&& groupadd --gid ${GROUP_ID} www-data \
		&& useradd www-data --no-log-init --gid ${USER_ID} --groups www-data --home-dir /home/www-data --shell /bin/bash \
		&& mkdir -p /var/www \
		&& chown -R www-data:www-data /var/www \
		&& mkdir -p /home/www-data \
		&& chown -R www-data:www-data /home/www-data

USER www-data

RUN mkdir -p /home/www-data/bin \
		&& curl -sS https://getcomposer.org/installer | php -- --install-dir=/home/www-data/bin --filename=composer \
		&& chmod +x /home/www-data/bin/composer \
  	&& echo 'export PATH="/home/www-data/bin:$PATH"' >> ~/.profile

RUN echo 'alias ll="ls -al"' >> ~/.bashrc

USER root

RUN echo 'alias ll="ls -al"' >> ~/.bashrc \
		&& mkdir -p /var/log/php/tracy && chown -R www-data /var/log/php && chmod +w /var/log/php

RUN echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" > /etc/apt/sources.list.d/caddy-fury.list \
		&& apt-get update && apt-get install caddy && caddy list-modules \
		&& touch /var/log/caddy && chown caddy /var/log/caddy

COPY .docker /

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
