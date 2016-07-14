#!/bin/bash

cd /root/devicemanagerdemo/demo-files

#Start Kafka
KAFKASTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/KAFKA | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$KAFKASTATUS" == INSTALLED ]; then
	>&2 echo "Starting Kafka Broker..."
	TASKID=$(curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Kafka via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/KAFKA | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "AMBARI TaskID " $TASKID
	sleep 2
fi

sleep 1
# Start NIFI service
NIFISTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$NIFISTATUS" == INSTALLED ]; then
	>&2 echo "Starting NIFI Service"
	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Start NIFI"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep "id" | grep -Po '([0-9]+)')

	>&2 echo "AMBARI TaskID " $TASKID
fi

sleep 1
#Start HBASE
HBASESTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/HBASE | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$HBASESTATUS" == INSTALLED ]; then
	>&2 echo "Starting  Hbase Service..."
	TASKID=$(curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Hbase via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/HBASE | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "HBASE TaskId " $TASKID
fi

# Start Storm
STORMSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/STORM | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$STORMSTATUS" == INSTALLED ]; then
	>&2 echo "Starting Storm Service..."
	TASKID=$(curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Storm via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/STORM | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "STORM TaskId " $TASKID
fi




# Clear Slider working directory
sudo -u hdfs hadoop fs -rm -R /user/root/.slider/cluster
# Ensure docker service is running
service docker start
# Start UI servlet on Yarn using Slider
slider create mapui --template /home/docker/dockerbuild/mapui/appConfig.json --metainfo /home/docker/dockerbuild/mapui/metainfo.json --resources /home/docker/dockerbuild/mapui/resources.json
# yarn application -kill $(yarn application -list | grep -Po '(application_[0-9]+_[0-9]+)\s(biologicsmanufacturingui)' | grep -Po '(application_[0-9]+_[0-9]+)')

nohup spark-submit --class com.hortonworks.iot.spark.streaming.SparkNostradamus --master local[4] /home/spark/DeviceMonitorNostradamus-0.0.1-SNAPSHOT-jar-with-dependencies.jar >> /root/devicemanagerdemo/demo-files/DeviceMonitorNostradamus.log 2>&1 &