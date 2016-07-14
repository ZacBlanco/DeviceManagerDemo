cd /root/devicemanagerdemo/demo-files
export FILES="/root/devicemanagerdemo/demo-files"

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
        TASKSTATUS=$(curl -sS -u admin:admin -I -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox | grep -Po 'OK')
        if [ "$TASKSTATUS" == OK ]; then
                LOOPESCAPE="true"
                TASKSTATUS="READY"
        else
        		AUTHSTATUS=$(curl -sS -u admin:admin -I -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox | grep HTTP | grep -Po '( [0-9]+)'| grep -Po '([0-9]+)')
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
YARNSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/YARN | grep '"state" :' | grep -Po '([A-Z]+)')
sleep 2
>&2 echo "YARN STATUS: $YARNSTATUS"
LOOPESCAPE="false"
if ! [[ "$YARNSTATUS" == STARTED || "$YARNSTATUS" == INSTALLED ]]; then
        until [ "$LOOPESCAPE" == true ]; do
                TASKSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/YARN | grep '"state" :' | grep -Po '([A-Z]+)')
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
        TASKID=$(curl -sS -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context": "Stop YARN"}, "ServiceInfo": {"state": "INSTALLED"}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/YARN | grep "id" | grep -Po '([0-9]+)')
        >&2 echo "*********************************AMBARI TaskID " $TASKID
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
                TASKSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
                if [ "$TASKSTATUS" == COMPLETED ]; then
                        LOOPESCAPE="true"
                fi
                >&2 echo "*********************************Task Status" $TASKSTATUS
                sleep 2
        done
elif [ "$YARNSTATUS" == INSTALLED ]; then
        >&2 echo "YARN Service Stopped..."
fi

TASKID=$(curl -sS -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context": "Start YARN"}, "ServiceInfo": {"state": "STARTED"}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/YARN | grep "id" | grep -Po '([0-9]+)')
>&2 echo "*********************************AMBARI TaskID " $TASKID
sleep 2
LOOPESCAPE="false"
until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
        if [ "$TASKSTATUS" == COMPLETED ]; then
                LOOPESCAPE="true"
        fi
        >&2 echo "*********************************Task Status" $TASKSTATUS
        sleep 2
done

# Check if NIFI Service is Installed
NIFISTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep '"state" :' | grep -Po '([A-Z]+)')
if ! [[ "$NIFISTATUS" == INSTALLED || "$NIFISTATUS" == STARTED ]]; then
	>&2 echo "*********************************Creating NIFI service..."
	# Create NIFI service
	curl -sS -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI

	sleep 2
	>&2 echo "*********************************Adding NIFI MASTER component..."
	# Add NIFI Master component to service
	curl -sS -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI/components/NIFI_MASTER

	sleep 2
	>&2 echo "*********************************Creating NIFI configuration..."

	# Create and apply configuration
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-ambari-config $FILES/Nifi/config/nifi-ambari-config.json
	sleep 2
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-bootstrap-env $FILES/Nifi/config/nifi-bootstrap-env.json
	sleep 2
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-flow-env $FILES/Nifi/config/nifi-flow-env.json
	sleep 2
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-logback-env $FILES/Nifi/config/nifi-logback-env.json
	sleep 2
	/var/lib/ambari-server/resources/scripts/configs.sh set sandbox.hortonworks.com Sandbox nifi-properties-env $FILES/Nifi/config/nifi-properties-env.json

	sleep 2
	>&2 echo "*********************************Adding NIFI MASTER role to Host..."
	# Add NIFI Master role to Sandbox host
	curl -sS -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/hosts/sandbox.hortonworks.com/host_components/NIFI_MASTER

	sleep 2
	>&2 echo "*********************************Installing NIFI Service"
	# Install NIFI Service
	TASKID=$(curl -sS -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Nifi"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "*********************************AMBARI TaskID " $TASKID
	sleep 2
	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
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

NIFISTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$NIFISTATUS" == INSTALLED ]; then
	# Start NIFI service
	TASKID=$(curl -sS -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Start NIFI"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/NIFI | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "*********************************AMBARI TaskID " $TASKID
	sleep 2
	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
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
        TASKSTATUS=$(curl -sS -u admin:admin -i -X GET http://sandbox.hortonworks.com:9090/nifi-api/controller | grep -Po 'OK')
        if [ "$TASKSTATUS" == OK ]; then
                LOOPESCAPE="true"
        else
                TASKSTATUS="PENDING"
        fi
		>&2 echo "*********************************Waiting for NIFI Servlet..."
        >&2 echo "*********************************NIFI Servlet Status... " $TASKSTATUS
        sleep 2
done



#Start Kafka
KAFKASTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/KAFKA | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$KAFKASTATUS" == INSTALLED ]; then
	>&2 echo "*********************************Starting Kafka Broker..."
	TASKID=$(curl -sS -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Kafka via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/KAFKA | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "*********************************AMBARI TaskID " $TASKID
	sleep 2
	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do
		TASKSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
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


HBASESTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/HBASE | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$HBASESTATUS" == INSTALLED ]; then
	>&2 echo "*********************************Starting  Hbase Service..."
	TASKID=$(curl -sS -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Hbase via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/HBASE | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "HBASE TaskId " $TASKID
	sleep 2

	LOOPESCAPE="false"

	until [ "$LOOPESCAPE" == true ]; do

		TASKSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
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

STORMSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/STORM | grep '"state" :' | grep -Po '([A-Z]+)')
if [ "$STORMSTATUS" == INSTALLED ]; then
	>&2 echo "*********************************Starting Storm Service..."
	TASKID=$(curl -sS -u admin:admin -i -H 'X-Requested-By: ambari' -X PUT -d '{"RequestInfo": {"context" :"Start Storm via REST"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}}' http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/services/STORM | grep "id" | grep -Po '([0-9]+)')
	>&2 echo "*********************************STORM TaskId " $TASKID
	sleep 2
	LOOPESCAPE="false"
	until [ "$LOOPESCAPE" == true ]; do
		TASKSTATUS=$(curl -sS -u admin:admin -X GET http://sandbox.hortonworks.com:8080/api/v1/clusters/Sandbox/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
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





