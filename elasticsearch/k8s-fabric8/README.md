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

8. Endpoint 확인

   ```shell
   kubectl get services
   
   # 결과
   NAME                    TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)          AGE
   elasticsearch           LoadBalancer   10.59.247.179   35.189.158.229   9200:30423/TCP   1h
   elasticsearch-cluster   ClusterIP      None            <none>           9300/TCP         1h
   kubernetes              ClusterIP      10.59.240.1     <none>           443/TCP          19h
   ```

9. 정상 동작 확인

   ```shell
   curl 35.189.158.229:9200
   
   # 결과
   {
     "name" : "bCKvOEi",
     "cluster_name" : "elasticsearch",
     "cluster_uuid" : "C_SS8mFZQP2gR86cCxriVg",
     "version" : {
       "number" : "6.2.3",
       "build_hash" : "c59ff00",
       "build_date" : "2018-03-13T10:06:29.741383Z",
       "build_snapshot" : false,
       "lucene_version" : "7.2.1",
       "minimum_wire_compatibility_version" : "5.6.0",
       "minimum_index_compatibility_version" : "5.0.0"
     },
     "tagline" : "You Know, for Search"
   }
   ```

10. 클러스터 구성 확인

    ```shell
    curl 35.189.158.229:9200/_cluster/state?pretty
    
    # 결과
      ... 생략 ...
      "nodes" : {
        "bCKvOEi5RaWQjiE4z5g7kw" : {
          "name" : "bCKvOEi",
          "ephemeral_id" : "33CrftxYSu6RGF0xpSTemA",
          "transport_address" : "10.56.0.17:9300",
          "attributes" : { }
        },
        "8Xe6ZJBpQ-Ks4NKv30FqSQ" : {
          "name" : "8Xe6ZJB",
          "ephemeral_id" : "bkq5RH-TTwGddGJn7IFVWg",
          "transport_address" : "10.56.0.18:9300",
          "attributes" : { }
        },
        "jzU-eDYoT9e6BVJEOrPCDA" : {
          "name" : "jzU-eDY",
          "ephemeral_id" : "yf-Szx-MRdKpS7WVXNMHNQ",
          "transport_address" : "10.56.0.16:9300",
          "attributes" : { }
        }
      },
      ... 생략 ...
    ```
