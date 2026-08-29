FROM postgres:16

COPY ddl.sql /docker-entrypoint-initdb.d/01-ddl.sql

COPY azure-entrypoint.sh /usr/local/bin/azure-entrypoint.sh

RUN chmod +x /usr/local/bin/azure-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/azure-entrypoint.sh"]

CMD ["postgres"]