FROM centos:7.8.2003

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r -g 11211 memcache && useradd -r -g memcache -u 11211 memcache

ENV MEMCACHED_VERSION 1.6.9

RUN set -x \
	# install build dependencies for openssl
    && yum --nogpg install -y perl* zlib-devel gcc \
	&& perl -v \
	&& curl -o openssl-1.1.1g.tar.gz "https://www.openssl.org/source/openssl-1.1.1g.tar.gz" \
	&& mkdir -p /usr/src/openssl-1.1.1 \
	&& tar -xzf openssl-1.1.1g.tar.gz -C /usr/src/openssl-1.1.1 --strip-components=1 \
	&& rm -rf openssl-1.1.1g.tar.gz \
    && cd /usr/src/openssl-1.1.1 \
	&& ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib no-shared zlib-dynamic \
	&& make \
	&& make install \
	&& openssl version \
	&& cd / && rm -rf /usr/src/openssl-1.1.1 \
	&& export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64 \
	&& echo "export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64" >> ~/.bashrc \
    && yum --nogpg install -y epel-release \
    && yum --nogpg install -y dpkg-dev cyrus-sasl-devel libevent-devel \
    && curl -o memcached.tar.gz "https://memcached.org/files/memcached-$MEMCACHED_VERSION.tar.gz" \
    && mkdir -p /usr/src/memcached \
    && tar -xzf memcached.tar.gz -C /usr/src/memcached --strip-components=1 \
    && rm -rf memcached.tar.gz \
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
	&& cd / && rm -rf /usr/src/memcached \
	&& yum autoremove -y perl* zlib-devel gcc

# CMD ["memcached"]