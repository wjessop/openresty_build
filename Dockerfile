FROM ubuntu:14.04
ARG version
ARG iteration
ARG maintainer
ARG processors=8
ARG mod_zip_version=1.1.6

# Install a recent Ruby for FPM
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN apt-add-repository ppa:brightbox/ruby-ng

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y git binutils make ruby2.3 ruby2.3-dev ruby-switch dpkg-dev libpcre3-dev libssl-dev curl

# Add in any extra modules we want. Note that headers_more and mod_echo is already bundled with openresty
RUN mkdir /tmp/mod_zip
# RUN curl -L https://github.com/evanmiller/mod_zip/archive/${mod_zip_version}.tar.gz | tar oxzC /tmp/mod_zip --strip-components 1
RUN curl -L https://github.com/evanmiller/mod_zip/archive/master.tar.gz | tar oxzC /tmp/mod_zip --strip-components 1

ADD https://openresty.org/download/openresty-${version}.tar.gz /tmp/openresty.tar.gz
RUN mkdir /tmp/openresty
RUN tar zxf /tmp/openresty.tar.gz -C /tmp/openresty --strip-components 1

WORKDIR /tmp/openresty
RUN ./configure --with-pcre-jit --with-http_v2_module --prefix=/usr/local/nginx \
  --conf-path=/etc/nginx/nginx.conf --pid-path=/run/nginx.pid --sbin-path=/usr/local/sbin/nginx \
  --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log \
  --lock-path=/var/lock/nginx.lock --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi\
  --user=www-data \
  --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module \
  --with-http_ssl_module --with-http_stub_status_module \
  --add-module=/tmp/mod_zip \
  -j$processors --with-debug

RUN make -j$processors
RUN make install DESTDIR=/tmp/fpm

WORKDIR /

# Got to do a bit of cleanup, openresty build doesn't put stuff in exactly the right place.
RUN mkdir -p /tmp/fpm/usr/share/nginx
RUN mv /tmp/fpm/usr/local/nginx/nginx/html /tmp/fpm/usr/share/nginx
RUN rmdir /tmp/fpm/usr/local/nginx/nginx

ADD files /tmp/fpm

# Workaround. Nothing I can do seems to allow me to add the scripts directory, Docker insists on copying the files out of it.
RUN mkdir -p /tmp/scripts
ADD scripts /tmp/scripts

RUN mkdir -p /tmp/fpm/var/lib/nginx/body

RUN ["/usr/bin/gem", "install", "fpm", "--bindir=/usr/bin", "--no-rdoc", "--no-ri"]
RUN fpm \
    -s dir \
    -t deb \
    -m "${maintainer}" \
    --description "Openresty Nginx build by Will Jessop. See Homepage metadata for build info link." \
    --url "https://github.com/wjessop/openresty_build" \
    -n openresty \
    --iteration $iteration \
    -a amd64 \
    -v $version \
    -d libluajit-5.1-2 \
    -d $(for i in `ldd /tmp/fpm/usr/local/sbin/nginx  | awk '{print $1}'`; do dpkg -S $i 2>/dev/null | cut -f1 -d:; done | sort -u | sed ':a;N;s/\n/ -d /;ba') \
    --after-install /tmp/scripts/after_install.sh \
    --after-remove /tmp/scripts/after_remove.sh \
    -C /tmp/fpm \
    -p /openresty-${version}-amd64.deb \
    usr etc run var lib
