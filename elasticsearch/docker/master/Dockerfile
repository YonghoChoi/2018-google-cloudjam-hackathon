FROM docker.elastic.co/elasticsearch/elasticsearch:6.0.1
  
MAINTAINER clghks@gmail.com

RUN yum install -y gcc-c++ make zip

RUN wget http://www.kwangsiklee.com/wp-content/uploads/2017/02/mecab-0.996-ko-0.9.2.tar-1.gz
RUN tar -xvzf mecab-0.996-ko-0.9.2.tar-1.gz
RUN cd mecab-0.996-ko-0.9.2 && ./configure && make && make check && make install && ldconfig

RUN wget https://bitbucket.org/eunjeon/mecab-ko-dic/downloads/mecab-ko-dic-2.1.1-20180720.tar.gz
RUN tar -xvzf mecab-ko-dic-2.1.1-20180720.tar.gz
RUN cd mecab-ko-dic-2.1.1-20180720 && ./configure && make && make install

RUN wget https://bitbucket.org/eunjeon/seunjeon/raw/master/elasticsearch/scripts/downloader.sh && chmod +x downloader.sh && ./downloader.sh -e 6.0.1 -p 6.0.0.1
RUN ./bin/elasticsearch-plugin install file://`pwd`/elasticsearch-analysis-seunjeon-6.0.0.1.zip

COPY elasticsearch.yml /usr/share/elasticsearch/config/
