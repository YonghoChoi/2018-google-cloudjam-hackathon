# Elasitcsearch Kubernetes Plugin (Fabric8) 

## Kuberntes 클러스터 구성

1. 서비스 계정 생성

   ```shell
   kubectl create sa elasticsearch
   ```

2. 서비스 계정에 클러스터 권한 부여

   ```shell
   kubectl create --save-config -f accounts/service-account.yml
   ```

3. 로드밸런서 생성

   ```shell
   kubectl apply -f services/loadbalancer.yml
   ```

4. Discovery용 Service 생성

   ```shell
   kubectl apply -f services/discovery.yml
   ```

5. 마스터 노드 생성

   ```shell
   kubectl apply -f deployments/es-master.yml
   ```

6. 데이터 노드 생성

   ```shell
   kubectl apply -f deployments/es-data.yml
   ```

7. Coordinating 노드 생성

   ```shell
   kubectl apply -f deployment/es-coord.yml
   ```
