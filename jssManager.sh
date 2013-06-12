#! /bin/bash

#	Multi-context JSS management script by John Kitzmiller

#	http://www.johnkitzmiller.com

#	The latest version of this script can be found at https://github.com/jkitzmiller/jssmanager

#	Version 8.7b1 - 6/10/2013

#	Tested on Ubuntu 12.04 LTS with Tomcat 7 and Casper Suite v. 8.7

#	This script assumes Tomcat7 and MySQL client are installed

#	This script should be run as root

##########################################################################################
############### Edit the following variables to suit your environment ####################
##########################################################################################

	# The FQDN or IP of your MySQL database host
	# Leave this blank to have the script prompt each time
	
	dbHost="localhost"
	
	# Path where you store your JSS logs (do not leave a trailing / at the end of your path)
	
	logPath="/var/log/JSS"
	
	# Path to your .war file
	
	webapp="/usr/local/jssmanager/ROOT.war"
	
	# Path to dump MySQL database (do not leave a trailing / at the end of your path)
	
	dbDump="/tmp"
	
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

       		[nN] | [n|N][O|o] )
                yesNo="no";;
                
    		*) echo "Invalid input";;
		esac
}	

# The deleteMenu function prompts the user for the name of the instance they want to delete

function deleteMenu()
{
	echo "Please enter the name of the instance you would like to delete."
	echo
	read -p "Instance Name: " instanceName
	
	if [ ! -d "$tomcatPath/webapps/$instanceName" ];
		then
			echo "$instanceName is not a valid JSS instance."
		else
			echo "$instanceName will be deleted."
			echo "Would you like to continue?"
			yesNo
			
			if [ $yesNo == "yes" ];
				then
					echo "Deleting $instanceName..."
					deleteWebapp
				else
					echo "$instanceName will not be deleted."
			fi
	fi
}

# The deleteWebapp function deletes the JSS webapp for the specified instance.

function deleteWebapp()
{
	echo "Deleting $tomcatPath/webapps/$instanceName.war"
	rm -rf $tomcatPath/webapps/$instanceName.war
	echo "Deleting $tomcatPath/webapps/$instanceName"
	rm -rf $tomcatPath/webapps/$instanceName
}

# The pullDatabaseSettings function reads the DataBase.xml file for the specified instance
# and reads the Database host, name, user and password settings. This is used when upgading
# existing JSS instances.

function pullDatabaseSettings()
{
	dbHost=$(sed -n 's|<ServerName>\(.*\)</ServerName>|\1|p' $tomcatPath/webapps/$instanceName/WEB-INF/xml/DataBase.xml)
	dbName=$(sed -n 's|<DataBaseName>\(.*\)</DataBaseName>|\1|p' $tomcatPath/webapps/$instanceName/WEB-INF/xml/DataBase.xml)
	dbUser=$(sed -n 's|<DataBaseUser>\(.*\)</DataBaseUser>|\1|p' $tomcatPath/webapps/$instanceName/WEB-INF/xml/DataBase.xml)
	dbPass=$(sed -n 's|<DataBasePassword>\(.*\)</DataBasePassword>|\1|p' $tomcatPath/webapps/$instanceName/WEB-INF/xml/DataBase.xml)
}

# The touchLogFiles function first checks for the existance of the directory specified
# in logPath, and gives the option to create or specify a new path if it doesn't exist.
# It then checks for the existance of unique log files for the instance, and creates
# them if none are found.

function touchLogFiles()
{
	# Check to make sure directory specified in logPath exists, gives the opton to create
	# or specify a new logPath if it does not exist.
	
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
	
	if [ ! -d "$logPath/$instanceName" ];
		then
			echo Creating $logPath/$instanceName/
			mkdir $logPath/$instanceName
			chown tomcat7:tomcat7 $logPath/$instanceName
		else
			echo $logPath/$instanceName/ exists
	fi
	
	if [ ! -f "$logPath/$instanceName/JAMFSoftwareServer.log" ];
		then
			echo Creating $logPath/$instanceName/JAMFSoftwareServer.log
			touch $logPath/$instanceName/JAMFSoftwareServer.log
			chown tomcat7:tomcat7 $logPath/$instanceName/JAMFSoftwareServer.log
		else
			echo $logPath/$instanceName/JAMFSoftwareServer.log exists
	fi
	
	if [ ! -f "$logPath/$instanceName/jamfChangeManagement.log" ];
		then
			echo Creating $logPath/$instanceName/jamfChangeManagement.log
			touch $logPath/$instanceName/jamfChangeManagement.log
			chown tomcat7:tomcat7 $logPath/$instanceName/jamfChangeManagement.log
		else
			echo $logPath/$instanceName/jamfChangeManagement.log exists
	fi
}

# The deployWebapp function deploys the JSS webapp using the specified instance name
# and database connection settings.

function deployWebapp()
{
	echo Deploying Tomcat webapp
	cp $webapp $tomcatPath/webapps/$instanceName.war
	
	# Sleep timer to allow tomcat app to deploy

	counter=0
	while [ $counter -lt 12 ];
		do
			if [ ! -d "$tomcatPath/webapps/$instanceName" ];
				then
					echo "Waiting for Tomcat webapp to deploy..."
					sleep 5
					let counter=counter+1
				else
					let counter=12
			fi
	done
	
	if [ ! -d "$tomcatPath/webapps/$instanceName" ];
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
	sed -e "s@log4j.appender.JAMFCMFILE.File=.*@log4j.appender.JAMFCMFILE.File=$logPath/$instanceName/jamfChangeManagement.log@" -e "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$instanceName/JAMFSoftwareServer.log@" -i $tomcatPath/webapps/$instanceName/WEB-INF/classes/log4j.JAMFCMFILE.properties
	sed "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$instanceName/JAMFSoftwareServer.log@" -i $tomcatPath/webapps/$instanceName/WEB-INF/classes/log4j.JAMFCMSYSLOG.properties
	sed -e "s@log4j.appender.JAMFCMFILE.File=.*@log4j.appender.JAMFCMFILE.File=$logPath/$instanceName/jamfChangeManagement.log@" -e "s@log4j.appender.JAMF.File=.*@log4j.appender.JAMF.File=$logPath/$instanceName/JAMFSoftwareServer.log@" -i $tomcatPath/webapps/$instanceName/WEB-INF/classes/log4j.properties

	# Add database connection info to JSS instance

	echo Writing database connection settings
	sed -e "s@<ServerName>.*@<ServerName>$dbHost</ServerName>@" -e "s@<DataBaseName>.*@<DataBaseName>$dbName</DataBaseName>@" -e "s@<DataBaseUser>.*@<DataBaseUser>$dbUser</DataBaseUser>@" -e "s@<DataBasePassword>.*@<DataBasePassword>$dbPass</DataBasePassword>@" -i $tomcatPath/webapps/$instanceName/WEB-INF/xml/DataBase.xml
}

function updateWebapp()
{
	echo "Please enter the name of the instance you would like to update."
	echo
	read -p "Instance Name: " instanceName
	
	if [ ! -d "$tomcatPath/webapps/$instanceName" ];
		then
			echo "$instanceName is not a valid JSS instance."
		else
			echo "$instanceName will be updated."
			echo "Would you like to continue?"
			yesNo
			
			if [ $yesNo == "yes" ];
				then
					echo "Updating $instanceName..."
						pullDatabaseSettings
		   				touchLogFiles
		   				deleteWebapp
		   				deployWebapp
		   				bounceTomcat
				else
					echo "$instanceName will not be updated."
			fi
	fi
}

# The bounceTomcat function checks to see if Tomcat was installed as part of the JSS
# installer, or if Tomcat was installed manually, and sends the appropriate restart command.

function bounceTomcat()
{
	if [ -d "/var/lib/tomcat7" ];
		then
			service tomcat7 restart
	elif [ -d "/usr/local/jss/tomcat" ];
		then
			/etc/init.d/jamf.tomcat7 restart
	fi
}

# Get JSS instance name and database connection information from user

function newInstance()
{
	echo
	echo "Please enter a name for this instance."
	echo
	read -p "Instance Name: " instanceName
	
	if [ -d "$tomcatPath/webapps/$instanceName" ];
		then
			echo "$instanceName already exists!"
			echo "Would you like to upgrade this instance?"
			yesNo
				if [ $yesNo == "yes" ];
					then
						echo "Updating $instanceName..."
							pullDatabaseSettings
		   					touchLogFiles
		   					deleteWebapp
		   					deployWebapp
		   					bounceTomcat
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
			
			echo "A new instance will be deployed with the following settings."
			echo
			echo "Instance Name: $instanceName"
			echo "Database Name: $dbName"
			echo "Database User: $dbUser"
			echo "Database Pass: $dbPass"
			echo "Database Host: $dbHost"
			echo
			echo "Would you like to continue?"
			yesNo
				
			if [ $yesNo == "yes" ];
				then
					touchLogFiles
		   			deleteWebapp
					deployWebapp
   					bounceTomcat
   			elif [ $yesNo == "no" ];
   				then
   					echo "Instance will not be created."
   			fi
	fi
}
			
##########################################################################################
#################################### End functions #######################################
##########################################################################################

	clear
	
	echo "JSS Manager v8.7b1"
	
# Check to make sure script is being run as root

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

# Check to make sure ROOT.war exists at the specified path

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
	
# Check Tomcat installation method and set appropriate Tomcat path

	echo "Checking Tomcat installation type..."
	
	if [ -d "/var/lib/tomcat7" ];
		then
			tomcatPath="/var/lib/tomcat7"
	elif [ -d "/usr/local/jss/tomcat" ];
		then
			tomcatPath="/usr/local/jss/tomcat"
	fi
	
	echo "Tomcat path is $tomcatPath"

# Main menu

	while true
		do
			echo
			echo
			echo "Welcome to the JSS Manager!"
			echo
			echo "What would you like to do?"
			echo
			echo "1 Deploy a new JSS instance"
			echo "2 Upgrade an existing JSS instance"
			echo "3 Delete an existing JSS instance"
			echo "4 Exit"
			echo
			echo

			installType=""
	
			read -p "Enter your choice: " installType
			case $installType in
		   		1)    echo Deploying a new JSS...;
		   				newInstance;;
		   		2)    echo Upgrading an existing JSS...;
		   				updateWebapp;;
		   		3)    echo Deleting an existing JSS...;
		   				deleteMenu;;
		   		4)	  echo Exiting...;
		   				sleep 3;
		   		 		exit 0;;
				*)    echo Invalid Selection!;;
			esac
		done