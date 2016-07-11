import sys, util
from resource_management import *
from util.shell import Shell
from util import config
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
		sh = Shell()
		conf_dir = config.get_conf_dir()
		print('CONFIGURATION DIRECTORY')
		print(conf_dir)
		print("SET CWD:")
		print(conf_dir + "..")
		sh.set_cwd(conf_dir + "..")
		output = sh.run('bash ' + conf_dir + '../files/install.sh')
		print("WORKING DIR")
		print(sh.run('pwd'))
		print(output[0])
		print(output[1])
		if len(output[1]) > 0:
			sys.exit(1)
	
	def stop(self, env):
		# Fill me in!
		print 'Stop the Sample Srv Master';
	
	def start(self, env):
		# Fill me in!
		print 'Start the Sample Srv Master';
		self.configure(env)
		sh = Shell()
		conf_dir = config.get_conf_dir()
		print('CONFIGURATION DIRECTORY')
		print(conf_dir)
		print("SET CWD:")
		print(conf_dir + "..")
		sh.set_cwd(conf_dir + "..")
		print(sh.run('pwd'))
		sh.set_cwd(conf_dir + "..")
		output = sh.run('bash ' + conf_dir + '../files/startDemoServices.sh')
		print(output[0])
		print(output[1])
		if len(output[1]) > 0:
			sys.exit(1)
	
	def status(self, env):
		# Fill me in!
		# check_process_status(pid_file)
#		sys.exit(1)
		print 'Status of the Sample Srv Master';
	
	def configure(self, env):
		# Fill me in!
		print 'Configure the Sample Srv Master';


if __name__ == "__main__":
	Master().execute()
	