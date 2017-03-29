#!/bin/bash -l


# Creating new config
echo -e '# Default hdfs configuration properties' > config
echo -e 'HADOOP_TMP_DIR='${HOME}'/hdfs_dir/app-hadoop' >> config 
echo -e 'REPLICATION_VALUE=3' >> config
echo -e 'NAMENODE_DIR='${HOME}'/hdfs_dir/hdfs-meta' >> config
echo -e 'DATANODE_DIR='${HOME}'/hdfs_dir/hdfs-data' >> config

echo -en '# Master Details\n' >> config
MASTER=`hostname`
echo -en 'MASTER='$MASTER'\n\n' >> config

#echo -en 'Please enter slave hostname details in format slave1_hostname,slave2_hostname \n'
SLAVE_HOSTNAME=$1

echo -en '# Using these format to save SLAVE Details: slave1IP,slave1cpu,slave1memory....\n' >> config
echo -e

j=0
for i in `echo $SLAVE_HOSTNAME |tr ',' ' '`
do
slavehost=$(ssh $i hostname)
echo -en 'Collecting memory details from SLAVE machine '$slavehost' \n'
freememory=$(ssh $slavehost free -m | awk '{print $4}'| head -2 | tail -1)
memorypercent=$(awk "BEGIN { pc=80*$freememory/100; i=int(pc); print (pc-i<0.5)?i:i+1 }")
ncpu=$(ssh $slavehost nproc --all)
if [ $j -eq 0 ]
then
SLAVE=`echo ''$slavehost','$ncpu','$memorypercent''`
else
SLAVE=`echo ''$SLAVE'%'$slavehost','$ncpu','$memorypercent''`
fi
((j=j+1))
done

echo -en 'SLAVES='$SLAVE'\n\n' >> config

echo -en '#Node Manager properties (Default yarn cpu and memory value for all nodes)\n' >> config	 
echo -en 'YARN_SCHEDULER_MIN_ALLOCATION_MB=128\n' >> config				 
echo -en 'YARN_SCHEDULER_MIN_ALLOCATION_VCORES=1\n\n' >> config
echo -e
echo -en 'Spark version selected for setup : '$2''
#sparkver="2.0.1"
sparkver=$2
echo -en 'hadoop version selected for setup :'$3''	
#hadoopver="2.7.1"
hadoopver=$3

echo -en '#Hadoop and Spark versions and setup zip download urls\n' >> config
echo -e
echo -en 'sparkver='"$sparkver"'\n' >> config
echo -en 'hadoopver='"$hadoopver"'\n\n' >> config

HADOOP_URL="http://www-us.apache.org/dist/hadoop/common/hadoop-${hadoopver}/hadoop-${hadoopver}.tar.gz"
SPARK_URL="http://www-us.apache.org/dist/spark/spark-${sparkver}/spark-${sparkver}-bin-hadoop${hadoopver:0:3}.tgz"

echo -en 'SPARK_URL='$SPARK_URL'\n' >> config
echo -en 'HADOOP_URL='$HADOOP_URL'\n\n' >> config


echo -en '# Default port values\n' >> config

echo -en 'NAMENODE_PORT=9000\n' >> config
echo -en 'NAMENODE_HTTP_ADDRESS=50070\n' >> config
echo -en 'NAMENODE_SECONDARY_HTTP_ADDRESS=50090\n' >> config
echo -en 'NAMENODE_SECONDARY_HTTPS_ADDRESS=50091\n\n' >> config

echo -en 'DATANODE_ADDRESS=50010\n' >> config
echo -en 'DATANODE_HTTP_ADDRESS=50075\n' >> config
echo -en 'DATANODE_IPC_ADDRESS=50020\n\n' >> config

echo -en 'MAPREDUCE_JOBHISTORY_ADDRESS=10020\n' >> config
echo -en 'MAPREDUCE_JOBHISTORY_ADMIN_ADDRESS=10033\n' >> config 
echo -en 'MAPREDUCE_JOBHISTORY_WEBAPP_ADDRESS=19888\n\n' >> config

echo -en 'RESOURCEMANAGER_SCHEDULER_ADDRESS=8030\n' >> config
echo -en 'RESOURCEMANAGER_RESOURCE_TRACKER_ADDRESS=8031\n' >> config
echo -en 'RESOURCEMANAGER_ADDRESS=8032\n' >> config
echo -en 'RESOURCEMANAGER_ADMIN_ADDRESS=8033\n' >> config
echo -en 'RESOURCEMANAGER_WEBAPP_ADDRESS=8088\n\n' >> config

echo -en 'NODEMANAGER_LOCALIZER_ADDRESS=8040\n' >> config
echo -en 'NODEMANAGER_WEBAPP_ADDRESS=8042\n\n' >> config
echo -en 'SPARKHISTORY_HTTP_ADDRESS=18080\n\n' >> config

##setting flag to setup hive and mysql or not
echo -e "#Flag set for hive and mysql set up required or not" >> config
#echo -e 'Do you want to setup hive and mysql. This will be required for running benchmarks like TPCDS and HiBench'
#read -p "Please confirm ? [y/N] " prompt
flag_hive_mysql=$5
if [[ $flag_hive_mysql == "y" || $flag_hive_mysql == "Y" ]]
then
    echo -e 'SETUP_HIVE_MYSQL=Yes' >> config
else 
    echo -e 'SETUP_HIVE_MYSQL=No' >> config
fi

echo -e
echo -e 'Please check configuration (config file) once before run (setup.sh file).'
echo -e 'You can modify hadoop or spark versions in config file'
echo -e
chmod +x config

