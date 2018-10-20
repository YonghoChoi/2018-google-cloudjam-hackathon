# Elasitcsearch Kubernetes Plugin (Fabric8) 

## Elasticsearch 설정

1. elasticsearch.yml

   ```yaml
   cloud:
     kubernetes:
       service: ${SERVICE}
       namespace: ${KUBERNETES_NAMESPACE}
   discovery.zen.hosts_provider: kubernetes
   ```

2. 플러그인 설치

   ```shell
   elasticsearch-plugin install io.fabric8:elasticsearch-cloud-kubernetes:6.2.3.2
   ```



## Kubernetes 설정

1. 서비스 계정 생성

   ```shell
   kubectl create sa elasticsearch
   ```

2. 서비스 계정에 권한 부여

   ```shell
   kubectl create clusterrolebinding cluster-admin-for-elasticsearch --clusterrole=cluster-admin --user=elasticsearch
   ```

   * 여기서는 관리 편의를 위해 cluster 전체에 대해 admin 권한을 부여하였다.



## Kuberntes 클러스터 구성

1. 로드밸런서 생성

   ```shell
   kubectl apply -f services/loadbalancer.yml
   ```

2. Discovery용 Service 생성

   ```shell
   kubectl apply -f services/discovery.yml
   ```

3. 마스터 노드 생성

   ```shell
   kubectl apply -f deployments/es-master.yml
   ```

4. 데이터 노드 생성

   ```shell
   kubectl apply -f deployments/es-data.yml
   ```

5. Coordinating 노드 생성

   ```shell
   kubectl apply -f deployment/es-coord.yml
   ```
