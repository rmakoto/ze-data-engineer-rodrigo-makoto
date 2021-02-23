#!/bin/bash

mkdir -p /etc/tracking/nginx
touch /etc/tracking/nginx/events.log
mkdir -p /etc/tracking/fluentd

/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
