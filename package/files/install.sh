#!/bin/bash

cd /root/devicemanagerdemo/package/files

VERSION=`hdp-select status hadoop-client | sed 's/hadoop-client - \([0-9]\.[0-9]\).*/\1/'`
INTVERSION=$(echo $VERSION*10 | bc | grep -Po '([0-9][0-9])')
>&2 echo "*********************************SANDBOX VERSION IS $VERSION" 
if [ "$INTVERSION" -lt 24 ]; then	
	>&2 echo "*********************************Downloading NIFI..." 
	sudo git clone https://github.com/abajwa-hw/ambari-nifi-service.git  /var/lib/ambari-server/resources/stacks/HDP/$VERSION/services/NIFI
	service ambari restart
	>&2 echo "*********************************Install Zeppelin Notebook"
	cp -rvf Zeppelin/notebook/* /usr/hdp/current/zeppelin-server/lib/notebook/
else
	>&2 echo "*********************************Install Zeppelin Notebook"
	cp -rvf Zeppelin/notebook/* /usr/hdp/current/zeppelin-server/lib/notebook/  
fi

# Wait for Ambari
LOOPESCAPE="false"
until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -u admin:admin -I -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox | grep -Po 'OK')
        if [ "$TASKSTATUS" == OK ]; then
                LOOPESCAPE="true"
                TASKSTATUS="READY"
        else
        		AUTHSTATUS=$(curl -u admin:admin -I -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox | grep HTTP | grep -Po '( [0-9]+)'| grep -Po '([0-9]+)')
                if [ "$AUTHSTATUS" == 403 ]; then
                	>&2 echo "THE AMBARI PASSWORD IS NOT SET TO: admin"
                	>&2 echo "RUN COMMAND: ambari-admin-password-reset, SET PASSWORD: admin"
                	exit 403
                else
                	TASKSTATUS="PENDING"
                fi
        fi
		>&2 echo "Waiting for Ambari..."
        >&2 echo "Ambari Status... " $TASKSTATUS
        sleep 2
done

>&2 echo "*********************************Changing YARN Container Memory Size..."
/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox yarn-site "yarn.scheduler.maximum-allocation-mb" "6144"
sleep 2
/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox yarn-site "yarn.nodemanager.resource.memory-mb" "6144"

# Ensure that Yarn is not in a transitional state
YARNSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/YARN | grep '"state" :' | grep -Po '([A-Z]+)')
sleep 2
>&2 echo "YARN STATUS: $YARNSTATUS"
LOOPESCAPE="false"
if ! [[ "$YARNSTATUS" == STARTED || "$YARNSTATUS" == INSTALLED ]]; then
        until [ "$LOOPESCAPE" == true ]; do
                TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/YARN | grep '"state" :' | grep -Po '([A-Z]+)')
                if [[ "$TASKSTATUS" == STARTED || "$TASKSTATUS" == INSTALLED ]]; then
                        LOOPESCAPE="true"
                fi
                >&2 echo "*********************************Task Status" $TASKSTATUS
                sleep 2
        done
fi

sleep 2
>&2 echo "*********************************Restarting YARN..."
if [ "$YARNSTATUS" == STARTED ]; then
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context": "Stop YARN"}, "ServiceInfo": {"state": "INSTALLED"}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/YARN | grep "id" | grep -Po '([0-9]+)')
        >&2 echo "*********************************AMBARI TaskID " $TASKID
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
                TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
                if [ "$TASKSTATUS" == COMPLETED ]; then
                        LOOPESCAPE="true"
                fi
                >&2 echo "*********************************Task Status" $TASKSTATUS
                sleep 2
        done
elif [ "$YARNSTATUS" == INSTALLED ]; then
        >&2 echo "YARN Service Stopped..."
fi

TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context": "Start YARN"}, "ServiceInfo": {"state": "STARTED"}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/YARN | grep "id" | grep -Po '([0-9]+)')
>&2 echo "*********************************AMBARI TaskID " $TASKID
sleep 2
LOOPESCAPE="false"
until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
        if [ "$TASKSTATUS" == COMPLETED ]; then
                LOOPESCAPE="true"
        fi
        >&2 echo "*********************************Task Status" $TASKSTATUS
        sleep 2
done

# Check if NIFI Service is Installed
NIFISTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep '"state" :' | grep -Po '([A-Z]+)')
if ! [[ "$NIFISTATUS" == INSTALLED || "$NIFISTATUS" == STARTED ]]; then
	>&2 echo "*********************************Creating NIFI service..."
	# Create NIFI service
	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI

	sleep 2
	>&2 echo "*********************************Adding NIFI MASTER component..."
	# Add NIFI Master component to service
	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI/components/NIFI_MASTER

	sleep 2
	>&2 echo "*********************************Creating NIFI configuration..."

	# Create and apply configuration
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-ambari-config /root/devicemanagerdemo/package/files/Nifi/config/nifi-ambari-config.json
	sleep 2
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-bootstrap-env /root/devicemanagerdemo/package/files/Nifi/config/nifi-bootstrap-env.json
	sleep 2
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-flow-env /root/devicemanagerdemo/package/files/Nifi/config/nifi-flow-env.json
	sleep 2
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-logback-env /root/devicemanagerdemo/package/files/Nifi/config/nifi-logback-env.json
	sleep 2
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-properties-env /root/devicemanagerdemo/package/files/Nifi/config/nifi-properties-env.json

	sleep 2
	>&2 echo "*********************************Adding NIFI MASTER role to Host..."
	# Add NIFI Master role to Sandbox host
	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/hosts/sandbox.hortonworks.com/host_components/NIFI_MASTER

	sleep 2
	>&2 echo "*********************************Installing NIFI Service"
	# Install NIFI Service
	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Nifi"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "*********************************AMBARI TaskID " $TASKID
	sleep 2
	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
        if [ "$TASKSTATUS" == COMPLETED ]; then
                LOOPESCAPE="true"
        fi
        >&2 echo "*********************************Task Status" $TASKSTATUS
        sleep 2
	done
	>&2 echo "*********************************NIFI Service Installed..."

	sleep 2
	>&2 echo "*********************************Starting NIFI Service..."
else
	>&2 echo "*********************************NIFI Service Already Installed..."
fi

NIFISTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$NIFISTATUS" == INSTALLED ]; then
	# Start NIFI service
	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Start NIFI"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "*********************************AMBARI TaskID " $TASKID
	sleep 2
	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
        if [ "$TASKSTATUS" == COMPLETED ]; then
                LOOPESCAPE="true"
                >&2 echo "*********************************NIFI Service Started..."
        fi
        >&2 echo "*********************************Task Status" $TASKSTATUS
        sleep 2
	done
elif [ "$NIFISTATUS" == STARTED ]; then
	>&2 echo "*********************************NIFI Service Already Started..."
else
	>&2 echo "*********************************NIFI Service in a transition state. Wait for process to complete and then run the install script again."
	exit 1
fi

LOOPESCAPE="false"
until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -u admin:admin -i -X GET http://sandbox.hortonworks.com:9090/nifi-api/controller | grep -Po 'OK')
        if [ "$TASKSTATUS" == OK ]; then
                LOOPESCAPE="true"
        else
                TASKSTATUS="PENDING"
        fi
		>&2 echo "*********************************Waiting for NIFI Servlet..."
        >&2 echo "*********************************NIFI Servlet Status... " $TASKSTATUS
        sleep 2
done

>&2 echo "*********************************Importing NIFI Template..."
# Import NIFI Template
#TEMPLATEID=$(curl -v -F template=@"Nifi/template/DeviceManagerDemo.xml" -X POST http://sandbox.hortonworks.com:9090/nifi-api/controller/templates | grep -Po '<id>([a-z0-9-]+)' | grep -Po '>([a-z0-9-]+)' | grep -Po '([a-z0-9-]+)')
TEMPLATEID=$(curl -v -F template=@"Nifi/template/DeviceManagerDemo.xml" -X POST http://sandbox.hortonworks.com:9090/nifi-api/controller/templates | grep -Po '<id>([a-z0-9-]+)' | grep -Po '>([a-z0-9-]+)' | grep -Po '([a-z0-9-]+)')
sleep 2
>&2 echo "*********************************Instantiating NIFI Flow..."
# Instantiate NIFI Template
REVISION=$(curl -u admin:admin  -i -X GET http://sandbox.hortonworks.com:9090/nifi-api/controller/revision |grep -Po '\"version\":([0-9]+)' | grep -Po '([0-9]+)')
curl -u admin:admin -i -H "Content-Type:application/x-www-form-urlencoded" -d "templateId=$TEMPLATEID&originX=100&originY=100&version=$REVISION" -X POST http://sandbox.hortonworks.com:9090/nifi-api/controller/process-groups/root/template-instance

>&2 echo "*********************************Installing Maven"
# Install Maven
wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
yum install -y apache-maven

>&2 echo "*********************************Building Storm Topology"
# Build Storm Topology from source
cd DeviceMonitor
mvn clean package 
cp target/DeviceMonitor-0.0.1-SNAPSHOT.jar /home/storm
cd ..

>&2 echo "*********************************Building Spark Topology"
Build Spark Project and Copy to working folder
cd DeviceMonitorNostradamus
mvn clean package
cp target/DeviceMonitorNostradamus-0.0.1-SNAPSHOT-jar-with-dependencies.jar /home/spark
cd ..

>&2 echo "*********************************Building Simulator"
#Build Device Simulator from source
git clone https://github.com/vakshorton/DataSimulators.git
cd DataSimulators/DeviceSimulator
mvn clean package
cp -vf target/DeviceSimulator-0.0.1-SNAPSHOT-jar-with-dependencies.jar ../..
cd ../..

#Start Kafka
KAFKASTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/KAFKA | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$KAFKASTATUS" == INSTALLED ]; then
	>&2 echo "*********************************Starting Kafka Broker..."
	TASKID=$(curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Kafka via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/KAFKA | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "*********************************AMBARI TaskID " $TASKID
	sleep 2
	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do
		TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
		if [ "$TASKSTATUS" == COMPLETED ]; then
			LOOPESCAPE="true"
 		fi
		>&2 echo "*********************************Task Status" $TASKSTATUS
		sleep 2
	done
	>&2 echo "*********************************Kafka Broker Started..."
elif [ "$KAFKASTATUS" == STARTED ]; then
	>&2 echo "*********************************Kafka Broker Started..."
else
	>&2 echo "*********************************Kafka Broker in a transition state. Wait for process to complete and then run the install script again."
	exit 1
fi

#Configure Kafka
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --zookeeper sandbox.hortonworks.com:2181 --replication-factor 1 --partitions 1 --topic TechnicianEvent
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --zookeeper sandbox.hortonworks.com:2181 --replication-factor 1 --partitions 1 --topic DeviceEvents

#Install and start Docker
tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

rpm -iUvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum -y install docker-io
groupadd docker
gpasswd -a yarn docker
service docker start
chkconfig --add docker
chkconfig docker on
sudo -u hdfs hadoop fs -mkdir /user/root/
sudo -u hdfs hadoop fs -chown root:hdfs /user/root/

#Create Docker working folder
mkdir /home/docker/
mkdir /home/docker/dockerbuild/
mkdir /home/docker/dockerbuild/mapui

#Copy Slider configurations to working folder
cd SliderConfig
cp -vf appConfig.json /home/docker/dockerbuild/mapui
cp -vf metainfo.json /home/docker/dockerbuild/mapui
cp -vf resources.json /home/docker/dockerbuild/mapui
cd ..

HBASESTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/HBASE | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$HBASESTATUS" == INSTALLED ]; then
	>&2 echo "*********************************Starting  Hbase Service..."
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

STORMSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/STORM | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$STORMSTATUS" == INSTALLED ]; then
	>&2 echo "*********************************Starting Storm Service..."
	TASKID=$(curl -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Storm via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/STORM | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "*********************************STORM TaskId " $TASKID
	sleep 2
	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do
		TASKSTATUS=$(curl -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
		if [ "$TASKSTATUS" == COMPLETED ]; then
			LOOPESCAPE="true"
 		fi
		>&2 echo "*********************************Task Status" $TASKSTATUS
		sleep 2
	done
	>&2 echo "*********************************Storm Broker Started..."
elif [ "$STORMSTATUS" == STARTED ]; then
	>&2 echo "*********************************Storm Service Started..."
else
	>&2 echo "*********************************Storm Service in a transition state. Wait for process to complete and then run the install script again."
	exit 1
fi

# Start NIFI Flow
>&2 echo "*********************************Starting NIFI Flow..."
REVISION=$(curl -u admin:admin  -i -X GET http://sandbox.hortonworks.com:9090/nifi-api/controller/revision |grep -Po '\"version\":([0-9]+)' | grep -Po '([0-9]+)')
TARGETS=($(curl -u admin:admin -i -X GET http://sandbox.hortonworks.com:9090/nifi-api/controller/process-groups/root/processors | grep -Po '\"uri\":\"([a-z0-9-://.]+)' | grep -Po '(?!.*\")([a-z0-9-://.]+)'))
length=${#TARGETS[@]}
for ((i = 0; i != length; i++)); do
   >&2 echo curl -u admin:admin -i -X GET ${TARGETS[i]}
   >&2 echo "Current Revision: " $REVISION
   curl -u admin:admin -i -H "Content-Type:application/x-www-form-urlencoded" -d "state=RUNNING&version=$REVISION" -X PUT ${TARGETS[i]}
   REVISION=$(curl -u admin:admin  -i -X GET http://sandbox.hortonworks.com:9090/nifi-api/controller/revision |grep -Po '\"version\":([0-9]+)' | grep -Po '([0-9]+)')
done

# Deploy Storm Topology
>&2 echo "*********************************Deploying Storm Topology..."
storm jar /home/storm/DeviceMonitor-0.0.1-SNAPSHOT.jar com.hortonworks.iot.topology.DeviceMonitorTopology

>&2 echo "*********************************Downloading Docker Images for UI..."
# Download Docker Images
service docker start
docker pull vvaks/mapui
docker pull vvaks/cometd

#Create SOLR service script
mv /etc/init.d/solr /etc/init.d/solr_bak
tee /etc/init.d/solr <<-'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          solr
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Controls Apache Solr as a Service
### END INIT INFO

SOLR_INSTALL_DIR=/opt/lucidworks-hdpsearch/solr

if [ ! -d "$SOLR_INSTALL_DIR" ]; then
  echo "$SOLR_INSTALL_DIR not found! Please check the SOLR_INSTALL_DIR setting in your $0 script."
  exit 1
fi

case "$1" in
start)
    $SOLR_INSTALL_DIR/bin/solr $1 -c -z sandbox.hortonworks.com
    ;;
stop)
    $SOLR_INSTALL_DIR/bin/solr $1
    ;;
status)
     $SOLR_INSTALL_DIR/bin/solr $1
    ;;
*)
    echo $"Usage: $0 {start|stop|status}"
    exit 2
esac
EOF
chmod 755 /etc/init.d/solr

#Import Spark Model
pwd
cd /root/devicemanagerdemo/package/files
cd Model
unzip nostradamusSVMModel.zip
cp -rvf nostradamusSVMModel /tmp
cp -vf DeviceLogTrainingData.csv /tmp
sudo -u hdfs hadoop fs -chmod 777 /demo/data/
hadoop fs -mkdir /demo/data/model/
hadoop fs -mkdir /demo/data/checkpoint
hadoop fs -mkdir /demo/data/training/
hadoop fs -put /tmp/nostradamusSVMModel /demo/data/model/ 
hadoop fs -put /tmp/DeviceLogTrainingData.csv /demo/data/training/
rm -Rvf /tmp/nostradamusSVMModel
rm -vf /tmp/DeviceLogTrainingData.csv

#Start Solr and create index
service solr start
chkconfig --add solr
chkconfig solr on
sleep 10
curl "http://sandbox.hortonworks.com:8983/solr/admin/cores?action=CREATE&name=settopbox&instanceDir=/opt/lucidworks-hdpsearch/solr/server/solr/settopbox&configSet=data_driven_schema_configs"

# Reboot to refresh configuration
#reboot now

#slider create mapui --template /usr/hdp/docker/dockerbuild/mapui/appConfig.json --metainfo /usr/hdp/docker/dockerbuild/mapui/metainfo.json --resources /usr/hdp/docker/dockerbuild/mapui/resources.json

#storm jar /home/storm/DeviceMonitor-0.0.1-SNAPSHOT.jar com.hortonworks.iot.topology.DeviceMonitorTopology

#spark-submit --class com.hortonworks.iot.spark.streaming.SparkNostradamus --master local[4] /home/spark/DeviceMonitorNostradamus-0.0.1-SNAPSHOT-jar-with-dependencies.jar

###### use —master yarn-client or yarn-cluster to start SparkNostradamus on Yarn (Need more RAM and CPU)