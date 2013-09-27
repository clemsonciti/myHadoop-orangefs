#!/bin/bash

# Uncomment the following line to enable shell debugging
#set -x

function print_usage {
    echo "Usage: -n NODES -c CONFIG_DIR -h"
    echo "       -n: Number of nodes requested for the Hadoop installation"
    echo "       -c: The directory to generate Hadoop configs in"
    echo "       -h: Print help"
}

# initialize arguments
NODES=""
CONFIG_DIR=""

# parse arguments
args=`getopt n:c:h $*`
if test $? != 0
then
    print_usage
    exit 1
fi
set -- $args
for i
do
    case "$i" in
        -n) shift;
        NODES=$1
            shift;;

        -c) shift;
        CONFIG_DIR=$1
            shift;;

        -h) shift;
        print_usage
        exit 0
    esac
done

if [ "$NODES" != "" ]; then
    echo "Number of Hadoop nodes requested: $NODES"
else 
    echo "Required parameter not set - number of nodes (-n)"
    print_usage
    exit 1
fi

if [ "$CONFIG_DIR" != "" ]; then
    echo "Generation Hadoop configuration in directory: $CONFIG_DIR"
else 
    echo "Location of configuration directory not specified"
    print_usage
    exit 1
fi

# get the number of nodes from PBS
if [ -e $PBS_NODEFILE ]; then
    PBS_NODES=`awk 'END { print NR }' $PBS_NODEFILE`
    echo "Received $PBS_NODES nodes from PBS"

    if [ "$NODES" != "$PBS_NODES" ]; then
    echo "Number of nodes received from PBS not the same as number of nodes requested by user"
    exit 1
    fi
else 
    echo "PBS_NODEFILE is unavailable"
    exit 1
fi

# create the config, data, and log directories
rm -rf $CONFIG_DIR
mkdir -p $CONFIG_DIR

# first copy over all default Hadoop configs
cp $HADOOP_PREFIX/conf/* $CONFIG_DIR

# pick the master node as the first node in the PBS_NODEFILE
echo `awk 'NR==1{print;exit}' $PBS_NODEFILE` > $CONFIG_DIR/jt
sed -i 's/.lakeside/-ib0.lakeside/g' $CONFIG_DIR/jt
MASTER_NODE=`cat $CONFIG_DIR/jt`
#MASTER_NODE=`awk 'NR==1{print;exit}' $PBS_NODEFILE`

echo "JobTracker will be: $MASTER_NODE"
echo

# every node in the PBS_NODEFILE is a slave
cat $PBS_NODEFILE > $CONFIG_DIR/slaves

# Use IB interface instead of what PBS gave us.
sed -i 's/.lakeside/-ib0.lakeside/g' $CONFIG_DIR/slaves

# update the mapred configs
sed 's/<value>.*:/<value>'"$MASTER_NODE"':/g' $MY_HADOOP_PREFIX/etc/mapred-site.xml > $CONFIG_DIR/mapred-site.xml
cp -f $MY_HADOOP_PREFIX/etc/core-site.xml $CONFIG_DIR/core-site.xml
#sed 's/hdfs:\/\/.*:/hdfs:\/\/'"$MASTER_NODE"':/g' $MY_HADOOP_PREFIX/etc/core-site.xml > $CONFIG_DIR/core-site.xml
sed -i 's:HADOOP_TMP_DIR:'"$HADOOP_TMP_DIR"':g' $CONFIG_DIR/core-site.xml
#cp $MY_HADOOP_PREFIX/etc/hdfs-site.xml $CONFIG_DIR/

# update the HADOOP log directory
echo "" >> $CONFIG_DIR/hadoop-env.sh
echo "# Overwrite location of the log directory" >> $CONFIG_DIR/hadoop-env.sh
echo "export HADOOP_LOG_DIR=$HADOOP_LOG_DIR" >> $CONFIG_DIR/hadoop-env.sh

# TODO: Add OrangeFS specific environment variables to hadoop-env.sh
echo "# JAVA_HOME location on scheduled nodes" >> $CONFIG_DIR/hadoop-env.sh
echo "export JAVA_HOME=$JAVA_HOME" >> $CONFIG_DIR/hadoop-env.sh

echo "# OrangeFS specific variables:" >> $CONFIG_DIR/hadoop-env.sh
echo "export JNI_LIBRARY_PATH=$JNI_LIBRARY_PATH" >> $CONFIG_DIR/hadoop-env.sh
echo "export HADOOP_CLASSPATH=$JNI_LIBRARY_PATH/ofs_hadoop.jar:$JNI_LIBRARY_PATH/ofs_jni.jar" >> $CONFIG_DIR/hadoop-env.sh
echo "export PVFS2TAB_FILE=$PVFS2TAB_FILE" >> $CONFIG_DIR/hadoop-env.sh

# create or link HADOOP_{DATA,LOG}_DIR on all slaves
for ((i=1; i<=$NODES; i++))
do
    node=`awk 'NR=='"$i"'{print;exit}' $PBS_NODEFILE`
    echo "Configuring node: $node"
    cmd="rm -rf $HADOOP_LOG_DIR; mkdir -p $HADOOP_LOG_DIR"
    echo $cmd
    ssh $node $cmd 
    cmd="rm -rf $HADOOP_TMP_DIR; mkdir -p $HADOOP_TMP_DIR"
    echo $cmd
    ssh $node $cmd 
done
