# Device Manager Demo

## Quick Demo Installation

Run the following commands via SSH on the Sandbox
	
	git clone https://github.com/ZacBlanco/DeviceManagerDemo /root/devicemanagerdemo
	cd /root/devicemanagerdemo
	python demo.py install
	
when the command finishes Ambari server will have restarted and you can add the new service to Ambari

### Files to look at

- `demo.py`
- `package/scripts/master.py`

Compare the above to the files at [https://github.com/ZacBlanco/hdp-demo-bootstrap](https://github.com/ZacBlanco/hdp-demo-bootstrap)

- `demo.py`
- `package/scripts/master.py`
	
## Need more Information?

### [Read the docs here!](docs/README.md)
 
 
Other commands (ignore)

	scp -r -q -P 2222 devicemanagerdemo root@sanbox.hortonworks.com:/root
	ssh root@sandbox.hortonworks.com -p 2222
	cd demo_utils/
	python setup.py install
	cd ..

	export VERSION=2.4
	rm -rf /var/lib/ambari-server/resources/stacks/HDP/$VERSION/services/DEMOSERVICE
	sudo git clone https://github.com/zacblanco/devicemanagerdemo.git /var/lib/ambari-server/resources/stacks/HDP/$VERSION/services/DEMOSERVICE
	git clone https://github.com/ZacBlanco/hdp-demo-bootstrap.git
	cd hdp-demo-bootstrap
	git submodule update --init --recursive
	ambari-server restart
	
	
	sed -i s/parallel_execution=0/parallel_execution=1/g /etc/ambari-agent/conf/ambari-agent.ini
	
	export VERSION=2.4
	rm -rf /var/lib/ambari-server/resources/stacks/HDP/$VERSION/services/DEMOSERVICE
	rm -rf /var/lib/ambari-agent/cache/stacks/HDP/$VERSION/services/DEMOSERVICE
	cp -r /root/devicemanagerdemo /var/lib/ambari-server/resources/stacks/HDP/$VERSION/services/DEMOSERVICE
	cp -r /root/devicemanagerdemo /var/lib/ambari-agent/cache/stacks/HDP/$VERSION/services/DEMOSERVICE
	service ambari restart

 