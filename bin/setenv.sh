#!/bin/bash

# Uncomment the following line to enable shell debugging
#set -x

# Set this to the location of Java JRE on compute nodes. 
export JAVA_HOME=/usr/java/jre1.6.0_45

# Set this to location of myHadoop 
export MY_HADOOP_PREFIX="/home/denton/myHadoop-orangefs"

# Set this to the location of the Hadoop installation
export HADOOP_PREFIX="/opt/hadoop-1.2.1"

# Set this to the location you want Hadoop to use for its temporary data.
# Note that this path should be a LOCAL directory, and
# that the path should be readable and writable on all involved compute nodes.
export HADOOP_TMP_DIR="/local_scratch/hadoop_$USER/hadoop_tmp_dir"

# Set this to the directory where Hadoop will store logfiles
export HADOOP_LOG_DIR="/local_scratch/hadoop_$USER/hadoop_log_dir"

# Set this to the path of OrangeFS shared libraries.
export JNI_LIBRARY_PATH="/opt/orangefs/lib"

# Set this to the path of your OrangeFS tabfile (client connection information)
export PVFS2TAB_FILE="/opt/orangefs/ofstab"
