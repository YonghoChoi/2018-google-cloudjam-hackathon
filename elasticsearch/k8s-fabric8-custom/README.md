# Fabric8 기반 커스텀 이미지로 클러스터 구성

1. elasticsearch.yml

   ```yaml
   cluster.name: ${CLUSTER_NAME}
   network.host: ${NETWORK_HOST}
   
   # Cluster Setting
   node.master: ${NODE_MASTER}
   node.data: ${NODE_DATA}
   node.ingest: ${NODE_INGEST}
   search.remote.connect: false
   
   cloud:
     kubernetes:
       service: ${SERVICE}
       namespace: ${KUBERNETES_NAMESPACE}
   discovery.zen.hosts_provider: kubernetes
   discovery.zen.minimum_master_nodes: ${NUMBER_OF_MASTERS}
   xpack.license.self_generated.type: basic
   ```

2. Dockerfile 작성

   ```dockerfile
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
   ```

   * 엘라스틱서치 플러그인 설치시 필요한 환경 변수 설정

3. 이미지 빌드

   ```shell
   docker build -t [이미지명] .
   ```

4. 이미지 태깅

   ```shell
   docker tag [이미지명] gcr.io/[프로젝트ID]/[이미지명]:[태그명]
   ```

5. 이미지 푸시

   ```
   docker push gcr.io/[PROJECT-ID]/[이미지명]:[태그명]
   ```

6. 쿠버네티스 클러스터 생성 스크립트 수행

   ```shell
   ./create.sh
   ```

7. 종료 시 제거 스크립트 수행

   ```shell
   ./delete.sh
   ```


