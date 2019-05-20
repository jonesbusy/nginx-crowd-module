# Build nginx
FROM alpine:3.9.4 as builder

# Nginx version
ENV NGINX_VERSION=1.16.0

# Build tools
RUN apk add --no-cache --virtual .build-deps curl curl-dev libcurl tar gzip git ca-certificates \
    build-base openssh-client openssl openssl-dev perl-dev pcre pcre-dev libaio libaio-dev \
    linux-headers gnupg autoconf zlib-dev python-dev wget && \
	update-ca-certificates

# Build dir
WORKDIR /opt/build

# Download nginx
RUN curl -O http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz && \
    tar xzvf nginx-$NGINX_VERSION.tar.gz && \
    mv nginx-$NGINX_VERSION nginx

WORKDIR /opt/build/nginx

# Clone crowd module
RUN git clone https://github.com/kare/ngx_http_auth_crowd_module.git

# Configure build
RUN ./configure  --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-http_ssl_module --with-http_realip_module \
    --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module \
    --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_stub_status_module \
    --with-http_auth_request_module --with-threads --with-stream --with-stream_ssl_module --with-http_slice_module --with-mail --with-mail_ssl_module \
    --with-file-aio --with-http_v2_module --with-ipv6 --add-dynamic-module=ngx_http_auth_crowd_module --with-ld-opt="-lcurl"

# Build
RUN make

# Install ngninx
RUN make install

# Nginx
FROM alpine:3.9.4 as release

# Run time tools
RUN apk add --no-cache --virtual pcre \
	update-ca-certificates

# Copy from builder
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /var/log/nginx /var/log/nginx

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80

STOPSIGNAL SIGTERM

# Run as nginx user
RUN addgroup -S nginx && adduser --disabled-password --no-create-home -S nginx -G nginx

# Make cache
RUN mkdir /var/cache/nginx && chown nginx:nginx -R /var/cache/nginx

CMD ["nginx", "-g", "daemon off;"]