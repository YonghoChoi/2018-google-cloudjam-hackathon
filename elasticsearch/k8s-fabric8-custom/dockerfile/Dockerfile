FROM docker.elastic.co/elasticsearch/elasticsearch:6.2.3
ENV CLUSTER_NAME=es-k8s-cluster
ENV NETWORK_HOST=0.0.0.0
ENV NODE_MASTER=true
ENV NODE_DATA=true
ENV NODE_INGEST=false
ENV SERVICE=es-k8s-cluster
ENV KUBERNETES_NAMESPACE=default
ENV NUMBER_OF_MASTERS=1

COPY --chown=elasticsearch:elasticsearch elasticsearch.yml /usr/share/elasticsearch/config/
RUN ./bin/elasticsearch-plugin install io.fabric8:elasticsearch-cloud-kubernetes:6.2.3.2