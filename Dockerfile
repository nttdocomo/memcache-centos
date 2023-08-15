FROM centos:7.8.2003

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r -g 11211 memcache && useradd -r -g memcache -u 11211 memcache

ENV MEMCACHED_VERSION 1.6.9

RUN set -x \
    && wget -O memcached.tar.gz "https://memcached.org/files/memcached-$MEMCACHED_VERSION.tar.gz" \
    && mkdir -p /usr/src/memcached \
    && tar -xzf memcached.tar.gz -C /usr/src/memcached --strip-components=1 \
    && rm memcached.tar.gz \
    && cd /usr/src/memcached \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && enableExtstore="$( \
# https://github.com/docker-library/memcached/pull/38
		case "$gnuArch" in \
# https://github.com/memcached/memcached/issues/381 "--enable-extstore on s390x (IBM System Z mainframe architecture) fails tests"
			s390x-*) ;; \
			*) echo '--enable-extstore' ;; \
		esac \
	)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-sasl \
		--enable-sasl-pwdb \
		--enable-tls \
		$enableExtstore \
	&& nproc="$(nproc)" \
	&& make -j "$nproc" \
# see https://github.com/docker-library/memcached/pull/54#issuecomment-562797748 and https://bugs.debian.org/927461 for why we have to munge openssl.cnf
	&& sed -i.bak 's/SECLEVEL=2/SECLEVEL=1/g' /etc/ssl/openssl.cnf \
	&& make test PARALLEL="$nproc" \
	&& mv /etc/ssl/openssl.cnf.bak /etc/ssl/openssl.cnf \
	\
	&& make install \
	\
	&& cd / && rm -rf /usr/src/memcached

# CMD ["memcached"]