# GCP Hackathon 2018

## VM에 SSH 키 사용해서 접속

* 참고 : https://gongjak.me/2016/08/01/ssh%EB%A5%BC-%EC%9D%B4%EC%9A%A9%ED%95%B4%EC%84%9C-vm%EC%97%90-%EC%A0%91%EC%86%8D%ED%95%98%EA%B8%B0/



## Kubernetes 클러스터 생성

1. GCP 프로젝트에서 쿠버네티스 클러스터를 사용할 수 있도록 준비 절차가 필요하다. GCP Kubernetes Engine 페이지에 최조 접속 시 자동으로 준비 

2. Google Cloud Shell에서 다음 명령 실행

   ```shell
   gcloud config set compute/zone asia-northeast1-b
   gcloud container clusters create hackathon
   ```

3. 다른 인스턴스에서 kubectl 명령으로 관리하려는 경우 다음 명령 실행

   ```shell
   sudo snap install kubectl --classic
   gcloud container clusters get-credentials hackathon --zone asia-northeast1-b --project gcp-hackathon-2018
   ```

   * credentials 정보를 가져오기 위해서는 사전에 해당 VM이 container cluster에 접근할 수 있는 권한이 필요

   * 해당 권한은 인스턴스 설정에서 변경할 수 있고, 아래와 같이 VM 생성시 부여

     ```shell
     gcloud compute instances create NAME --scopes=https://www.googleapis.com/auth/cloud-platform
     ```

4. 정상 동작 확인

   ```shell
   kubectl run nginx --image=nginx
   kubectl get pods
   ```



## 엘라스틱서치 구성

### Deployment

1. Deployment 작성

   ```shell
   apiVersion: extensions/v1beta1
   kind: Deployment
   metadata:
     name: elasticsearch
   spec:
     replicas: 1
     template:
       metadata:
         labels:
           app: elasticsearch
           version: 6.0.1
       spec:
         initContainers:
         - name: init-pod
           image: busybox:1.27.2
           command:
           - sysctl
           - -w
           - vm.max_map_count=262144
           securityContext:
             privileged: true
         containers:
           - name: elasticsearch
             image: "docker.elastic.co/elasticsearch/elasticsearch:6.0.1"
             ports:
               - name: es-external
                 containerPort: 9200
                 hostPort: 9200
               - name: transport
                 containerPort: 9300
                 hostPort: 9300
             readinessProbe:
               httpGet:
                 path: /
                 port: 9200
               initialDelaySeconds: 10
               periodSeconds: 15
               timeoutSeconds: 5
   ```

   * initContainers를 통해 Pod의 설정 초기화
   * readinessProbe를 통해 실행 가능 여부 체크
   * 은전한닢 버전과 맞추기 위해 6.0.1 버전 사용

2. Deployment 생성

   ```shell
   kubectl create -f deployment/elasticsearch.yaml
   ```



### Service

1. Service 작성

   ```yaml
   kind: Service
   apiVersion: v1
   metadata:
     name: "elasticsearch"
   spec:
     selector:
       app: "elasticsearch"
     ports:
       - protocol: "TCP"
         port: 9200
         targetPort: 9200
         nodePort: 30001
     type: NodePort
   ```

   * port는 서비스 레벨에서 pod와 매핑할 port 번호를 의미
   * targetPort는 Pod의 port 번호를 의미
   * NodePort의 Range가 30000-32767 이기 때문에 해당 범위내로 포트 변경
   * Node Selector에 명시된 label이 Pod에 적용이 되어 있어야 정상적으로 해당 Pod에 NodePort가 연결된다.
   * 위 예에서는 app=elasticsearch Label이 Pod에 정의 되어있어야함

2. Service 생성

   ```shell
   kubectl create -f services/elasticsearch.yaml
   ```

3. Service 확인

   ```shell
   kubectl get services
   ```

   ```
   NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
   elasticsearch   NodePort    10.47.254.125   <none>        9200:30001/TCP   2m
   kubernetes      ClusterIP   10.47.240.1     <none>        443/TCP          1h
   ```

4. 30001 방화벽 오픈

   ```shell
   gcloud compute firewall-rules create allow-elasticsearch-nodeport --allow=tcp:30001
   ```

5. 쿠버네티스 워커 노드 인스턴스 주소 확인

   ```shell
   gcloud compute instances list
   ```

   ```shell
   NAME                                      ZONE               MACHINE_TYPE               PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP    STATUS
   es-based-docker                           asia-northeast1-b  custom (2 vCPU, 8.00 GiB)               10.146.0.2   35.221.127.7   RUNNING
   gke-hackathon-default-pool-d208988f-8zqc  asia-northeast1-b  n1-standard-1                           10.146.0.3   35.221.127.30  RUNNING
   gke-hackathon-default-pool-d208988f-f3ld  asia-northeast1-b  n1-standard-1                           10.146.0.4   35.189.153.31  RUNNING
   gke-hackathon-default-pool-d208988f-gqjs  asia-northeast1-b  n1-standard-1                           10.146.0.5   35.200.93.117  RUNNING
   ```

6. Elasticsearch 접속 확인

   ```shell
   curl 35.221.127.30:30001
   ```

   ```
   {
     "name" : "fM2cv6F",
     "cluster_name" : "docker-cluster",
     "cluster_uuid" : "laF2noclT4uWyGAVc8f4dw",
     "version" : {
       "number" : "6.0.1",
       "build_hash" : "601be4a",
       "build_date" : "2017-12-04T09:29:09.525Z",
       "build_snapshot" : false,
       "lucene_version" : "7.0.1",
       "minimum_wire_compatibility_version" : "5.6.0",
       "minimum_index_compatibility_version" : "5.0.0"
     },
     "tagline" : "You Know, for Search"
   }
   ```
