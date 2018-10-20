# Fabric8 기반 커스텀 이미지로 클러스터 구성

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

   - 여기서는 관리 편의를 위해 cluster 전체에 대해 admin 권한을 부여하였다.