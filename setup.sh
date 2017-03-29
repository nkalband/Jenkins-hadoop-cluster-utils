#!/bin/bash -l

# Need to create user manually
# Need to set JAVA_HOME in .bashrc files on all machines
# Need to complete ssh setup for all servers

CURDIR=`pwd`            # Inside hadoop-cluster-utils directory where run.sh is exist
WORKDIR=${HOME}         # where hadoop and spark package will download 

current_time=$(date +"%Y.%m.%d.%S")

if [ ! -d $CURDIR/logs ];
then
    mkdir logs
fi

log=`pwd`/logs/hadoop_cluster_utils_$current_time.log
echo -e | tee -a $log


##Checking if wget and curl installed or not, and getting installed if not for ubuntu and redhat both
python -mplatform  |grep -i redhat >/dev/null 2>&1
# Ubuntu
if [ $? -ne 0 ]
then
	dpkg -l | grep -w wget >/dev/null 2>&1

	if [ $? -ne 0 ]
	then
		echo "wget is not installed on Master, so getting installed" | tee -a $log
		sudo apt-get install wget | tee -a $log
	else
		echo "wget is already installed on Master" | tee -a $log
	fi
	
	dpkg -l | grep -w curl >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "curl is not installed on Master, so getting installed" | tee -a $log
		sudo apt-get install curl | tee -a $log
	else
		echo "curl is already installed on Master" | tee -a $log
	fi
else
   	rpm -qa |grep -w wget >/dev/null 2>&1

	if [ $? -ne 0 ]
	then
		echo "wget is not installed on Master, so getting installed" | tee -a $log
		sudo yum install wget | tee -a $log
	else
		echo "wget is already installed on Master" | tee -a $log
	fi
	
	rpm -qa |grep -w curl >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "curl is not installed on Master, so getting installed" | tee -a $log
		sudo yum install curl | tee -a $log
	else
		echo "curl is already installed on Master" | tee -a $log
	fi
fi

echo "---------------------------------------------" | tee -a $log	

## Validation for config file

if [ -f ${CURDIR}/config ]; 
then
    ## First time permission set for config file
    chmod +x ${CURDIR}/config
    source ${CURDIR}/config
 
    ## Checking config file for all required fields
  
    { cat ${CURDIR}/config; echo; } | while read -r line; do
      if [[ $line =~ "=" ]] ;
      then
          confvalue=`echo $line |grep = | cut -d "=" -f2`
          if [[ -z "$confvalue" ]];
          then
              echo "Configuration vlaue not set properly for $line, please check config file" | tee -a $log
              exit 1
          fi
      fi
    done
				
	#Logic to create server list 
    cat ${CURDIR}/config | grep SLAVES | grep -v "^#" | tr "%" "\n" | grep "$MASTER" &>>/dev/null
    if [ $? -eq 0 ]
    then
	    #if master is also used as data machine 
        SERVERS=$SLAVES
    else
	    ## Getting details for Master machine
        freememory_master="$(free -m | awk '{print $4}'| head -2 | tail -1)"
        memorypercent_master=$(awk "BEGIN { pc=80*${freememory_master}/100; i=int(pc); print (pc-i<0.5)?i:i+1 }")
        ncpu_master="$(nproc --all)"
        MASTER_DETAILS=''$MASTER','$ncpu_master','$memorypercent_master''
        SERVERS=`echo ''$MASTER_DETAILS'%'$SLAVES''`
    fi
	
	#Check for JAVA_HOME in bashrc of all machines
	for i in `echo $SERVERS |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1`
	do
		ssh $i 'grep "^export JAVA_HOME" $HOME/.bashrc' &>/dev/null
		if [[ $? -eq 0 ]]
		then
            JAVA=$(ssh $i "grep '^export JAVA_HOME' $HOME/.bashrc | cut -f2 -d "="") 2>/dev/null
			echo -e 'JAVA_HOME found in bashrc of '$i' and java executable in '$JAVA'' | tee -a $log
		else
			echo -e 'JAVA_HOME not found in bashrc of '$i', please set the JAVA_HOME variable then continue to run this script.' | tee -a $log
			exit 1 
		fi
		
	done
    
    echo "---------------------------------------------" | tee -a $log	
    
	#Checking for other prerequisite
	
	for i in `echo $SERVERS |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1`
	do
		ssh $i "grep '^#case \$- in' $HOME/.bashrc" &>/dev/null
		if [ $? -ne 0 ]
		then
			ssh $i "grep '^case \$- in' $HOME/.bashrc" &>/dev/null
			if [ $? -eq 0 ]
			then 
				echo 'Prerequisite not completed on '$i'. Please comment below lines in .bashrc file.' | tee -a $log
				echo "# If not running interactively, don't do anything" | tee -a $log
				echo "case \$- in" | tee -a $log
				echo "*i*) ;;" | tee -a $log
				echo "*) return;;" | tee -a $log
				echo "esac" | tee -a $log
				exit 1
			fi	
		fi
	
	done 



    ## Validation for hadoop port instances

    declare -a port_name=("NAMENODE_PORT" "NAMENODE_HTTP_ADDRESS" "NAMENODE_SECONDARY_HTTP_ADDRESS" "NAMENODE_SECONDARY_HTTPS_ADDRESS" "DATANODE_ADDRESS" "DATANODE_HTTP_ADDRESS" "DATANODE_IPC_ADDRESS" "MAPREDUCE_JOBHISTORY_ADDRESS" "MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS" "MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS" "RESOURCEMANAGER_SCHEDULER_ADDRESS" "RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS" "RESOURCEMANAGER_ADDRESS" "RESOURCEMANAGER_ADMIN_ADDRESS" "RESOURCEMANAGER_WEBAPP_ADDRESS" "NODEMANAGER_LOCALIZER_ADDRESS" "NODEMANAGER_WEBAPP_ADDRESS" "SPARKHISTORY_HTTP_ADDRESS")

    declare -a port_list=("$NAMENODE_PORT" "$NAMENODE_HTTP_ADDRESS" "$NAMENODE_SECONDARY_HTTP_ADDRESS" "$NAMENODE_SECONDARY_HTTPS_ADDRESS" "$DATANODE_ADDRESS" "$DATANODE_HTTP_ADDRESS" "$DATANODE_IPC_ADDRESS" "$MAPREDUCE_JOBHISTORY_ADDRESS" "$MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS" "$MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS" "$RESOURCEMANAGER_SCHEDULER_ADDRESS" "$RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS" "$RESOURCEMANAGER_ADDRESS" "$RESOURCEMANAGER_ADMIN_ADDRESS" "$RESOURCEMANAGER_WEBAPP_ADDRESS" "$NODEMANAGER_LOCALIZER_ADDRESS" "$NODEMANAGER_WEBAPP_ADDRESS" "$SPARKHISTORY_HTTP_ADDRESS")

    i=0
    for j in "${port_list[@]}";
    do
      sudo netstat -pnlt | grep $j > /dev/null
      if [ $? -eq 0 ];
      then
          echo "${port_name[i]} running on port $j" >> temp
      fi
      i=$i+1
    done

    if [ -f temp ];
    then
        cat temp
        cat temp >> $log
        echo "Kindly kill above running instance(s) else change port number in config file, then continue to run this script." | tee -a $log
        rm temp &>/dev/null 
        exit 1
    fi
   
    ## Adding slave machine names to slave file
    cat ${CURDIR}/config | grep SLAVES | grep -v "^#" |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1  >${CURDIR}/conf/slaves 

    
    ## Validation for Slaves hostnames/IPs
    echo -e "Validation for slave Hostnames" | tee -a $log
    while IFS= read -r host; do
         if ping -q -c2 "$host" &>/dev/null;
         then
             echo "$host is Pingable" | tee -a $log
         else
             echo "$host Not Pingable" | tee -a $log
             echo 'Please check your config file. '$host' is not pingalbe. \n' | tee -a $log
         exit 1
         fi
    done <${CURDIR}/conf/slaves

  
    ## Download hadoop on Master machine 
  
    echo "---------------------------------------------" | tee -a $log
    echo "Downloading and installing hadoop..." | tee -a $log
	echo -e | tee -a $log
    cd ${WORKDIR}
    if [ ! -f ${WORKDIR}/hadoop-${hadoopver}.tar.gz ];
    then
        if curl --output /dev/null --silent --head --fail $HADOOP_URL
        then
            echo 'Hadoop file Downloading on Master- '$MASTER'' | tee -a $log
	        wget $HADOOP_URL | tee -a $log
        else
            echo "This URL does not exist. Please check your hadoop version then continue to run this script." | tee -a $log
            exit 1
        fi 
    fi	
	
    ## Copying hadoop tgz file , unzipping and exporting paths in the .bashrc file on all machines
		  	  
	for i in `echo $SERVERS |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1`
	do 
	  
        if [ $i != $MASTER ]
	    then
	      echo 'Copying Hadoop setup file on '$i'' | tee -a $log
	      scp ${WORKDIR}/hadoop-${hadoopver}.tar.gz @$i:${WORKDIR} | tee -a $log
	    fi
		ssh $i '[ -d '${WORKDIR}/hadoop-${hadoopver}' ]' &>>/dev/null
		if [ $? -eq 0 ]
		then 
		 echo 'Deleting existing hadoop folder "'hadoop-${hadoopver}'" from '$i' '| tee -a $log
		 ssh $i "rm -rf ${WORKDIR}/hadoop-${hadoopver}" &>>/dev/null
		fi
		
         echo 'Unzipping Hadoop setup file on '$i'' | tee -a $log	  
	     ssh $i "tar xf hadoop-${hadoopver}.tar.gz --gzip" 
	 
         echo 'Updating hadoop variables on '$i'' | tee -a $log
		 
	     export HADOOP_HOME="${WORKDIR}"/hadoop-${hadoopver}
	     echo "#StartHadoopEnv"> tmp_b
         echo "export CURDIR="${CURDIR}"" >> tmp_b
         echo "export PATH="${CURDIR}":"${CURDIR}"/hadoop:\$PATH" >> tmp_b 
		 echo "export PATH="${CURDIR}":"${CURDIR}"/utils:\$PATH" >> tmp_b
         echo "export HADOOP_HOME="${WORKDIR}"/hadoop-${hadoopver}" >> tmp_b
         echo "export HADOOP_PREFIX=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_MAPRED_HOME=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_COMMON_HOME=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_HDFS_HOME=$HADOOP_HOME" >> tmp_b
         echo "export YARN_HOME=$HADOOP_HOME" >> tmp_b
         echo "export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop" >> tmp_b
         echo "export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop" >> tmp_b
         echo "export PATH=$HADOOP_HOME/bin:\$PATH" >> tmp_b
         echo "#StopHadoopEnv">> tmp_b
	 
	  scp tmp_b @$i:${WORKDIR} &>>/dev/null
	 
	  ssh $i "grep -q '#StartHadoopEnv' $HOME/.bashrc"
	  if [ $? -ne 0 ];
      then
	      ssh $i "cat tmp_b>>$HOME/.bashrc"
		  ssh $i "rm tmp_b"
      else
          ssh $i "sed -i '/#StartHadoopEnv/,/#StopHadoopEnv/d' $HOME/.bashrc"
          ssh $i "cat tmp_b>>$HOME/.bashrc"
		  ssh $i "rm tmp_b"
      fi
	  echo 'Sourcing updated .bashrc file on '$i'' | tee -a $log
	  ssh $i "source ~/.bashrc" &>>/dev/null
	  echo "---------------------------------------------" | tee -a $log
   done
   rm -rf tmp_b
	
	
	## Configuration changes in hadoop-clusterfor Core-site,hdfs-site and mapred-site xml
	
    if [ ! -f ${CURDIR}/conf/core-site.xml ];
    then
	    #Copying xml templates for editing 
        cp ${CURDIR}/conf/core-site.xml.template ${CURDIR}/conf/core-site.xml
        cp ${CURDIR}/conf/hdfs-site.xml.template ${CURDIR}/conf/hdfs-site.xml
        cp ${CURDIR}/conf/mapred-site.xml.template ${CURDIR}/conf/mapred-site.xml
                  
       
        #core-site.xml configuration configuration properties
        sed -i 's|HADOOP_TMP_DIR|'"$HADOOP_TMP_DIR"'|g' ${CURDIR}/conf/core-site.xml
        sed -i 's|MASTER|'"$MASTER"'|g' ${CURDIR}/conf/core-site.xml
        sed -i 's|NAMENODE_PORT|'"$NAMENODE_PORT"'|g' ${CURDIR}/conf/core-site.xml
		 
           
        # hdfs-site.xml configuration properties
        sed -i 's|REPLICATION_VALUE|'"$REPLICATION_VALUE"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|NAMENODE_DIR|'"$NAMENODE_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|DATANODE_DIR|'"$DATANODE_DIR"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|NAMENODE_HTTP_ADDRESS|'"$NAMENODE_HTTP_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|NAMENODE_SECONDARY_HTTP_ADDRESS|'"$NAMENODE_SECONDARY_HTTP_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|NAMENODE_SECONDARY_HTTPS_ADDRESS|'"$NAMENODE_SECONDARY_HTTPS_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|DATANODE_ADDRESS|'"$DATANODE_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|DATANODE_HTTP_ADDRESS|'"$DATANODE_HTTP_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml
        sed -i 's|DATANODE_IPC_ADDRESS|'"$DATANODE_IPC_ADDRESS"'|g' ${CURDIR}/conf/hdfs-site.xml

  
        # mapred-site.xml configuration properties
        sed -i 's|MAPREDUCE_JOBHISTORY_ADDRESS|'"$MAPREDUCE_JOBHISTORY_ADDRESS"'|g' ${CURDIR}/conf/mapred-site.xml
        sed -i 's|MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS|'"$MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS"'|g' ${CURDIR}/conf/mapred-site.xml
        sed -i 's|MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS|'"$MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS"'|g' ${CURDIR}/conf/mapred-site.xml
  
    fi  
      
    ## yarn-site.xml configuration properties and hadoop-env.sh file updates for all machines

  	for i in `echo $SERVERS  |cut -d "=" -f2 | tr "%" "\n" `
    do
	 
      memorypercent=`echo $i| cut -d "," -f3`	
	  ncpu=`echo $i| cut -d "," -f2`
	  slavehost=`echo $i| cut -d "," -f1`
		 
	  echo 'Updating configuration properties for all xml files and hadoop.env.sh on '$slavehost'' | tee -a $log
		 
	  cp ${CURDIR}/conf/yarn-site.xml.template ${CURDIR}/conf/yarn-site.xml
	  
	  sed -i 's|MASTER|'"$MASTER"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_SCHEDULER_MIN_ALLOCATION_MB|'"$YARN_SCHEDULER_MIN_ALLOCATION_MB"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_SCHEDULER_MAX_ALLOCATION_MB|'"$memorypercent"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_SCHEDULER_MIN_ALLOCATION_VCORES|'"$YARN_SCHEDULER_MIN_ALLOCATION_VCORES"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_SCHEDULER_MAX_ALLOCATION_VCORES|'"$ncpu"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|YARN_NODEMANAGER_RESOURCE_CPU_VCORES|'"$ncpu"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|YARN_NODEMANAGER_RESOURCE_MEMORY_MB|'"$memorypercent"'|g' ${CURDIR}/conf/yarn-site.xml
	  sed -i 's|0.0.0.0:RESOURCEMANAGER_SCHEDULER_ADDRESS|'"$MASTER"':'"$RESOURCEMANAGER_SCHEDULER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|0.0.0.0:RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS|'"$MASTER"':'"$RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|0.0.0.0:RESOURCEMANAGER_ADDRESS|'"$MASTER"':'"$RESOURCEMANAGER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|0.0.0.0:RESOURCEMANAGER_ADMIN_ADDRESS|'"$MASTER"':'"$RESOURCEMANAGER_ADMIN_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      # RESOURCEMANAGER_WEBAPP_ADDRESS should not be associated with a private IP for enabling remote access.
      sed -i 's|0.0.0.0:RESOURCEMANAGER_WEBAPP_ADDRESS|'"0.0.0.0"':'"$RESOURCEMANAGER_WEBAPP_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|NODEMANAGER_LOCALIZER_ADDRESS|'"$NODEMANAGER_LOCALIZER_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
      sed -i 's|NODEMANAGER_WEBAPP_ADDRESS|'"$NODEMANAGER_WEBAPP_ADDRESS"'|g' ${CURDIR}/conf/yarn-site.xml
		 
		 
	  scp ${CURDIR}/conf/*site.xml @$slavehost:$HADOOP_HOME/etc/hadoop | tee -a $log
		 
	  ## Updating java version in hadoop-env.sh file on all machines
		 
	  JAVA_HOME_SLAVE=$(ssh $slavehost 'grep JAVA_HOME ~/.bashrc | grep -v "PATH" | cut -d"=" -f2')
	  echo "sed -i 's|"\${JAVA_HOME}"|"${JAVA_HOME_SLAVE}"|g' $HADOOP_HOME/etc/hadoop/hadoop-env.sh" | ssh $slavehost bash
      	  
    done	 
	rm -rf ${CURDIR}/conf/*site.xml
	
	echo "---------------------------------------------" | tee -a $log
 	
    ##Updating the slave file on master 
 
    cp ${CURDIR}/conf/slaves ${HADOOP_HOME}/etc/hadoop
     
else
    echo "Config file does not exist. Please check README.md for installation steps." | tee -a $log
    exit 1
fi  

##exporting hadoop variables for current script session on master
export HADOOP_HOME=${WORKDIR}/hadoop-${hadoopver}
export HADOOP_PREFIX=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop
export PATH=$HADOOP_HOME/bin:$PATH

##Spark installation

echo -e "${ul}Downloading and installing Spark...${nul}\n" | tee -a $log

cd ${WORKDIR}

if [ ! -f ${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz ];
then
    if curl --output /dev/null --silent --head --fail $SPARK_URL
    then
	    echo 'SPARK file Downloading on Master - '$MASTER'' | tee -a $log
        wget $SPARK_URL | tee -a $log
    else 
        echo "This URL Not Exist. Please check your spark version then continue to run this script." | tee -a $log
        exit 1
    fi 
echo "***********************************************"
fi

## Exporting SPARK_HOME to the PATH and Add scripts to the PATH

for i in `echo $SERVERS |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1`
do

    if [ $i != $MASTER ]
	then
	    echo 'Copying Spark setup file on '$i'' | tee -a $log
	    scp ${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz @$i:${WORKDIR} | tee -a $log
	fi
	
	ssh $i '[ -d '${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}' ]' &>>/dev/null
	if [ $? -eq 0 ]
		then 
		echo 'Deleting existing spark folder "'spark-${sparkver}-bin-hadoop${hadoopver:0:3}'"  from '$i' '| tee -a $log
		ssh $i "rm -rf ${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}" &>>/dev/null
	fi
	
	echo 'Unzipping Spark setup file on '$i'' | tee -a $log
    ssh $i "tar xf spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz --gzip" | tee -a $log	
	
	echo 'Updating .bashrc file on '$i' with Spark variables '	
	echo '#StartSparkEnv' >tmp_b
	echo "export SPARK_HOME="${WORKDIR}"/spark-"${sparkver}"-bin-hadoop"${hadoopver:0:3}"" >>tmp_b
	echo "export PATH=\$SPARK_HOME/bin:\$PATH">>tmp_b
	echo '#StopSparkEnv'>>tmp_b
		
	scp tmp_b @$i:${WORKDIR}&>>/dev/null
		
	ssh $i "grep -q "SPARK_HOME" ~/.bashrc"
	if [ $? -ne 0 ];
	then
	    ssh $i "cat tmp_b>>$HOME/.bashrc"
	    ssh $i "rm tmp_b"
	else
	    ssh $i "sed -i '/#StartSparkEnv/,/#StopSparkEnv/ d' $HOME/.bashrc"
	    ssh $i "cat tmp_b>>$HOME/.bashrc"
		ssh $i "rm tmp_b"
	fi

	ssh $i "source $HOME/.bashrc"
    echo "---------------------------------------------" | tee -a $log			
done
rm -rf tmp_b

##Exporting spark variables for current script session on master
export SPARK_HOME=${WORKDIR}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}
export PATH=$SPARK_HOME/bin:$PATH


## updating Slave file for Spark folder
source ${HOME}/.bashrc
echo 'Updating Slave file for Spark setup'| tee -a $log

cp spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves.template spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves
sed -i 's|localhost||g' spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves
cat ${CURDIR}/conf/slaves>>spark-${sparkver}-bin-hadoop${hadoopver:0:3}/conf/slaves

echo -e "Configuring Spark history server" | tee -a $log

cp $SPARK_HOME/conf/spark-defaults.conf.template $SPARK_HOME/conf/spark-defaults.conf
grep -q "#StartSparkconf" $SPARK_HOME/conf/spark-defaults.conf 
if [ $? -ne 0 ];
then
    echo "#StartSparkconf" >> $SPARK_HOME/conf/spark-defaults.conf
    echo "spark.eventLog.enabled   true" >> $SPARK_HOME/conf/spark-defaults.conf
    echo 'spark.eventLog.dir       '${HOME}'/hdfs_dir/spark-events' >> $SPARK_HOME/conf/spark-defaults.conf 
    echo "spark.eventLog.compress  true" >> $SPARK_HOME/conf/spark-defaults.conf
    echo 'spark.history.fs.logDirectory   '${HOME}'/hdfs_dir/spark-events' >> $SPARK_HOME/conf/spark-defaults.conf
    echo "#StopSparkconf">> $SPARK_HOME/conf/spark-defaults.conf
else
    sed -i '/#StartSparkconf/,/#StopSparkconf/ d' $SPARK_HOME/conf/spark-defaults.conf
    echo "#StartSparkconf" >> $SPARK_HOME/conf/spark-defaults.conf 
    echo "spark.eventLog.enabled   true" >> $SPARK_HOME/conf/spark-defaults.conf
    echo 'spark.eventLog.dir       '${HOME}'/hdfs_dir/spark-events' >> $SPARK_HOME/conf/spark-defaults.conf
    echo "spark.eventLog.compress  true" >> $SPARK_HOME/conf/spark-defaults.conf
    echo 'spark.history.fs.logDirectory   '${HOME}'/hdfs_dir/spark-events' >> $SPARK_HOME/conf/spark-defaults.conf
    echo "#StopSparkconf">> $SPARK_HOME/conf/spark-defaults.conf
fi

CP $SPARK_HOME/conf/spark-defaults.conf $SPARK_HOME/conf &>/dev/null

echo -e "Spark installation done..!!\n" | tee -a $log

#setting spark and hadoop log properties to display only errors
cp $SPARK_HOME/conf/log4j.properties.template $SPARK_HOME/conf/log4j.properties
sed -i 's/^log4j.rootCategory.*/log4j.rootCategory=ERROR, console/g' $SPARK_HOME/conf/log4j.properties
CP $SPARK_HOME/conf/log4j.properties $SPARK_HOME/conf &>/dev/null

sed -i 's/log4j.threshold=ALL/log4j.threshold=ERROR/g' ${HADOOP_HOME}/etc/hadoop/log4j.properties
CP ${HADOOP_HOME}/etc/hadoop/log4j.properties ${HADOOP_HOME}/etc/hadoop &>/dev/null


##to start hadoop setup

#
# Check whether the list of directories exist.
#   even if one directory got missed out, delete & recreate all directories and do hdfs format.
#   even all directories exist, prompt whether to initiate hdfs format.
#
RMDIR=0
for slave in `echo $SERVERS  |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1 `
do
for dr in $HADOOP_TMP_DIR $NAMENODE_DIR $DATANODE_DIR
do
  splitdir=$(echo $dr | tr "," "\n")
  for idr in $splitdir
  do
    ssh $slave "ls -ld $idr >/dev/null 2>&1"
    if [ $? -ne 0 ]; then
      RMDIR=1
    fi
  done
done
done

if [ $RMDIR == 1 ]; then
  for slave in `echo $SERVERS  |cut -d "=" -f2 | tr "%" "\n" | cut -d "," -f1 `
  do
  for dr in $HADOOP_TMP_DIR $NAMENODE_DIR $DATANODE_DIR
  do
    splitdir=$(echo $dr | tr "," "\n")
    for idr in $splitdir
    do
      ssh $slave "ls -ld $idr >/dev/null 2>&1"
      if [ $? -eq 0 ]; then
        ssh $slave "rm -rf $idr" 
      fi
      ssh $slave "mkdir -p $idr"
    done
  done
  done 
  echo "Finished creating HDFS directories" | tee -a $log
  echo 'Formatting NAMENODE'| tee -a $log
  $HADOOP_PREFIX/bin/hdfs namenode -format mycluster >> $log 2>&1
else
  #read -p "** NOTE ** HDFS directories existing. Do you wish to format ? [y/N] " prompt
  hdfs_format=$1
  if [[ $hdfs_format == "y" || $hdfs_format == "Y" || $hdfs_format == "yes" || $hdfs_format == "Yes" ]]; then
    echo 'Formatting NAMENODE'| tee -a $log
    $HADOOP_PREFIX/bin/hdfs namenode -format -force mycluster >> $log 2>&1
  fi
fi

AN "mkdir -p '${HOME}'/hdfs_dir/spark-events" &>/dev/null

echo -e | tee -a $log
$CURDIR/hadoop/start-all.sh | tee -a $log
# echo -e | tee -a $log
# $CURDIR/utils/checkall.sh | tee -a $log

## use stop-all.sh for stopping
source ${HOME}/.bashrc

echo "---------------------------------------------" | tee -a $log

##Installing hive and mysql
	
	if [ ${SETUP_HIVE_MYSQL} == "Yes" ]
	then 
		echo "Setting up mysql" | tee -a $log

		python -mplatform  |grep -i redhat >/dev/null 2>&1
		# Ubuntu
		if [ $? -ne 0 ]
		then
			dpkg -l | grep mysql >/dev/null 2>&1

			if [ $? -ne 0 ]
			then
				sudo apt-key update
				sudo apt-get -y update
				sudo apt-get -y dist-upgrade

				dpkg -S /usr/bin/mysql
				if [ $? -ne 0 ]
				then
					sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password passw0rd'
					sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password passw0rd'
					sudo apt-get -y install mysql-server --force-yes
					sudo apt-get -y install mysql-client --force-yes
				fi
			else
				echo "mysql is already installed" | tee -a $log
			fi

			if [ ! -f /usr/share/java/mysql-connector-java.jar ]
			then
				sudo apt-get -y install libmysql-java --force-yes
			else
				echo "mysql connector is installed already" | tee -a $log
			fi

			sudo netstat -tap | grep mysql >/dev/null 2>&1
			if [ $? -ne 0 ]
			then
				sudo systemctl restart mysql.service
				sudo netstat -tap | grep mysql
				if [ $? -ne 0 ]
				then
					echo "Failed to start mysql" | tee -a $log
					exit 255
				fi
			fi
		else
			# RedHat
			mdb=0
			for i in mariadb mariadb-server mariadb-libs
			do
			rpm -qa |grep $i >/dev/null 2>&1
			if [ $? -ne 0 ]; then
			mdb=1
			fi
			done
			
			if [ $mdb -ne 0 ]; then
				sudo yum -y install mariadb mariadb-server mariadb-libs >/dev/null 2>&1
				sudo systemctl start mariadb.service
				sudo systemctl enable mariadb.service

				rpm -qa | grep expect >/dev/null 2>&1
				if [ $? -ne 0 ] ; then
				  sudo yum -y install expect >/dev/null 2>&1
				fi

				MYSQL=passw0rd

				echo "Setting mysql root password to ${MYSQL}" | tee -a $log
				SECURE_MYSQL=$(expect -c "
				set timeout 10
				spawn mysql_secure_installation
				expect \"Enter current password for root (enter for none):\"
				send \"\r\"
				expect \"Set root password?\"
				send \"y\r\"
				expect \"New password:\"
				send \"$MYSQL\r\"
				expect \"Re-enter new password:\"
				send \"$MYSQL\r\"
				expect \"Remove anonymous users?\"
				send \"y\r\"
				expect \"Disallow root login remotely?\"
				send \"y\r\"
				expect \"Remove test database and access to it?\"
				send \"y\r\"
				expect \"Reload privilege tables now?\"
				send \"y\r\"
				expect eof
				")

				
			else
				echo "mysql is already installed" | tee -a $log
			fi

			if [ ! -f /usr/share/java/mysql-connector-java.jar ]
			then
				sudo sudo yum -y install mysql-connector-java
			else
				echo "mysql connector is installed already" | tee -a $log
			fi
		fi

		# Check for hive user
		mysql -u root -ppassw0rd -e 'select user from mysql.user where user="hive" and host="localhost";' 2>&1 | grep -w hive >/dev/null
		if [ $? -ne 0 ]
		then
			mysql -u root -ppassw0rd -e "CREATE USER 'hive'@'%' IDENTIFIED BY 'hivepassword';GRANT all on *.* to 'hive'@localhost identified by 'hivepassword';flush privileges;"
			if [ $? -ne 0 ]
			then
				echo "Failed to create hive user" | tee -a $log
				exit 255
			fi
			echo "User hive added to mysql" | tee -a $log
		else
			mysql -u hive -phivepassword -e "show databases;" >/dev/null 2>&1
			if [ $? -ne 0 ]
			then
				echo "Note: Error accessing hive user with the password: hivepassword;"
				echo "      Ensure that the ConnectionUserName/ConnectionPassword in hive-site.xml"
				echo "      in Spark conf directory matches with the mysql's hive user"
			fi
			echo "Existing user hive in mysql is sufficient." | tee -a $log
		fi

#Copying hive-site.xml into ${SPARK_HOME}/conf/

		if [ ! -f ${SPARK_HOME}/conf/hive-site.xml ]
		then
			cp ${CURDIR}/conf/hive-site.xml.template ${SPARK_HOME}/conf/hive-site.xml
			if [ $? -eq 0 ]
			then
			   echo "Sucessfully placed ${SPARK_HOME}/conf/hive-site.xml" | tee -a $log
			fi
		else
			echo "${SPARK_HOME}/conf/hive-site.xml exist already."
			echo "Note: Check it out javax.jdo.option.ConnectionUserName"
			echo "      and javax.jdo.option.ConnectionPassword attributes"
			echo "      it should match with the mysql's hive user"
		fi

		echo "Adding mysql connector to Spark Classpath" | tee -a $log
		grep spark.executor.extraClassPath ${SPARK_HOME}/conf/spark-defaults.conf | grep -v "^#" | grep mysql-connector-java.jar >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			grep spark.executor.extraClassPath ${SPARK_HOME}/conf/spark-defaults.conf | grep -v "^#" >/dev/null 2>&1
			if [ $? -ne 0 ]; then
			# Fresh entry
				echo "spark.executor.extraClassPath /usr/share/java/mysql-connector-java.jar" >> ${SPARK_HOME}/conf/spark-defaults.conf
			else
			# append to the existing CLASSPATH
				sed -i '/^spark.executor.extraClassPath/ s~$~:/usr/share/java/mysql-connector-java.jar~' ${SPARK_HOME}/conf/spark-defaults.conf
			fi
			echo "Added mysql-connector-java.jar to spark executor classpath" | tee -a $log
		fi

		grep spark.driver.extraClassPath ${SPARK_HOME}/conf/spark-defaults.conf | grep -v "^#" | grep mysql-connector-java.jar >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			grep spark.driver.extraClassPath ${SPARK_HOME}/conf/spark-defaults.conf | grep -v "^#" >/dev/null 2>&1
			if [ $? -ne 0 ]; then
			# Fresh entry
				echo "spark.driver.extraClassPath /usr/share/java/mysql-connector-java.jar" >> ${SPARK_HOME}/conf/spark-defaults.conf
			else
			# append to the existing CLASSPATH
				sed -i '/^spark.driver.extraClassPath/ s~$~:/usr/share/java/mysql-connector-java.jar~' ${SPARK_HOME}/conf/spark-defaults.conf
			fi
			echo "Added mysql-connector-java.jar to spark driver classpath" | tee -a $log
		fi
		
	fi
    echo "---------------------------------------------" | tee -a $log

	
echo -e | tee -a $log
echo "${ul}Web URL link${nul}" | tee -a $log
echo "HDFS web address : http://"$MASTER":"$NAMENODE_HTTP_ADDRESS"" | tee -a $log 
echo "Resource Manager : http://"$MASTER":"$RESOURCEMANAGER_WEBAPP_ADDRESS"/cluster" | tee -a $log
echo "SPARK history server : http://"$MASTER":"$SPARKHISTORY_HTTP_ADDRESS"" | tee -a $log
echo -e | tee -a $log

echo "---------------------------------------------" | tee -a $log	
echo "${ul}Ensure SPARK running correctly using following command${nul}" | tee -a $log
echo "${SPARK_HOME}/bin/spark-submit --class org.apache.spark.examples.SparkPi --master yarn-client --driver-memory 1024M --num-executors 2 --executor-memory 1g  --executor-cores 1 ${SPARK_HOME}/examples/jars/spark-examples_2.11-2.0.1.jar 10" | tee -a $log
echo -e 

#read -p "Do you wish to run above command ? [y/N] " prompt

spark_test=$2
if [[ $spark_test == "y" || $spark_test == "Y" || $spark_test == "yes" || $spark_test == "Yes" ]]
then
  ${SPARK_HOME}/bin/spark-submit --class org.apache.spark.examples.SparkPi --master yarn-client --driver-memory 1024M --num-executors 2 --executor-memory 1g  --executor-cores 1 ${SPARK_HOME}/examples/jars/spark-examples_2.11-2.0.1.jar 10 &>> $log
  
  echo -e | tee -a $log
  echo "---------------------------------------------" | tee -a $log	
  grep -r 'Pi is roughly' ${log}
  if [ $? -eq 0 ];
  then
     echo -e 'Spark services running.\n' | tee -a $log
     echo -e 'Please check log file '$log' for more details.\n'
  else
     echo -e 'Expected output not found.\n' | tee -a $log
     echo -e 'Please check log file '$log' for more details. \n'
  fi
fi

echo "Setup Complete !! "
echo -e 'Please execute "source ~/.bashrc" to export updated hadoop and spark environment variables in your current login session. \n'

