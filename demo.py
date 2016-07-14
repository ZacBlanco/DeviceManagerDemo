#!/usr/bin/env python

import os, sys, demo_utils
from demo_utils.shell import Shell

usage = """
Usage: python demo.py {install|pre|service|post}

install:
		Full installation. Runs the pre-install, service-install, then post-install.

pre:
		Run only the pre-service install function

service:
		Runs only the service install (possibly fails if pre-install isn't run)
		
post:
		Runs just the post-service install function
"""

# DEMO.py
# Fill in the pre-install and post-install functions as necessary.
# [OPTIONAL]
# This method should contain any requests to the Ambari server - before installing the demo service
def pre_install():
	sh = Shell('demo-files')
	print(sh.run('bash pre-install.sh'))

# [OPTIONAL]
# This method is used for any cleanup/tests/post-install actions that you want to run after the demo Ambari service is installed
def post_install():
	print("post install function")

def install_service():
	print("Install here...")
	sh = Shell('demo-files')
	version = '2.4'
	cmd = 'cp -r . /var/lib/ambari-server/resources/stacks/HDP/%s/services/DEMOSERVICE' % version
	print(sh.run(cmd))
	cmd = 'ambari-server restart'
	print(sh.run(cmd))
#	curl -X POST http://ambari-server:8080/api/v1/cluster/services/DEMOSERVICE


def setup():
	print('...Setup Actions...')
	# Setup actions for the environment
	pass

def run():
	print("Running install lifecycle")
	setup()
	pre_install()
	install_service()
	post_install()
	print("Done Install")



args = sys.argv[1:]
arg = ""
if not len(args) == 1:
	print(usage)
else:
	arg = args[0]

setup()

if arg == "install":
	run()
elif arg == "pre":
	pre_install()
elif arg == "service":
	install_service()
elif arg == "post":
	post_install()
else:
	print("\nUsage: python demo.py {install|pre|service|post}\n\n")





























	