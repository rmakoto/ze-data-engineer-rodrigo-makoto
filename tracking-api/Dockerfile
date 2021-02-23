FROM ruby:2.4-stretch

RUN apt-get update
RUN apt-get install -y logrotate \
	git \
	cron \
	supervisor \
	build-essential \
	zlib1g-dev \
	libjemalloc1 \
	rsyslog \
    ruby-dev \
    make \
    gcc \
    libsnappy-dev \
    libtool automake autoconf 

RUN	gem install fluentd -v 1.1.0 && \
	gem install avro_turf && \
	gem install ruby-kafka && \
	gem install oj bigdecimal && \
	fluent-gem install fluent-plugin-record-modifier \
		fluent-plugin-rewrite-tag-filter \
		fluent-plugin-kafka \
		snappy \
	&& rm -rf /tmp/* /var/tmp/* /usr/lib/ruby/gems/*/cache/*.gem

# Install Nginx

RUN apt-get install -y gnupg1 && \
	apt-transport-https && \
	ca-certificates && \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 && found=yes && break; \
	done; \
	echo "deb-src https://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list.d/nginx.list \
	apt-get build-dep nginx=1.13.12

ENV ECHO_PWD=/etc/nginx/echo-nginx-module
WORKDIR /etc/nginx

RUN git clone https://github.com/openresty/echo-nginx-module.git
RUN wget 'http://nginx.org/download/nginx-1.13.12.tar.gz'
RUN tar -xf nginx-1.13.12.tar.gz

WORKDIR /etc/nginx/nginx-1.13.12

RUN ./configure --prefix=/opt/nginx --add-module=$ECHO_PWD

RUN make -j$(nproc) && \
	make install

WORKDIR /opt/nginx

RUN ln -s /opt/nginx/sbin/nginx /usr/local/bin/nginx

# Configure Nginx
COPY nginx/nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /etc/tracking/nginx
RUN touch /etc/tracking/nginx/events.log

# Configure LogRotate
COPY nginx/logrotate.conf /etc/logrotate.conf
COPY nginx/crontab /etc/cron.d/logrotate

COPY nginx/rsyslog.conf /etc/
RUN chmod 0644 /etc/logrotate.conf
RUN chmod 0644 /etc/rsyslog.conf

RUN chmod 0600 /etc/cron.d/logrotate

RUN touch /var/log/cron.log

# Configure Fluent
ADD fluentd/config/fluentd.conf /etc/fluent/fluentd.conf
ADD fluentd/filters /etc/fluent/plugin

RUN mkdir -p /etc/tracking/fluentd

# Configure Supervisor
RUN mkdir -p /var/log/supervisor
ADD nginx/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configure Entrypoint
COPY entrypoint.sh /opt/nginx/entrypoint.sh
RUN chmod +x /opt/nginx/entrypoint.sh

EXPOSE 80
EXPOSE 24231

CMD [ "/opt/nginx/entrypoint.sh" ]
