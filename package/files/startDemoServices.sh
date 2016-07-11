#!/bin/bash

cd /root/devicemanagerdemo/package/files

#Start Kafka
KAFKASTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/KAFKA | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$KAFKASTATUS" == INSTALLED ]; then
	>&2 echo "Starting Kafka Broker..."
	TASKID=$(curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Kafka via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/KAFKA | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "AMBARI TaskID " $TASKID
	sleep 2

	LOOPESCAPE="false"

	until [ "$LOOPESCAPE" == true ]; do

		TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
		if [ "$TASKSTATUS" == COMPLETED ]; then
			LOOPESCAPE="true"
 		fi
		
		>&2 echo "Task Status" $TASKSTATUS
		sleep 2
	done
	>&2 echo "Kafka Broker Started..."

elif [ "$KAFKASTATUS" == STARTED ]; then
	>&2 echo "Kafka Broker Started..."
else
	>&2 echo "Kafka Broker in a transition state. Wait for process to complete and then run the install script again."
	exit 1
fi

sleep 1
# Start NIFI service
NIFISTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$NIFISTATUS" == INSTALLED ]; then
	>&2 echo "Starting NIFI Service"
	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Start NIFI"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep "id" | grep -Po '([0-9]+)')

	>&2 echo "AMBARI TaskID " $TASKID
	sleep 2

	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do

        	TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
        	if [ "$TASKSTATUS" == COMPLETED ]; then
                	LOOPESCAPE="true"
        	fi

        	>&2 echo "Task Status" $TASKSTATUS
        	sleep 2
	done
        >&2 echo "NIFI Service Started..."

elif [ "$NIFISTATUS" == STARTED ]; then
        >&2 echo "NIFI Service Started..."
else
        >&2 echo "NIFI Service in a transition state. Wait for process to complete and then run the install script again."
        exit 1
fi

sleep 1
#Start HBASE
HBASESTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/HBASE | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$HBASESTATUS" == INSTALLED ]; then
	>&2 echo "Starting  Hbase Service..."
	TASKID=$(curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Hbase via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/HBASE | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "HBASE TaskId " $TASKID
	sleep 2

	LOOPESCAPE="false"

	until [ "$LOOPESCAPE" == true ]; do

		TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
		if [ "$TASKSTATUS" == COMPLETED ]; then
			LOOPESCAPE="true"
 		fi

		>&2 echo "Task Status" $TASKSTATUS
		sleep 2
	done
	>&2 echo "Hbase Service Started..."

elif [ "$HBASESTATUS" == STARTED ]; then
	>&2 echo "Hbase Service  Started..."
else
	>&2 echo "Hbase Service in a transition state. Wait for process to complete and then run the install script again."
	exit 1
fi

sleep 1
# Start Storm
STORMSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/STORM | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$STORMSTATUS" == INSTALLED ]; then
	>&2 echo "Starting Storm Service..."
	TASKID=$(curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Storm via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/STORM | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "STORM TaskId " $TASKID
	sleep 2

	LOOPESCAPE="false"

	until [ "$LOOPESCAPE" == true ]; do

		TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
		if [ "$TASKSTATUS" == COMPLETED ]; then
			LOOPESCAPE="true"
 		fi
		
		>&2 echo "Task Status" $TASKSTATUS
		sleep 2
	done
	>&2 echo "Storm Service Started..."

elif [ "$STORMSTATUS" == STARTED ]; then
	>&2 echo "Storm Service Started..."
else
	>&2 echo "Storm Service in a transition state. Wait for process to complete and then run the install script again."
	exit 1
fi

# Clear Slider working directory
sudo -u hdfs hadoop fs -rm -R /user/root/.slider/cluster
# Ensure docker service is running
service docker start
# Start UI servlet on Yarn using Slider
slider create mapui --template /home/docker/dockerbuild/mapui/appConfig.json --metainfo /home/docker/dockerbuild/mapui/metainfo.json --resources /home/docker/dockerbuild/mapui/resources.json
# yarn application -kill $(yarn application -list | grep -Po '(application_[0-9]+_[0-9]+)\s(biologicsmanufacturingui)' | grep -Po '(application_[0-9]+_[0-9]+)')
nohup spark-submit --class com.hortonworks.iot.spark.streaming.SparkNostradamus --master local[4] /home/spark/DeviceMonitorNostradamus-0.0.1-SNAPSHOT-jar-with-dependencies.jar >> /root/devicemanagerdemo/package/configuration/files/DeviceMonitorNostradamus.log &