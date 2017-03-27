# Hadoop and Yarn Setup

### Set passwordless login

To create user
```
sudo adduser testuser
sudo adduser testuser sudo
```

For local host

```
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa 
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
 ```
For other hosts

```
ssh-copy-id -i ~/.ssh/id_rsa.pub user@host
ssh user@host
```

### Pre-requisities:
1. JAVA Setup should be completed and JAVA_HOME should be set in the ~/.bashrc file (environment variable).
2. Make sure the nodes are set for password-less SSH both ways(master->slaves).
3. Since we use the environment variables a lot in our scripts, make sure to comment out the portion following this statement in your ~/.bashrc , 
`If not running interactively, don't do anything`. Update .bashrc

 Delete/comment the following check.
  ```
   # If not running interactively, don't do anything
   case $- in
       *i*) ;;
         *) return;;
   esac
  ```
4. Same username/useraccount should be need on `master` and `slaves` nodes for multinode installation.
5. The following dependencies must be installed: make, ctags, gcc, flex, bison

### Installations:

* To automate hadoop installation follows the steps,

  ```bash
  git clone https://github.com/kmadhugit/hadoop-cluster-utils.git
  
  cd hadoop-cluster-utils  
  ```
  
* Configuration

   1. To configure `hadoop-cluster-utils`, run `./autogen.sh` which will create `config` with appropriate field values.
   2. User can enter SLAVE hostnames (if more than one, use comma seperated) interactively while running `./autogen.sh` file.
   3. Default `Spark-2.0.1` and `Hadoop-2.7.1` version available for installation. 
   4. While running `./autogen.sh` file, it will prompt for your choice for setting up Hive and Mysql on your master, select desired option.Hive and Mysql setup is required for running spark benchmarks like TPCDS,HiBench. 
   5. User can edit default port values, `spark` and `hadoop` versions in config
   6. Before executing `./setup.sh` file, user can verify or edit `config` 
   7. Once setup script completed,source `~/.bashrc` file to export updated hadoop and spark environment variables for current login session. 
   
* Ensure that the following java process is running in master. If not, check the log files
  
 ```bash
  checkall.sh
  ```
  
  Invoke `checkall.sh` ensure all services are started on the Master & slaves

  ```
  NameNode
  JobHistoryServer
  ResourceManager
  ```
  Ensure that the following java process is running in slaves. If not, check the hadoop log files
  ```
  DataNode
  NodeManager
  ```
 
* HDFS, Resource Manager, Node Manager and Spark web Address
  
  ```
  HDFS web address : http://localhost:50070
  Resource Manager : http://localhost:8088/cluster
  Node Manager     : http://datanode:8042/node (For each node)
  Spark            : http://localhost:8080 (Default)
  ```
 
* Useful scripts
 
  ```
   > stop-all.sh #stop HDFS and Yarn
   > start-all.sh #start HDFS and Yarn
   > CP <localpath to file> <remotepath to dir> #Copy file from name nodes to all slaves
   > AN <command> #execute a given command in all nodes including master
   > DN <command> #execute a given command in all nodes excluding master
   > checkall.sh #ensure all services are started on the Master & slaves
  ```
