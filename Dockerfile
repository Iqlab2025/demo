FROM zabbix/zabbix-web-nginx-mysql:alpine-latest

USER root
RUN apk add --no-cache curl jq

# Branding
COPY --chown=zabbix:zabbix rebranding/ /usr/share/zabbix/rebranding/
COPY --chown=zabbix:zabbix local/conf/brand.conf.php /usr/share/zabbix/local/conf/brand.conf.php

# Custom dashboard
COPY dashboards/dashboard.json /usr/share/zabbix/custom_dashboards/dashboard.json

# Custom entrypoint wrapper
COPY docker-entrypoint-custom.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint-custom.sh

USER zabbix

# Don’t override CMD! Just call your wrapper instead of the original entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-custom.sh"]
