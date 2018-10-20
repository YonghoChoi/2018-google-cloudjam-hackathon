FROM docker.elastic.co/elasticsearch/elasticsearch:6.4.2

COPY --chown=elasticsearch:elasticsearch elasticsearch.yml /usr/share/elasticsearch/config/
RUN ./bin/elasticsearch-plugin install io.fabric8:elasticsearch-cloud-kubernetes:6.2.3.2