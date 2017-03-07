FROM ubuntu:14.04
ARG version
ARG maintainer

# Install a recent Ruby for FPM
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN apt-add-repository ppa:brightbox/ruby-ng

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y git binutils make ruby2.3 ruby2.3-dev ruby-switch dpkg-dev libpcre3-dev libssl-dev

ADD https://openresty.org/download/openresty-${version}.tar.gz /tmp/openresty.tar.gz
RUN mkdir /tmp/openresty
RUN tar zxf /tmp/openresty.tar.gz -C /tmp/openresty --strip-components 1

WORKDIR /tmp/openresty
RUN ./configure --with-pcre-jit --with-ipv6 --with-http_v2_module --prefix=/usr/local -j8
RUN make -j8
RUN make install DESTDIR=/tmp/fpm

RUN ["/usr/bin/gem", "install", "fpm", "--bindir=/usr/bin", "--no-rdoc", "--no-ri"]

WORKDIR /
RUN fpm \
    -s dir \
    -t deb \
    -m "${maintainer}" \
    --description "Openresty build by Will Jessop. See Homepage for buld info link." \
    --url "https://github.com/wjessop/openresty_build" \
    -n openresty \
    -a amd64 \
    -v $version \
    -d libluajit-5.1-2 \
    -d $(for i in `ldd /tmp/fpm/usr/local/nginx/sbin/nginx | awk '{print $1}'`; do dpkg -S $i 2>/dev/null | cut -f1 -d:; done | sort -u | sed ':a;N;s/\n/ -d /;ba') \
    -C /tmp/fpm \
    -p /openresty-${version}-amd64.deb \
    usr
