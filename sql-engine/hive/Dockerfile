FROM fabric8/java-alpine-openjdk8-jdk

USER root

ENV JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk
ENV APP_HOME /opt

RUN set -ex && \
    apk upgrade --no-cache

# Installing JMX Exporter
ENV JMX_PROMETHEUS_JAVAAGENT_VERSION 0.3.1
ENV JMX_PROMETHEUS_JAVAAGENT_HOME /opt/jmx_prometheus_javaagent
ENV JMX_PROMETHEUS_JAVAAGENT_PORT 5556
ENV JMX_PROMETHEUS_JAVAAGENT_CONFIG ${JMX_PROMETHEUS_JAVAAGENT_HOME}/config.yml

RUN apk update && apk add --no-cache wget curl tar bash

RUN mkdir -p ${JMX_PROMETHEUS_JAVAAGENT_HOME} && \
    curl -s https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_PROMETHEUS_JAVAAGENT_VERSION}/jmx_prometheus_javaagent-${JMX_PROMETHEUS_JAVAAGENT_VERSION}.jar > ${JMX_PROMETHEUS_JAVAAGENT_HOME}/jmx_prometheus_javaagent.jar

# Installing Hadoop
ENV HADOOP_VERSION 2.10.1
ENV HADOOP_HOME $APP_HOME/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR $HADOOP_HOME/etc/hadoop/

RUN curl -fSL http://ftp.unicamp.br/pub/apache/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz -o hadoop-$HADOOP_VERSION.tar.gz && \
    mkdir -p $HADOOP_HOME && \
    tar -xzf hadoop-$HADOOP_VERSION.tar.gz && \
    mv hadoop-$HADOOP_VERSION $APP_HOME && \
    rm hadoop-$HADOOP_VERSION.tar.gz

RUN mkdir -p /hadoop/dfs/name && mkdir -p /hadoop/dfs/data

ENV PATH $HADOOP_HOME/bin/:$PATH

# Installing Hive
ENV APP_HOME /opt
ENV HIVE_VERSION 2.3.8
ENV HIVE_HOME $APP_HOME/hive
ENV HIVE_CONF $HIVE_HOME/conf

WORKDIR $APP_HOME

RUN curl -fSL http://ftp.unicamp.br/pub/apache/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz > apache-hive-$HIVE_VERSION-bin.tar.gz  && \
    tar -xzvf apache-hive-$HIVE_VERSION-bin.tar.gz && \
    mv apache-hive-$HIVE_VERSION-bin hive && \
	wget https://jdbc.postgresql.org/download/postgresql-9.4.1212.jar && \
	mv postgresql-9.4.1212.jar $HIVE_HOME/lib/postgresql-jdbc.jar && \
	rm apache-hive-$HIVE_VERSION-bin.tar.gz && \
	rm -rf /var/lib/apt/lists/*

COPY sql-engine/hive/config/core-site.xml $HADOOP_CONF_DIR
COPY sql-engine/hive/config/hadoop-env.sh $HADOOP_CONF_DIR
COPY sql-engine/hive/config/hive-site.xml $HIVE_HOME/conf
COPY sql-engine/hive/config/hive-env.sh $HIVE_HOME/conf
COPY sql-engine/hive/config/beeline-log4j2.properties $HIVE_HOME/conf
COPY sql-engine/hive/config/hive-exec-log4j2.properties $HIVE_HOME/conf
COPY sql-engine/hive/config/hive-log4j2.properties $HIVE_HOME/conf
COPY sql-engine/hive/config/ivysettings.xml $HIVE_HOME/conf
COPY sql-engine/hive/config/llap-daemon-log4j2.properties $HIVE_HOME/conf

COPY sql-engine/hive/startup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/startup.sh
RUN chmod -R +x $HADOOP_CONF_DIR

ENV PATH $HIVE_HOME/bin:$PATH

EXPOSE 10000 10002

CMD startup.sh
