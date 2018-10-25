# GCP Hackathon 2018

* 2018년 GCP Study Jam에서 진행한 GCP Hackathon을 위해 준비한 내용입니다.

![](images/gcp-hackathon-2018.jpg)



## 1. Kubernetes 클러스터 생성

1. GCP 프로젝트에서 쿠버네티스 클러스터를 사용할 수 있도록 준비 절차가 필요하다. GCP Kubernetes Engine 페이지에 최조 접속 시 자동으로 준비 

2. Google Cloud Shell에서 다음 명령 실행

   ```shell
   gcloud config set compute/zone asia-northeast1-b
   gcloud container clusters create hackathon --machine-type n1-standard-2
   ```

   * Elasticsearch 구동을 위해 n1-standard-2 머신 유형 사용 (vcpu : 2, mem : 7.50g)

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



## 2 Movie Finder 이미지 생성

### 2.1 Movie Finder 빌드

```shell
cd movie-finder/app && \
npm install && \
npm run build
```



### 2.2 Movie Finder Dockerfile

```Dockerfile
FROM nginx

RUN mkdir /app
ADD ./app/dist/ /app
ADD ./app/nginx/nginx.conf /etc/nginx/nginx.conf

WORKDIR /app
```

* 앞서 진행한 빌드 산출물을 Docker 이미지에 추가
* nginx를 사용하여 웹 호스팅
* 이미지 빌드 및 푸시는 "4. Container Registry에 이미지 push" 참고



## 3. 엘라스틱서치 이미지 생성

### 3.1 Elasticsearch Dockerfile

1. elasticsearch.yml 준비

   ```yaml
   cluster.name: ${CLUSTER_NAME}
   network.host: ${NETWORK_HOST}
   
   node.master: ${NODE_MASTER}
   node.data: ${NODE_DATA}
   node.ingest: ${NODE_INGEST}
   
   http.cors.enabled: true
   http.cors.allow-origin: "*"
   http.cors.allow-methods: OPTIONS, HEAD, GET, POST, PUT, DELETE
   http.cors.allow-headers: "X-Requested-With,X-Auth-Token,Content-Type, Content-Length, Authorization"
   
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
   ENV HTTP_ENABLED=true
   ENV SERVICE=es-k8s-cluster
   ENV KUBERNETES_NAMESPACE=default
   ENV NUMBER_OF_MASTERS=1
   
   RUN yum install -y gcc-c++ make zip deltarpm
   RUN wget http://www.kwangsiklee.com/wp-content/uploads/2017/02/mecab-0.996-ko-0.9.2.tar-1.gz
   RUN tar -xvzf mecab-0.996-ko-0.9.2.tar-1.gz
   RUN cd mecab-0.996-ko-0.9.2 && ./configure && make && make check && make install && ldconfig
   
   RUN wget https://bitbucket.org/eunjeon/mecab-ko-dic/downloads/mecab-ko-dic-2.1.1-20180720.tar.gz
   RUN tar -xvzf mecab-ko-dic-2.1.1-20180720.tar.gz
   RUN cd mecab-ko-dic-2.1.1-20180720 && ./configure && make && make install
   
   COPY --chown=elasticsearch:elasticsearch elasticsearch.yml /usr/share/elasticsearch/config/
   COPY --chown=elasticsearch:elasticsearch elasticsearch-analysis-seunjeon-6.1.1.0.zip /usr/share/elasticsearch/
   COPY --chown=elasticsearch:elasticsearch elasticsearch-hangul-jamo-analyzer-6.2.3.zip /usr/share/elasticsearch/
   
   RUN ./bin/elasticsearch-plugin install file://`pwd`/elasticsearch-analysis-seunjeon-6.1.1.0.zip
   RUN ./bin/elasticsearch-plugin install file://`pwd`/elasticsearch-hangul-jamo-analyzer-6.2.3.zip
   RUN ./bin/elasticsearch-plugin install io.fabric8:elasticsearch-cloud-kubernetes:6.2.3.2
   ```

   * 쿠버네티스 클러스터에서 엘라스틱서치 노드간 Discovery를 위해 fabric8 플러그인을 사용한다.
   * fabric8 플러그인이 지원하는 엘라스틱서치의 최신 버전이 6.2.3이기 때문에 해당 버전의 엘라스틱서치 이미지를 사용한다.
   * 은전한닢이 6.1.1.0 이후에 지원이되고 있지 않는데, 은전한닢 압축파일을 다운로드 받은 후 해당 파일 내 properties 파일을 수정하여 Elasticsearch 버전을 6.2.3 버전으로 맞춘다.
     * Elasticsearch 현시점 최신 버전 6.4.2에서는 플러그인의 디렉토리 구조가 변경되어 플러그인 디렉토리 구조에서 elasticsearch 디렉토리 내 파일들을 상위로 이동 시켜서 사용한다.
   * 최신 버전에서는 플러그인 압축파일 내 elasticsearch 디렉토리를 사용하지 않기 때문에 여기서는 elasticsearch 디렉토리 제거한 zip 파일을 Docker 이미지에 Copy해서 사용한다.
   * 은전한닢 플러그인 설치 시에 elasticsearch.yml 파일을 참조하기 때문에 위에서 작성한 elasticsearch.yml 파일로 대체하는 것은 가장 마지막에 수행한다.
   * 이미지 빌드 및 푸시는 "4. Container Registry에 이미지 push" 참고



### 4. Container Registry에 이미지 push

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



## 5. Kubernetes Elasticsearch Cluster 구성

### 5.1 Deployment 구성

```shell
apiVersion: extensions/v1beta1
kind: "Deployment"
metadata:
  name: "elasticsearch-data"
spec:
  replicas: 2
  selector:
    matchLabels:
      component: "elasticsearch"
      type: "data"
      provider: "fabric8"
  template:
    metadata:
      labels:
        component: "elasticsearch"
        type: "data"
        provider: "fabric8"
    spec:
      serviceAccount: elasticsearch
      serviceAccountName: elasticsearch
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
        - env:
            - name: "SERVICE"
              value: "elasticsearch-cluster"
            - name: "KUBERNETES_NAMESPACE"
              valueFrom:
                fieldRef:
                  fieldPath: "metadata.namespace"
            - name: "NODE_MASTER"
              value: "true"
            - name: "NODE_DATA"
              value: "true"
            - name: "NODE_INGEST"
              value: "true"
            - name: "ES_JAVA_OPTS"
              value: "-Xms1g -Xmx1g"
          image: "gcr.io/gcp-summit-2018/elasticsearch:6.2.3"
          imagePullPolicy: Always
          name: "elasticsearch"
          ports:
            - containerPort: 9300
              name: "transport"
          volumeMounts:
            - mountPath: "/usr/share/elasticsearch/data"
              name: "elasticsearch-data"
              readOnly: false
          readinessProbe:
            httpGet:
              path: /
              port: 9200
            initialDelaySeconds: 10
            periodSeconds: 15
            timeoutSeconds: 5
      volumes:
        - emptyDir:
            medium: ""
          name: "elasticsearch-data"
```

* 환경 변수 설정을 제외하고 coordinating node, data node, master node 형식 동일
* initContainers를 통해 Pod의 설정 초기화
* readinessProbe를 통해 실행 가능 여부 체크



### 5.2 서비스 구성

#### 5.2.1 Discovery를 위한 Service 작성

```yaml
apiVersion: v1
kind: "Service"
metadata:
  name: "elasticsearch-cluster"
spec:
  clusterIP: "None"
  ports:
    - port: 9300
      targetPort: 9300
  selector:
    provider: "fabric8"
    component: "elasticsearch"
```

* Elasticsearch에서 클러스터의 각 노드들을 발견하기 위해서 Zen Discovery를 사용하는데, 이 때 각 노드를 찾기 위해 transport 모듈을 사용하게 된다. Deployment 설정에서 transport 통신을 위한 포트를 9300으로 지정했기 때문에 서비스 생성 시 클러스터 내 노드간 통신을 위해 9300 포트를 지정한다.
* 내부통신이기 때문에 로드밸런서 타입은 ClusterIP를 사용한다.



#### 5.2.2 Movie finder 웹 서버와 통신하기 위한 Service 작성

```yaml
apiVersion: v1
kind: "Service"
metadata:
  name: "elasticsearch-connector"
spec:
  ports:
    - port: 9200
      targetPort: 9200
  selector:
    role: "es-connect"
```

* 엘라스틱서치 클러스터에서 통신을 담당하는 coordinating node와 ClusterIP로 연결
* Movie finder 웹 서버와 엘라스틱서치 coordinaiting node는 role=es-connect Label을 통해 서비스 연결



### 5.3 Elasticsearch로 접속 확인

1. 30001 방화벽 오픈

   ```
   gcloud compute firewall-rules create allow-elasticsearch-nodeport --allow=tcp:30001
   ```

2. 쿠버네티스 워커 노드 인스턴스 주소 확인

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

3. Elasticsearch 접속 확인

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

4. 클러스터 연결 확인

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



## 6. Movie Finder Kubernetes 구성

### 6.2 Deployment

```yaml
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: movie-finder-deployment
spec:
  selector:
    matchLabels: 
      app: movie-finder
  replicas: 2
  template: 
    metadata:
      labels:
        app: movie-finder
        role: es-connect
    spec:
      containers:
      - name: movie-finder
        image: wowyo3/movie-finder-javacafe
        ports:
        - containerPort: 8080
```



###6.3 사용자가 외부에서 접속할 수 있도록 Service 생성

```yaml
apiVersion: v1
kind: Service
metadata:
  name: movie-finder
spec:
  type: LoadBalancer
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: movie-finder
```

* GCP 로드밸런서 생성
* 내부의 웹 서버와 연동



## 7. Trouble Shooting

### 7.1 ConfigMap 사용

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



### 7.2 GCP Registry 사용

* 가이드대로 진행 했으나 권한 오류 발생
* GCP의 Credential 관련 부분 확인 필요



### 7.3 은전한닢 버전 호환 문제 해결

```
-> Downloading file:///usr/share/elasticsearch/elasticsearch-analysis-seunjeon-6.1.1.0.zip
[=================================================] 100%??
Exception in thread "main" java.lang.IllegalArgumentException: Plugin [analysis-seunjeon] was built for Elasticsearch version 6.1.1 but version 6.4.2 is running
        at org.elasticsearch.plugins.PluginsService.verifyCompatibility(PluginsService.java:339)
        at org.elasticsearch.plugins.InstallPluginCommand.loadPluginInfo(InstallPluginCommand.java:717)
        at org.elasticsearch.plugins.InstallPluginCommand.installPlugin(InstallPluginCommand.java:792)
        at org.elasticsearch.plugins.InstallPluginCommand.install(InstallPluginCommand.java:775)
        at org.elasticsearch.plugins.InstallPluginCommand.execute(InstallPluginCommand.java:231)
        at org.elasticsearch.plugins.InstallPluginCommand.execute(InstallPluginCommand.java:216)
        at org.elasticsearch.cli.EnvironmentAwareCommand.execute(EnvironmentAwareCommand.java:86)
        at org.elasticsearch.cli.Command.mainWithoutErrorHandling(Command.java:124)
        at org.elasticsearch.cli.MultiCommand.execute(MultiCommand.java:77)
        at org.elasticsearch.cli.Command.mainWithoutErrorHandling(Command.java:124)
        at org.elasticsearch.cli.Command.main(Command.java:90)
        at org.elasticsearch.plugins.PluginCli.main(PluginCli.java:47)
The command '/bin/sh -c ./bin/elasticsearch-plugin install file://`pwd`/elasticsearch-analysis-seunjeon-6.1.1.0.zip' returned a non-zero code: 1
```







## 8. 참고

* [엘라스틱서치 디스커버리 관련](https://github.com/fabric8io/elasticsearch-cloud-kubernetes/blob/master/README.md)
* [headless-service](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)
* [엘라스틱서치 클러스터 구성](http://kimjmin.net/2018/01/2018-01-build-es-cluster-5/)
* [Elasticsearch Node](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html)
