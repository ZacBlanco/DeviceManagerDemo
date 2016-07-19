import sys, demo_utils
from resource_management import *
from resource_management.core.exceptions import ComponentIsNotRunning
from demo_utils.shell import Shell
from demo_utils import config
reload(sys)
sys.setdefaultencoding('utf8')

# INSTRUCTIONS ON IMPLEMENTING SERVICE METHODS
# 
# Note: all of this information can be found
# under ./docs/ambari-service.md
# 
# Install
#  - Installs any necessary components for the service
# Start
#  - Starts any necessary services
# Stop
#  - Stops any service components
# Status
#  - Gets the status of the components
# Configure
#  - Writes out configuration details from Ambari to the services configuration files


class Master(Script):
	
	
	def install(self, env):
		# Fill me in!
		print 'Install the Sample Srv Master';
		self.configure(env)
		conf_dir = '/root/devicemanagerdemo/'
		sh = Shell()
		print("WORKING DIR")
		print(sh.run('pwd'))
		sh.set_cwd(conf_dir)
		sh.run('bash demo-files/install.sh')
	
	def stop(self, env):
		# Fill me in!
		print 'Stop the Sample Srv Master';
		sh = Shell('/root/devicemanagerdemo/demo-files')
		sh.run("yarn application -kill $(yarn application -list | grep -Po '(application_[0-9]+_[0-9]+)\s(biologicsmanufacturingui)' | grep -Po '(application_[0-9]+_[0-9]+)')")
		sh.run('service docker stop')
		
		
	
	def start(self, env):
		# Fill me in!
		print 'Start the Sample Srv Master';
		sh = Shell()
		self.configure(env)
		sh = Shell('/root/devicemanagerdemo/demo-files')
		print(sh.run('bash ' 'startDemoServices.sh'))
		print("WORKING DIR")
		print(sh.run('pwd'))
	
	
	def status(self, env):
		# Fill me in!
		pid_file = sh.run('pgrep docker > /var/run/docker-demo.pid')[0]
		check_process_status('/var/run/docker-demo.pid')
		print 'Status of the Sample Srv Master';
	
	def configure(self, env):
		# Fill me in!
		print 'Configure the Sample Srv Master';


if __name__ == "__main__":
	Master().execute()
	