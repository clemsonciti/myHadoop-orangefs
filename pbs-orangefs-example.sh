#!/bin/bash

#PBS -q workq
#PBS -N myHadoop_job
#PBS -l select=64:ncpus=16
#PBS -o /home/denton/hadoop_job.out
#PBS -e /home/denton/hadoop_job.err

### Run the myHadoop environment script to set the appropriate variables
#
# Note: ensure that the variables are set correctly in bin/setenv.sh
. /home/denton/myHadoop-orangefs/bin/setenv.sh

#### Set this to the directory where Hadoop configs should be generated
# Don't change the name of this variable (HADOOP_CONF_DIR) as it is
# required by Hadoop - all config files will be picked up from here
#
# Make sure that this is accessible to all nodes
export HADOOP_CONF_DIR="/home/denton/myHadoopGeneratedConf"

#### Set up the configuration
# Make sure number of nodes is the same as what you have requested from PBS
# usage: $MY_HADOOP_PREFIX/bin/pbs-configure.sh -h
echo "Set up the configurations for myHadoop"
JAVA_HOME=$JAVA_HOME $MY_HADOOP_PREFIX/bin/pbs-configure.sh -n 64 -c $HADOOP_CONF_DIR
echo

#### Start the Hadoop cluster
echo "Start Hadoop MapReduce daemons"
$HADOOP_PREFIX/bin/start-mapred.sh
echo

#### Run your jobs here
echo "Run some test Hadoop jobs"
$HADOOP_PREFIX/bin/hadoop --config $HADOOP_CONF_DIR jar $HADOOP_PREFIX/hadoop-test-1.2.1.jar TestDFSIO -write -nrFiles 64 -fileSize 1000
$HADOOP_PREFIX/bin/hadoop --config $HADOOP_CONF_DIR jar $HADOOP_PREFIX/hadoop-test-1.2.1.jar TestDFSIO -read -nrFiles 64 -fileSize 1000
echo

#### Stop the Hadoop cluster
echo "Stop Hadoop MapReduce daemons"
$HADOOP_PREFIX/bin/stop-mapred.sh
echo

#### Clean up the working directories after job completion
echo "Clean up"
$MY_HADOOP_PREFIX/bin/pbs-cleanup.sh -n 64
echo
