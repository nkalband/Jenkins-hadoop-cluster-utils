
$HADOOP_HOME/sbin/hadoop-daemon.sh start namenode
$HADOOP_HOME/sbin/hadoop-daemons.sh start datanode
$HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager
$HADOOP_HOME/sbin/yarn-daemons.sh start nodemanager
$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver

$SPARK_HOME/sbin/start-history-server.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 
${DIR}/../utils/checkall.sh 