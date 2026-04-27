FROM wordpress:php8.3-fpm-alpine

# install the PHP extensions we need
RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		icu-dev \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		intl \
		pdo_mysql \
	; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .wordpress-phpexts-rundeps $runDeps; \
	apk del --no-network .build-deps

HEALTHCHECK --interval=1m --timeout=10s --start-period=60s --retries=3 \
	CMD php-fpm -t >/dev/null 2>&1 || exit 1

CMD ["php-fpm"]
