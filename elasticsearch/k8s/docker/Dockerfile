FROM docker.elastic.co/elasticsearch/elasticsearch:6.2.3

ENV CLUSTER_NAME=es-k8s-cluster
ENV NETWORK_HOST=0.0.0.0
ENV NODE_MASTER=true
ENV NODE_DATA=true
ENV NODE_INGEST=false
ENV SERVICE=es-k8s-cluster
ENV KUBERNETES_NAMESPACE=default
ENV NUMBER_OF_MASTERS=1

RUN yum install -y gcc-c++ make zip
RUN wget http://www.kwangsiklee.com/wp-content/uploads/2017/02/mecab-0.996-ko-0.9.2.tar-1.gz
RUN tar -xvzf mecab-0.996-ko-0.9.2.tar-1.gz
RUN cd mecab-0.996-ko-0.9.2 && ./configure && make && make check && make install && ldconfig

RUN wget https://bitbucket.org/eunjeon/mecab-ko-dic/downloads/mecab-ko-dic-2.1.1-20180720.tar.gz
RUN tar -xvzf mecab-ko-dic-2.1.1-20180720.tar.gz
RUN cd mecab-ko-dic-2.1.1-20180720 && ./configure && make && make install

COPY --chown=elasticsearch:elasticsearch elasticsearch.yml /usr/share/elasticsearch/config/
COPY --chown=elasticsearch:elasticsearch elasticsearch-analysis-seunjeon-6.1.1.0.zip /usr/share/elasticsearch/

RUN ./bin/elasticsearch-plugin install file://`pwd`/elasticsearch-analysis-seunjeon-6.1.1.0.zip
RUN ./bin/elasticsearch-plugin install io.fabric8:elasticsearch-cloud-kubernetes:6.2.3.2