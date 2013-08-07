#! /bin/bash

#	Multi-context JSS management script by John Kitzmiller

#	http://www.johnkitzmiller.com

#	The latest version of this script can be found at https://github.com/jkitzmiller/jssmanager

#	Version 9b3 - 8/5/2013

#	Tested on Ubuntu 12.04 LTS with Tomcat 7 and Casper Suite v. 9.0rc3

#	This script assumes Tomcat7 and MySQL client are installed

#	This script should be run as root

##########################################################################################
############### Edit the following variables to suit your environment ####################
##########################################################################################

	# The FQDN or IP of your MySQL database host
	# Leave this blank to have the script prompt each time
	
	dbHost="localhost"
	
	# MySQL root user
	
	dbRoot="root"
	
	# MySQL root password
	# Leave this blank to have the script prompt each time
	
	mysqlRootPwd=""
	
	# Path to dump MySQL database (do not leave a trailing / at the end of your path)
	
	dbDump="/tmp"
	
	# Path where you store your JSS logs (do not leave a trailing / at the end of your path)
	
	logPath="/var/log/JSS"
	
	# Path to your .war file
	
	webapp="/usr/local/jssmanager/ROOT.war"
	
	# Ethernet interface for the local IP of the server
	# This is the IP the server uses to connect to the database host
	# In most setups, this won't have to be changed
	
	eth="eth0"
	
########### It is not recommended that you make any changes after this line ##############

##########################################################################################
################################### Begin functions ######################################
##########################################################################################

# The yesNo function is used several times throughout the script to confirm the
# user wants to continue with the operation. 
 
function yesNo()
{	
		yesNo=""
		read yno
		case $yno in

		 	[yY] | [yY][Ee][Ss] )
                yesNo="yes";;

       		[nN] | [nN][Oo] )
                yesNo="no";;
                
    		*) echo "Invalid input";;
		esac
}	

# The deleteMenu function prompts the user for the name of the context they want to delete

function deleteMenu()
{
	echo "Please enter the name of the context you would like to delete."
	echo
	read -p "Context Name: " contextName
	
	if [ ! -d "$tomcatPath/webapps/$contextName" ];
		then
			echo "$contextName is not a valid JSS context."
			sleep 3
		else
			echo "$contextName will be deleted."
			echo "Would you like to continue?"
			yesNo
			
			if [ $yesNo == "yes" ];
				then
					echo "Deleting $contextName..."
					deleteWebapp
				else
					echo "$contextName will not be deleted."
			fi
	fi
	mainMenu
}

# The deleteWebapp function deletes the JSS webapp for the specified context.

function deleteWebapp()
{
	echo "Deleting $tomcatPath/webapps/$contextName.war"
	rm -rf $tomcatPath/webapps/$contextName.war
	echo "Deleting $tomcatPath/webapps/$contextName"
	rm -rf $tomcatPath/webapps/$contextName
}

# The readDatabaseSettings function reads the DataBase.xml file for the specified context
# and reads the Database host, name, user and password settings. This is used when upgading
# existing JSS contexts.

function readDatabaseSettings()
{
	echo "Reading database connection settings..."
	
	dbHost=$(sed -n 's|\s*<ServerName>\(.*\)</ServerName>|\1|p' $tomcatPath/webapps/$contextName/WEB-INF/xml/DataBase.xml)
	dbName=$(sed -n 's|\s*<DataBaseName>\(.*\)</DataBaseName>|\1|p' $tomcatPath/webapps/$contextName/WEB-INF/xml/DataBase.xml)
	dbUser=$(sed -n 's|\s*<DataBaseUser>\(.*\)</DataBaseUser>|\1|p' $tomcatPath/webapps/$contextName/WEB-INF/xml/DataBase.xml)
	dbPass=$(sed -n 's|\s*<DataBasePassword>\(.*\)</DataBasePassword>|\1|p' $tomcatPath/webapps/$contextName/WEB-INF/xml/DataBase.xml)
}

# The touchLogFiles function first checks for the existance of the directory specified
# in logPath, and gives the option to create or specify a new path if it doesn't exist.
# It then checks for the existance of unique log files for the context, and creates
# them if none are found.

function touchLogFiles()
{
	until [ -d "$logPath" ];
		do
			echo "$logPath does not exist!"
			echo "Would you like to create it?"
				yesNo
			
			if [ $yesNo == "yes" ];
				then
					echo Creating $logPath
					mkdir -p $logPath
			elif [ $yesNo == "no" ];
				then
					echo
					echo "Please specify a new directory for log files."
					echo "Make sure not to leave a trailing / at the end of your path."
					echo
					read -p "Log directory: " logPath
			fi
		done
	
	if [ ! -d "$logPath/$contextName" ];
		then
			echo Creating $logPath/$contextName/
			mkdir $logPath/$contextName
			chown tomcat7:tomcat7 $logPath/$contextName
		else
			echo $logPath/$contextName/ exists
	fi
	
	if [ ! -f "$logPath/$contextName/JAMFSoftwareServer.log" ];
		then
			echo Creating $logPath/$contextName/JAMFSoftwareServer.log
			touch $logPath/$contextName/JAMFSoftwareServer.log
			chown tomcat7:tomcat7 $logPath/$contextName/JAMFSoftwareServer.log
		else
			echo $logPath/$contextName/JAMFSoftwareServer.log exists
	fi
	
	if [ ! -f "$logPath/$contextName/jamfChangeManagement.log" ];
		then
			echo Creating $logPath/$contextName/jamfChangeManagement.log
			touch $logPath/$contextName/jamfChangeManagement.log
			chown tomcat7:tomcat7 $logPath/$contextName/jamfChangeManagement.log
		else
			echo $logPath/$contextName/jamfChangeManagement.log exists
	fi
}

# The deployWebapp function deploys the JSS webapp using the specified context name
# and database connection settings.

function deployWebapp()
{
	echo Deploying Tomcat webapp
	cp $webapp $tomcatPath/webapps/$contextName.war
	
	# Sleep timer to allow tomcat app to deploy

	counter=0
	while [ $counter -lt 12 ];
		do
			if [ ! -f "$tomcatPath/webapps/$contextName/WEB-INF/xml/DataBase.xml" ];
				then
					echo "Waiting for Tomcat webapp to deploy..."
					sleep 5
					let counter=counter+1
				else
					let counter=12
			fi
	done
	
	if [ ! -f "$tomcatPath/webapps/$contextName/WEB-INF/xml/DataBase.xml" ];
		then
			echo Something is wrong...
			echo Tomcat webapp has not deployed.
			echo Aborting!
			sleep 1
			exit 1
		else
			echo Webapp has deployed.
	fi

	# Change log4j files to point logs to new log locations

	echo Updating log4j files
	if [ -f "$tomcatPath/webapps/$contextName/WEB-INF/classes/log4j.JAMFCMFILE.properties" ];
		then
			sed -e "s@log4j.appender.JAMFCMFILE.File=.*@log4j.appender.JAMFCMFILE.File=$logPath/$contextName/jamfChangeManagement.log@" -e "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$contextName/JAMFSoftwareServer.log@" -i $tomcatPath/webapps/$contextName/WEB-INF/classes/log4j.JAMFCMFILE.properties
	fi
	
	if [ -f "$tomcatPath/webapps/$contextName/WEB-INF/classes/log4j.JAMFCMSYSLOG.properties" ];
		then
			sed "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$contextName/JAMFSoftwareServer.log@" -i $tomcatPath/webapps/$contextName/WEB-INF/classes/log4j.JAMFCMSYSLOG.properties
	fi
	
	sed -e "s@log4j.appender.JAMFCMFILE.File=.*@log4j.appender.JAMFCMFILE.File=$logPath/$contextName/jamfChangeManagement.log@" -e "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$contextName/JAMFSoftwareServer.log@" -i $tomcatPath/webapps/$contextName/WEB-INF/classes/log4j.properties

	# Add database connection info to JSS context

	echo Writing database connection settings
	sed -e "s@<ServerName>.*@<ServerName>$dbHost</ServerName>@" -e "s@<DataBaseName>.*@<DataBaseName>$dbName</DataBaseName>@" -e "s@<DataBaseUser>.*@<DataBaseUser>$dbUser</DataBaseUser>@" -e "s@<DataBasePassword>.*@<DataBasePassword>$dbPass</DataBasePassword>@" -i $tomcatPath/webapps/$contextName/WEB-INF/xml/DataBase.xml
}

# The updateWebapp function asks the user for the name of the context, validates it, then
# uses the readDatabaseSettings function to pull the existing database connection settings
# and store them, then tests the settings to ensure authentication to the database, then
# it will verify the log files exist and create them if not, then it will delete the exsting
# webapp, then deploy the new webapp, and finally it prompt for a tomcat restart.

function updateWebapp()
{
	echo "Please enter the name of the context you would like to update."
	echo
	read -p "Context Name: " contextName
	
	if [ ! -d "$tomcatPath/webapps/$contextName" ];
		then
			echo "$contextName is not a valid JSS context."
			sleep 3
		else
			echo "$contextName will be updated."
			echo "Would you like to continue?"
			yesNo
			
			if [ $yesNo == "yes" ];
				then
					echo "Updating $contextName..."
						updateContext
		   				tomcatRestartPrompt
				else
					echo "$contextName will not be updated."
			fi
	fi
	mainMenu
}

# The updateAll function will update ALL existing contexts in the Tomcat webapp directory
# and restart tomcat once all contexts have been updated.

function updateAll()
{
	echo "All existing JSS contexts will be updated."
	echo "Are you sure you want to continue?"
	yesNo
	if [ $yesNo == "yes" ];
		then
			for dirs in $tomcatPath/webapps/*/
				do
					contextName="$(basename $dirs)"
					echo
					echo "Updating $contextName..."
					updateContext
				done
			bounceTomcat
	fi
	mainMenu
}

# The displayAll function is used to display a list of all JSS contexts

function displayAll()
{
	echo "Existing JSS contexts:"
	echo
	for dirs in $tomcatPath/webapps/*/
		do
			contextName="$(basename $dirs)"
			echo "$contextName"
		done
	echo
	echo	
	read -s -p "Press [Enter] to reurn to the main menu"
	mainMenu
}

# The tomcatRestartPrompt will ask the user if they want to restart tomcat.

function tomcatRestartPrompt()
{
	echo
	echo "A Tomcat restart is recommended."
	echo "Would you like to restart Tomcat now?"
	yesNo
	if [ $yesNo == "yes" ];
		then
   			bounceTomcat
   	elif [ $yesNo == "no" ];
   		then
   			echo "Tomcat will not be restarted."
   	fi
}

# The bounceTomcat function checks to see if Tomcat was installed as part of the JSS
# installer, or if Tomcat was installed manually, and sends the appropriate restart command.

function bounceTomcat()
{
	echo "Restarting Tomcat..."
	
	if [ -d "/var/lib/tomcat7" ];
		then
			service tomcat7 restart
	elif [ -d "/usr/local/jss/tomcat" ];
		then
			/etc/init.d/jamf.tomcat7 restart
	fi
}

function updateContext()
{
	readDatabaseSettings
	testDatabase
	touchLogFiles
	deleteWebapp
	deployWebapp
}

# The newcontext function gets the context name and database connection information
# from the user, and deploys a new context. If the user enters an context name
# that is already in use, the script will prompt to upgrade the context instead.

function newcontext()
{
	echo
	echo "Please enter a name for this context."
	echo
	read -p "Context Name: " contextName
	
	if [ -d "$tomcatPath/webapps/$contextName" ];
		then
			echo "$contextName already exists!"
			echo "Would you like to upgrade this context?"
			yesNo
				if [ $yesNo == "yes" ];
					then
						echo "Updating $contextName..."
						updateContext
						tomcatRestartPrompt
		   		elif [ $yesNo == "no" ];
		   			then
		   				echo "Aborting deployment."
		   		fi 
		else
			echo
			echo "Please enter the name of the database."
			echo
			read -p "Database Name: " dbName
			echo
			echo "Please enter the name of the database user."
			echo
			read -p "Database User: " dbUser
			echo
			echo "Please enter the database user's password."
			echo
			read -s -p "Database Password: " dbPass
	
			if [ $dbHost == "" ];
				then
					echo "Please enter the hostname or IP address of the database server."
					echo
					read -p "Database Server: " dbHost
			fi
			
			echo "A new context will be deployed with the following settings."
			echo
			echo "Context Name: $contextName"
			echo "Database Name: $dbName"
			echo "Database User: $dbUser"
			echo "Database Pass: $dbPass"
			echo "Database Host: $dbHost"
			echo
			echo "Would you like to continue?"
			yesNo
				
			if [ $yesNo == "yes" ];
				then
					testDatabase
					touchLogFiles
					deployWebapp
					tomcatRestartPrompt
					setChangeManagement
   			elif [ $yesNo == "no" ];
   				then
   					echo "Context will not be created."
   					sleep 3
   					mainMenu
   			fi
	fi
	mainMenu
}

# The createDatabase function creates a database on the host server

function createDatabase()
{
	echo "Creating database $dbName..."
	mysql -h $dbHost -u $dbRoot -p$mysqlRootPwd -e "CREATE DATABASE $dbName;"
}

# The grantPermissions function grants permission to a user for the specified database

function grantPermissions()
{
	echo "Granting permissions on database $dbName to user $dbUser at $serverAddress..."
	mysql -h $dbHost -u $dbRoot -p$mysqlRootPwd -e "GRANT ALL ON $dbName.* TO $dbUser@$serverAddress IDENTIFIED BY '$dbPass';"
}

function setChangeManagement()
{
echo "Setting change management log path to $logPath/$contextName"
mysql --host=$dbHost --user=$dbUser --password=$dbPass $dbName << EOF
insert into change_management (cm_file) values('$logPath/$contextName');
EOF
}

# The testDatabase function will first test for the existence of the database using the
# root credentials, then checks to see if the specified user has permission to access the
# database, offering to create the database and grant permissions as needed.

function testDatabase()
{
	if [ $dbHost == "localhost" ];
		then
			serverAddress="localhost"
		else
			serverAddress=`ifconfig $eth | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
	fi
	
	if [ -z "$mysqlRootPwd" ];
		then
			read -s -p "Enter MySQL root password: " mysqlRootPwd
	fi
	
	echo "Testing MySQL root username and password..."
	# The following could potentially cause an infinite loop if a successful connection
	# to the database host can not be established
	until mysql -h $dbHost -u $dbRoot -p$mysqlRootPwd  -e ";" ;
		do
			echo "Invalid MySQL root username or password. Please retry."
			read -p "MySQL Root User: " dbRoot
			read -s -p "MySQL Root Password: " mysqlRootPwd
		done
	
	echo
	echo "Checking database connection settings..."

	dbTestUser=`mysqlshow --host=$dbHost --user=$dbUser --password=$dbPass $dbName| grep -v Wildcard | grep -o $dbName`
	echo "dbTestUser result: $dbTestUser"
	
	if [ -z $dbTestUser ];
		then
			dbTestRoot=`mysqlshow --host=$dbHost --user=$dbRoot --password=$mysqlRootPwd $dbName| grep -v Wildcard | grep -o $dbName`
			echo "dbTestRoot result: $dbTestRoot"
			if [ -z $dbTestRoot ];
				then
					echo "Database $dbName does not seem to exist."
					echo "Would you like to create it?"
					yesNo
						if [ $yesNo == "yes" ];
							then
								createDatabase
								grantPermissions
						elif [ $yesNo == "no" ];
							then
								echo "Database will not be created."
								echo "WARNING: Webapp may not be able to connect to database."
						fi
			elif [ $dbTestRoot == $dbName ];
				then
					echo "User $dbUser does not seem to have permission to access database $dbName."
					echo "Would you like to grant permissions?"
					yesNo
						if [ $yesNo == "yes" ];
							then
								grantPermissions
						elif [ $yesNo == "no" ];
							then
								echo "User will not be granted permission."
								echo "WARNING: Webapp may not be able to connect to database."
						fi
			fi
		else
			echo "Database connection test successful."
	fi	
}

# Check to make sure script is being run as root

function checkRoot()
{
	echo "Checking to see if logged in as root..."
	
	currentUser=$(whoami)

	if [ $currentUser != root ];
		then
			echo "ID10T Error: You must be root to run this script."
			sleep 1
			echo "Aborting!"
			sleep 3
			exit 1
		else
			echo "Congratulations! You followed the directions and ran the script as root!"
	fi
}

# Check to make sure ROOT.war exists at the specified path

function checkWebapp()
{

	echo "Checking for $webapp..."
	
	if [ ! -f $webapp ];
		then
			echo "$webapp not found!"
			sleep 1
			echo "Aborting!"
			sleep 3
			exit 1
		else
			echo "Webapp found at $webapp."
	fi
}

# Check Tomcat installation method and set appropriate Tomcat path

function checkTomcat()
{
	echo "Checking Tomcat installation type..."
	
	if [ -d "/var/lib/tomcat7" ];
		then
			tomcatPath="/var/lib/tomcat7"
	elif [ -d "/usr/local/jss/tomcat" ];
		then
			tomcatPath="/usr/local/jss/tomcat"
	else
		echo "Tomcat7 does not appear to be installed."
		echo "Please install Tomcat7 before using this script." 
		echo "Exiting..."
		sleep 3
		exit 1
	fi
	
	echo "Tomcat path is $tomcatPath"
}

# Main menu

function mainMenu()
{
			echo
			echo
			echo "What would you like to do?"
			echo
			echo "1 Deploy a new JSS context"
			echo "2 Upgrade an existing JSS context"
			echo "3 Upgrade ALL JSS contexts"
			echo "4 Delete an existing JSS context"
			echo "5 Display all JSS contexts"
			echo "6 Restart Tomcat"
			echo "7 Exit"
			echo

			installType=""
	
			read -p "Enter your choice: " installType
			case $installType in
		   		1)    echo Deploying a new JSS...;
		   				newcontext;;
		   				
		   		2)    echo Upgrading an existing JSS...;
		   				updateWebapp;;
		   				
		   		3)	  echo Upgrading ALL JSS contexts...;
		   				updateAll;;
		   				
		   		4)    echo Deleting an existing JSS...;
		   				deleteMenu;;
		   				
		   		5)	  displayAll;;
		   				
		   		6)	  bounceTomcat;
		   				mainMenu;;
		   		
		   		7)	  echo Exiting...;
		   				sleep 3;
		   		 		exit 0;;
		   		 		
				*)    echo Invalid Selection!;;
			esac
}
			
##########################################################################################
#################################### End functions #######################################
##########################################################################################

	clear
	
	echo "JSS Manager v9b3"
	
	checkRoot

	checkWebapp
	
	checkTomcat
	
	echo
	echo
	echo "Welcome to the JSS Manager!"
	
	mainMenu