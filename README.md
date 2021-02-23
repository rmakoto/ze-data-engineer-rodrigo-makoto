# Zé Delivery - Data Engineer Challenge

## Rodrigo Makoto Inoue

## Proposed Architectures

Since my background is mainly working with open-source technologies along with some managed AWS components. I am proposing 3 different solutions: A architecture using mostly AWS components, a open-source only architecture and a hybrid one using AWS and open-source.

### **Solution #1**: Using only AWS components

- AWS API Gateway (API to receive courier's events)
- AWS Lambda (Produce events to Kafka topic)
- AWS MSK (Managed Kafka)
- Schema Registry, KSQL, Kafka Connect running on EKS
- AWS S3 (Datalake)
- AWS Glue (Metastore)
- AWS Athena (SQL engine)

![AWS Architecture](/images/aws.jpg)

### **Solution #2**: Using only open-source components

- API (Nginx + fluentd)
- Kafka
- KSQL (JSON to Avro Stream converter)
- Schema Registry (Schema control)
- Kafka Connect (HDFS-Sink)
- HDFS (Datalake)
- Hive Metastore + Postgres (Metastore)
- All components running on K8S

![Open Source Architecture](/images/opensource.jpg)

### **Solution #3**: Hybrid solution using AWS and open source components

- AWS API Gateway (API to receive courier's events)
- AWS Lambda (Produce events to Kafka topic)
- Running on EKS
  - Kafka
  - KSQL (JSON to Avro Stream converter)
  - Schema Registry (Schema control)
  - Secor (Consume events from Kafka topics and store them in S3)
  - Hive Metastore (Metastore)
  - TrinoDB (SQL engine, former PrestoSQL)
- RDS Postgres (Hive Metastore database)
- AWS S3 (Datalake)

![Hybrid Architecture](/images/hybrid.jpg)

### Challenges Questions

#### **How are we going to receive all the location data from the couriers' app? What protocols, services, components we are going to use to proper receive the data, store it and be available to be used in other products**

- Should we create an API for it? 
- Should we use some specific managed component to receive this information? 
- Should we use queues, pub-sub mechanisms, serverless components? 

To capture couriers position events, I would suggest to create a API. AWS API Gateway, AWS Lambda and AWS MSK (Managed Kafka) are good options for this case. API Gateway would receive the events and Lambda would produce each event in JSON format to a MSK topic.
A important issue we have to consider, this API can be used to track not only courier GPS information, but to capture a range of different kind of events. Because of that, the events volume can increase super rapidly. Although API Gateway and Lambda are cheap, when we are dealing with huge volume of events, the costs can increase rapdily. A good alternative would be create a API using open-source solutions, like Nginx and fluentd.

#### **While receiving this location data associed with order's information, imagine we need to ingest more information to it**

- How would we do this? 
- In which layer that you have proposed in the previous answer?

To ingest more information to an existing event, we have to think how to deal with this new information to not break the entire pipeline that will come after it arrives. Firstly, each event MUST have a defined schema. To make this we can use KSQL to consume JSON topic, serializing each event to Avro format into a new topic, using Schema Registry to make control of event's schema. Avro and Schema Registry garantee that if a event comes with some new information or even a wrong existing attribute, it will not break the rest of the pipeline. To add this new information, we just have to deal with schema evolutions.

#### **We need to create an API to retrieve the last retrieved location from an order**

- How do you propose us to do this?
- While receiving location data, can you elaborate a solution to store the order's last location information?

In this architecture, we don't need to create a new API to receive the location when the order finishes, we can use the same API to receive all the events, making sure that each event has its own schema defined in Schema Registry. For example, let's consider the events `get_courier_location` and `order_status`.

```json
{
"event_name": "get_courier_location", 
"type": "GEO_LOCATION", 
"attributes": {
    "courier_id": "1",
    "order_id": 10, 
    "client_id": "123",
    "lat": 0.123123, 
    "long": 0.123123,
    "accuracy": "high",
    "speed": 50,
    "event_sent_timestamp": 213412213}
}
```

```json
{
"event_name": "order_status", 
"type": "ORDER", 
"attributes": {
    "courier_id": "1", 
    "order_id": 10, 
    "client_id": "123",
    "status": "finished",
    "lat": 0.123123, 
    "long": 0.123123,
    "accuracy": "high",
    "event_sent_timestamp": 12412323213}
}
```

With KSQL, we can create two different Streams to consume both events, each one being produced and stored in its own topic in Avro format. So if an application have to consume just `status: finished` events, it can consume the topic `order_status` and filter the ones with `status: finished`, or we can create another Stream to filter these specific events to another topic and make the application consume from there.

#### **If we need to notify the users about each order's status, how would you implement this while collecting the data?**

As stated in previous question, we can create Streams for `order_status` event and the service that notifies the users can consume from this topic.  

#### **How to store the data and how to make it available to be queried by our Data Analytics team?**

To make the data available for quering, we just have to consume each event topic, store them in Datalake (S3) and plug a SQL engine to make the data queriable. To accomplish this, we can use Kafka Connect with s3-sink plugin to land the data into Datalake and Hive Metastore + Trino (former PrestoSQL) or AWS Glue + Athena as SQL Engine. Since s3-sink plugin does not have support to repair Hive partitions, we can create a workaround using S3 Notifications + Lambda + DynamoDB, as proposed in this [article](https://aws.amazon.com/blogs/big-data/data-lake-ingestion-automatically-partition-hive-external-tables-with-aws/), or even use a open-source solution like [Secor](https://github.com/pinterest/secor), which has this support. In Glue + Athena case, we can use Glue crawlers to make datasets available for quering in Athena.

## Solution Demo

For this challenge propose, I am choosing to implement the open-source solution, because anyone can run it locally in Docker, without the need of external components in AWS. In production, I'd probably go with AWS or hybrid solution.

Unfortunatelly, I couln't automate each componenet configuration due to delivery deadline :sad-parrot:, but follow the step by step to make each component ready to run.

### How to Run

My local machine has only 8GB of RAM and a old dated processor, it cries when run everything together. Make sure to increase Docker memory and CPU resources, probably you are going to need.

Another issue that worth talking is that some containers might shut down or errors can popup in logs due to dependencies from another containers. For example, if you create KSQL Streams before creating a event to populate `courier_topic`, you will notice some errors in KSQL logs.

```bash
docker-compose build && \
docker-compose up -d
```

Go grab a coffee, it will take a while.

### **Data Ingestion**

### Tracking-api (Nginx + fluentd)

Tracking-api is composed of [NGINX](https://www.nginx.com/), which expose an endpoint that accepts a POST request and logs it to a file, and + [FluentD](https://www.fluentd.org/) which translate that log file into a JSON a sends it to `Kafka`.

Tracking-api is composed of [NGINX](https://www.nginx.com/), which expose an endpoint which accepts a POST request and logs it to a file. Fluentd is usually used for logging, so it can handle a huge volume of data. It translates that log file into a JSON and then produce to a Kafka topic `courier_events` using [fluent-plugin-kafka](https://docs.fluentd.org/v/0.12/output/kafka).

Examples to create a event to tracking-api:
Fluentd will create `courier_events` topic when the first event arrive.

- get_courier_location

    ```bash
    curl -X POST -H "Content-Type: application/json" \
    --data '{"event_name": "get_courier_location", "type": "GEO_LOCATION", "event_sent_timestamp": 213412213, "attributes": {"courier_id": "1", "order_id": 10,  "client_id": "123", "lat": 0.123123,  "long": 0.123123, "accuracy": "high", "speed": 50}}' \
    http://localhost:8000/events
    ```

- order_status

    ```bash
    curl -X POST -H "Content-Type: application/json" \
    --data '{"event_name": "order_status", "type": "ORDER", "event_sent_timestamp": 213412213, "attributes": {"courier_id": "1", "order_id": 10, "client_id": "123","status": "finished","lat": 0.123123, "long": 0.123123,"accuracy": "high"}}' \
    http://localhost:8000/events
    ```

Check created topics in Kafka

```bash
docker run \
   --net=host \
   --rm \
   confluentinc/cp-kafka:6.1.0 \
   kafka-topics --list --zookeeper localhost:2181
```

### Schema Validation

JSON is a fragile data format to work with, mainly because it is schemaless, in other words, its schema can change any time and can potentially break the rest of the pipeline. Serialized data formats like Avro and Protobuf ensure a schema for the data, avoiding several problems. In this challenge, we are going to use Avro.

Once we have events in `courier_events` topic in JSON format, we have to validate each of them if they match with its designed schema. To do that, we are going to consume `courier_events` with KSQL creating multiples Streams, it will create in Schema Registry a schema for each event defined in CREATE STREAM command and produce in `get_courier_location_avro` and `order_status_avro` topics in Avro serialized format.

Go inside KSQL container:

```bash
docker exec -it ze-data-engineer_ksql_1 bash
```

Type `ksql` to start a KSQL Client:

Spliting `courier_events` in multiples Streams

```sql
CREATE STREAM courier_events
    (event_name VARCHAR, 
    type VARCHAR, 
    attributes VARCHAR)
WITH (KAFKA_TOPIC='courier_events', 
      VALUE_FORMAT='JSON');

CREATE STREAM get_courier_location_json
    WITH (VALUE_FORMAT='JSON', KAFKA_TOPIC='get_courier_location_json') 
    AS SELECT * FROM courier_events
    WHERE event_name = 'get_courier_location';

CREATE STREAM order_status_json
    WITH (VALUE_FORMAT='JSON', KAFKA_TOPIC='order_status_json') 
    AS SELECT * FROM courier_events
    WHERE event_name = 'order_status';
```

Defining `get_courier_location` event schema and creating a Stream to convert to Avro format

```sql
CREATE STREAM get_courier_location_json
    (event_name VARCHAR
    type VARCHAR
    collector_timestamp DOUBLE
    event_sent_timestamp DOUBLE
    attributes STRUCT< 
        courier_id VARCHAR
        order_id INT
        client_id VARCHAR
        status VARCHAR
        lat DOUBLE
        long DOUBLE
        accuracy VARCHAR
        speed INT>)
WITH (KAFKA_TOPIC='get_courier_location_json', 
      VALUE_FORMAT='JSON');

CREATE STREAM get_courier_location_avro 
    WITH (VALUE_FORMAT='AVRO', KAFKA_TOPIC='get_courier_location_avro') 
    AS SELECT * FROM get_courier_location_json;
```

Defining `order_status` event schema and creating a Stream to convert to Avro format

```sql
CREATE STREAM order_status_json
    (event_name VARCHAR
    type VARCHAR
    collector_timestamp DOUBLE
    event_sent_timestamp DOUBLE
    attributes STRUCT<
        courier_id VARCHAR
        order_id INT
        client_id VARCHAR
        status VARCHAR
        lat DOUBLE
        long DOUBLE
        accuracy VARCHAR>)
WITH (KAFKA_TOPIC='order_status_json', 
      VALUE_FORMAT='JSON');

CREATE STREAM order_status_avro 
    WITH (VALUE_FORMAT='AVRO', KAFKA_TOPIC='order_status_avro') 
    AS SELECT * FROM order_status_json;
```

Check created Streams
```bash
# show existing streams
SHOW STREAMS

# drop a stream
DROP STREAM [IF EXISTS] stream_name [DELETE TOPIC];
```

Check if Avro schemas were created in Schema Registry

```bash
curl -X GET http://schema-registry:8081/subjects

# Schema Registry UI URL
http://localhost:8001/#/
```

### Configuring Hive Metastore

Before create Kafka Connect connectors start data ingestion to Datalake, let's configure Hive Metastore. We need to create a database `events` and each event table.

Go inside Hive container:

```bash
docker exec -it ze-data-engineer_hive_1 bash
```

Type `hive` to start a Hive Client:

```sql
CREATE DATABASE events;
USE events;

CREATE EXTERNAL TABLE get_courier_location
ROW FORMAT SERDE
'org.apache.hadoop.hive.serde2.avro.AvroSerDe'
STORED AS INPUTFORMAT
'org.apache.hadoop.hive.ql.io.avro.AvroContainerInputFormat'
OUTPUTFORMAT
'org.apache.hadoop.hive.ql.io.avro.AvroContainerOutputFormat'
TBLPROPERTIES (
'avro.schema.url'='http://schema-registry:8081/subjects/get_courier_location_avro.avsc'
LOCATION '/topics/get_courier_location_avro');

CREATE EXTERNAL TABLE order_status
ROW FORMAT SERDE
'org.apache.hadoop.hive.serde2.avro.AvroSerDe'
STORED AS INPUTFORMAT
'org.apache.hadoop.hive.ql.io.avro.AvroContainerInputFormat'
OUTPUTFORMAT
'org.apache.hadoop.hive.ql.io.avro.AvroContainerOutputFormat'
TBLPROPERTIES (
'avro.schema.url'='http://schema-registry:8081/subjects/order_status.avsc'
LOCATION '/topics/order_status_avro');
```

VERIFY SCHEMA URL



### Storing in Datalake

Now that we have validated events in `get_courier_location_avro` and `order_status_avro` topics, we are going to use Kafka Connect with [HDFS-Sink plugin](https://docs.confluent.io/kafka-connect-hdfs/current/index.html) to store all these events into HDFS (Datalake).

Creating Kafka Connect Connector for `get_courier_location_avro`

```bash
curl http://localhost:8083/connectors -X POST -H "Content-Type: application/json" \
--data '{"name": "get_courier_location_avro-sink",
"config": {
    "connector.class": "io.confluent.connect.hdfs2.Hdfs2SinkConnector",
    "tasks.max": "1",
    "topics": "get_courier_location_avro",
    "hdfs.url": "hdfs://namenode:9000",
    "flush.size": "3",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url":"http://schema-registry:8081",
    "confluent.topic.bootstrap.servers": "kafka:9092",
    "confluent.topic.replication.factor": "1",
    "hive.database": "events",
    "schema.generator.class": "io.confluent.connect.storage.hive.schema.DefaultSchemaGenerator",
    "hive.integration": "true",
    "hive.metastore.uris": "thrift://hive-metastore:9083",
    "schema.compatibility": "BACKWARD"}}'
```

Creating Kafka Connect Connector for `order_status_avro`

```bash
curl http://localhost:8083/connectors -X POST -H "Content-Type: application/json" \
--data '{"name": "order_status_avro-sink",
"config": {
    "connector.class": "io.confluent.connect.hdfs2.Hdfs2SinkConnector",
    "tasks.max": "1",
    "topics": "order_status_avro",
    "hdfs.url": "hdfs://namenode:9000",
    "flush.size": "3",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url":"http://schema-registry:8081",
    "confluent.topic.bootstrap.servers": "kafka:9092",
    "confluent.topic.replication.factor": "1",
    "hive.database": "events",
    "schema.generator.class": "io.confluent.connect.storage.hive.schema.DefaultSchemaGenerator",
    "hive.integration": "true",
    "hive.metastore.uris": "thrift://hive-metastore:9083",
    "schema.compatibility": "BACKWARD"}}'
```

Check Connectors status

``` bash
# list created connectors
curl -s -X GET http://localhost:8083/connectors/

# check order_status_avro-sink status
curl -s -X GET http://localhost:8083/connectors/order_status_avro-sink/status

# delete a existing connector
curl -X DELETE http://localhost:8083/connectors/order_status_avro-sink
```

Check `HDFS UI` to check if files arrived in Datalake

```url
http://localhost:9870/explorer.html
```

### **Data Consumption**

### Consuming the data

With events stored in datalake, now we have to make them avalilable for quering.

HDFS-Sink plugin has support to repair Hive tables partions in Hive Metastore automatically after the data is stored in HDFS. So it will be available for quering right after the data arrives in Datalake.

AWS Athena runs Presto behind it, so the equivalent open-source would be [Presto](https://trino.io/blog/2020/12/27/announcing-trino.html) or [Trino](https://trino.io/), the latter was choosen to be our SQL engine. Trino, [former PrestoSQL](https://trino.io/blog/2020/12/27/announcing-trino.html), can connect to several data sources (catalogs), in this case we are going to use Hive catalog. And it has some advantages over Presto:

- Community and user focused
- Growing at a faster pace, more active contributors
- Several bugs fixed
- New features like Cost Based Optimizer (CBO) and Security

Go inside Trino container:

```bash
docker exec -it ze-data-engineer_trino-coordinator_1 bash
```

Start a Trino client:

```bash
trino --server localhost:8080 --catalog hive --schema events

trino> select * from events.get_courier_location;
```

Check Trino UI

```
http://localhost:8080/ui/login.html
```

## Next Steps

- Automate each component configuration
- Monitoring with Prometheus + Grafana
- Tests
- Run on K8S
- Create K8s yaml files / Helm templates or use 3rd party Helm charts
