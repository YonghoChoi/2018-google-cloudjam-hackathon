# GCP Hackathon 2018

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



## 엘라스틱서치 이미지 구성

### Elasticsearch Dockerfile

1. elasticsearch.yml 준비

   ```yaml
   cluster.name: ${CLUSTER_NAME}
   network.host: ${NETWORK_HOST}
   
   # Cluster Setting
   node.master: ${NODE_MASTER}
   node.data: ${NODE_DATA}
   node.ingest: ${NODE_INGEST}
   search.remote.connect: false
   
   discovery.zen.minimum_master_nodes: ${NUMBER_OF_MASTERS}
   xpack.license.self_generated.type: basic
   ```

2. Dockerfile 작성

   ```dockerfile
   FROM docker.elastic.co/elasticsearch/elasticsearch:6.4.2
   
   RUN yum install -y gcc-c++ make zip
   
   RUN wget http://www.kwangsiklee.com/wp-content/uploads/2017/02/mecab-0.996-ko-0.9.2.tar-1.gz
   RUN tar -xvzf mecab-0.996-ko-0.9.2.tar-1.gz
   RUN cd mecab-0.996-ko-0.9.2 && ./configure && make && make check && make install && ldconfig
   
   RUN wget https://bitbucket.org/eunjeon/mecab-ko-dic/downloads/mecab-ko-dic-2.1.1-20180720.tar.gz
   RUN tar -xvzf mecab-ko-dic-2.1.1-20180720.tar.gz
   RUN cd mecab-ko-dic-2.1.1-20180720 && ./configure && make && make install
   
   COPY --chown=elasticsearch:elasticsearch elasticsearch-analysis-seunjeon-6.1.1.0.zip /usr/share/elasticsearch/
   RUN ./bin/elasticsearch-plugin install file://`pwd`/elasticsearch-analysis-seunjeon-6.0.0.1.zip
   
   COPY --chown=elasticsearch:elasticsearch elasticsearch.yml /usr/share/elasticsearch/config/
   ```



### Container Registry에 이미지 push

1. docker가 설치 되어있다는 전제 하에 진행. 먼저 docker build로 이미지 만들기

   ```shell
   docker build -t [이미지명] .
   ```

2. credential 정보 설정

   ```shell
   gcloud auth configure-docker
   ```

3. 프로젝트ID 확인

   ```shell
   gcloud projects list
   ```

4. 이미지명 태깅

   ```shell
   docker tag [이미지명] gcr.io/[프로젝트ID]/[이미지명]:[태그명]
   ```

   ```shell
   ex) docker tag elasticsearch gcr.io/gcp-hackathon-2018/elasticsearch:6.4.2
   ```

5. 이미지 push

   ```shell
   docker push gcr.io/[PROJECT-ID]/[이미지명]:[태그명]
   ```

6. 브라우저에서 이미지 확인

   ```shell
   http://gcr.io/[PROJECT-ID]/[이미지명]:[태그명]
   ```



## Kubernetes Elasticsearch Cluster 구성

### Elasticsearch Master Node

1. Deployment 작성

   ```shell
   apiVersion: extensions/v1beta1
   kind: Deployment
   metadata:
     name: elasticsearch
   spec:
     replicas: 3
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
             image: "yonghochoi/es-master:6.0.1"
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
   * Master 노드와 Data 노드 구분을 위해 label에 role 부여

2. Elasticsearch Master Deployment 생성

   ```shell
   kubectl create -f deployments/elasticsearch-master.yml
   ```

3. Discovery를 위한 Service 작성

   ```yaml
   kind: Service
   apiVersion: v1
   metadata:
     name: "elasticsearch-discovery"
   spec:
     selector:
       app: "elasticsearch"
       role: "master"
     ports:
     - protocol: "TCP"
       port: 9300
       name: transport
   ```

   * 내부통신이기 때문에 ClusterIP 사용

4. 서비스 생성

   ```
   kubectl create -f services/discovery.yml
   ```

5. 서비스 ClusterIP 확인

   ```shell
   kubectl get services
   ```

   ```shell
   NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
   elasticsearch-discovery   ClusterIP   10.47.251.46   <none>        9300/TCP         18m
   kubernetes                ClusterIP   10.47.240.1    <none>        443/TCP          3h
   ```



### Elasticsearch Data Node

1. Deployment 작성

   ```shell
   apiVersion: extensions/v1beta1
   kind: Deployment
   metadata:
     name: elasticsearch
   spec:
     replicas: 3
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
             image: "yonghochoi/es-data:6.0.1"
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

   * es-data 도커 이미지의 elasticsearch.yml 파일에는 위 Discovery를 위한 서비스의 ClusterIP가 설정되어 있음

     ```
     discovery.zen.ping.unicast.hosts: ["10.47.251.46"]
     ```

2. 외부에서 쿼리 요청을 받기 위한 Service 작성

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

3. Service 생성

   ```
   kubectl create -f services/elasticsearch.yml
   ```

4. Service 확인

   ```
   kubectl get services
   ```

   ```
   NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
   elasticsearch             NodePort    10.47.254.94   <none>        9200:30001/TCP   18m
   elasticsearch-discovery   ClusterIP   10.47.251.46   <none>        9300/TCP         18m
   kubernetes                ClusterIP   10.47.240.1    <none>        443/TCP          3h
   ```

5. 30001 방화벽 오픈

   ```
   gcloud compute firewall-rules create allow-elasticsearch-nodeport --allow=tcp:30001
   ```

6. 쿠버네티스 워커 노드 인스턴스 주소 확인

   ```
   gcloud compute instances list
   ```

   ```
   NAME                                      ZONE               MACHINE_TYPE               PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP    STATUS
   es-based-docker                           asia-northeast1-b  custom (2 vCPU, 8.00 GiB)               10.146.0.2   35.221.127.7   RUNNING
   gke-hackathon-default-pool-d208988f-8zqc  asia-northeast1-b  n1-standard-1                           10.146.0.3   35.221.127.30  RUNNING
   gke-hackathon-default-pool-d208988f-f3ld  asia-northeast1-b  n1-standard-1                           10.146.0.4   35.189.153.31  RUNNING
   gke-hackathon-default-pool-d208988f-gqjs  asia-northeast1-b  n1-standard-1                           10.146.0.5   35.200.93.117  RUNNING
   ```

7. Elasticsearch 접속 확인

   ```
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

8. 클러스터 연결 확인

   ```
   curl 35.200.12.206:30001/_cluster/health?pretty
   ```

   ```json
   {
     "cluster_name" : "docker-cluster",
     "status" : "green",
     "timed_out" : false,
     "number_of_nodes" : 3,
     "number_of_data_nodes" : 2,
     "active_primary_shards" : 0,
     "active_shards" : 0,
     "relocating_shards" : 0,
     "initializing_shards" : 0,
     "unassigned_shards" : 0,
     "delayed_unassigned_shards" : 0,
     "number_of_pending_tasks" : 0,
     "number_of_in_flight_fetch" : 0,
     "task_max_waiting_in_queue_millis" : 0,
     "active_shards_percent_as_number" : 100.0
   }
   ```



## VM에 SSH 키 사용해서 접속

* 참고 : https://gongjak.me/2016/08/01/ssh%EB%A5%BC-%EC%9D%B4%EC%9A%A9%ED%95%B4%EC%84%9C-vm%EC%97%90-%EC%A0%91%EC%86%8D%ED%95%98%EA%B8%B0/



## To Do List

### ConfigMap 사용

* ConfigMap으로 설정관리 시 다음과 같이 설정했더니 오류 발생

  ```yaml
  apiVersion: extensions/v1beta1
  kind: Deployment
  metadata:
    name: elasticsearch-master-node
  spec:
    replicas: 1
    template:
      metadata:
        labels:
          app: elasticsearch
          role: master
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
          image: "yonghochoi/elasticsearch:6.0.1"
          ports:
          - name: http
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
          volumeMounts:
          - name: es-config
            mountPath: /usr/share/elasticsearch/config
         volumes:
        - name: es-config
          configMap:
            name: es-master
  ```

* 오류 내용

  ```
  2018-10-05 18:50:23,821 main ERROR Could not register mbeans java.security.AccessControlException: access denied ("javax.management.MBeanTrustPermission" "register")
          at java.security.AccessControlContext.checkPermission(AccessControlContext.java:472)
          at java.lang.SecurityManager.checkPermission(SecurityManager.java:585)
          at com.sun.jmx.interceptor.DefaultMBeanServerInterceptor.checkMBeanTrustPermission(DefaultMBeanServerInterceptor.java:1848)
          at com.sun.jmx.interceptor.DefaultMBeanServerInterceptor.registerMBean(DefaultMBeanServerInterceptor.java:322)
          at com.sun.jmx.mbeanserver.JmxMBeanServer.registerMBean(JmxMBeanServer.java:522)
          at org.apache.logging.log4j.core.jmx.Server.register(Server.java:389)
          at org.apache.logging.log4j.core.jmx.Server.reregisterMBeansAfterReconfigure(Server.java:167)
          at org.apache.logging.log4j.core.jmx.Server.reregisterMBeansAfterReconfigure(Server.java:140)
          at org.apache.logging.log4j.core.LoggerContext.setConfiguration(LoggerContext.java:556)
          at org.apache.logging.log4j.core.LoggerContext.start(LoggerContext.java:261)
          at org.apache.logging.log4j.core.impl.Log4jContextFactory.getContext(Log4jContextFactory.java:206)
          at org.apache.logging.log4j.core.config.Configurator.initialize(Configurator.java:220)
          at org.apache.logging.log4j.core.config.Configurator.initialize(Configurator.java:197)
          at org.elasticsearch.common.logging.LogConfigurator.configureStatusLogger(LogConfigurator.java:172)
          at org.elasticsearch.common.logging.LogConfigurator.configure(LogConfigurator.java:141)
          at org.elasticsearch.common.logging.LogConfigurator.configure(LogConfigurator.java:120)
          at org.elasticsearch.bootstrap.Bootstrap.init(Bootstrap.java:290)
          at org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:130)
          at org.elasticsearch.bootstrap.Elasticsearch.execute(Elasticsearch.java:121)
          at org.elasticsearch.cli.EnvironmentAwareCommand.execute(EnvironmentAwareCommand.java:69)
          at org.elasticsearch.cli.Command.mainWithoutErrorHandling(Command.java:134)
          at org.elasticsearch.cli.Command.main(Command.java:90)
          at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:92)
          at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:85)
  
  ERROR: no log4j2.properties found; tried [/usr/share/elasticsearch/config] and its subdirectories
  ```

  * docker 컨테이너 내 /usr/share/elasticsearch/config 디렉토리가 바인딩 되면서 elasticsearch.yml 파일을 제외한 나머지 파일들이 제거되는 것으로 예상됨

  * mountPath를 파일(elasticsearch.yml )까지 지정하면 다음과 같은 오류 발생

    ```
    container_linux.go:247: starting container process caused "process_linux.go:359: container init caused \"rootfs_linux.go:54: mounting \\\"/var/lib/kubelet/pods/c74a26e7-c8cf-11e8-9f99-42010a920174/volumes/kubernetes.io~configmap/es-config\\\" to rootfs \\\"/var/lib/docker/overlay2/ba77e5cc3280e6775a92744613aafd87159f159702fdb5252d6d7c1bf7a91f3b/merged\\\" at \\\"/var/lib/docker/overlay2/ba77e5cc3280e6775a92744613aafd87159f159702fdb5252d6d7c1bf7a91f3b/merged/usr/share/elasticsearch/config/elasticsearch.yml\\\" caused \\\"not a directory\\\"\""
    yongho1037.gcp@kubernetes-control:~/2018-google-cloudjam-hackathon/elasticsearch/k8s$ vi deployments/elasticsearch-master.yml
    ```

* 현재는 Docker 이미지 빌드 시 config 파일을 포함시키도록 구성함



### GCP Registry 사용

* 가이드대로 진행 했으나 권한 오류 발생
* GCP의 Credential 관련 부분 확인 필요