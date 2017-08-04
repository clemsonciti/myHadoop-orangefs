#!/usr/bin/env bash

#set -x

# For use on Palmetto Cluster only
# =============================================================================
#module add java/1.8.0 # TODO: Test with this version of Java.
module add java/1.7.0
module add hadoop/1.2.1
# =============================================================================

# For use on other clusters, set JAVA_HOME to the location of Java JRE or JDK on compute nodes.
#export JAVA_HOME=/usr/java/jre1.6.0_45

# Set this to the path of your myHadoop-orangefs directory
export MY_HADOOP_PREFIX="${HOME}/orangefs_hadoop/myHadoop-orangefs"

# ***** Set this to the location of the Hadoop installation. *****
# On Palmetto, this is already done via the above "module add hadoop/x.x.x".
#export HADOOP_PREFIX="/opt/hadoop-1.2.1"

# Set this to the location you want Hadoop to use for its temporary data.
# Note that this path should be a LOCAL directory, and
# that the path should be readable and writable on all involved compute nodes.
export HADOOP_TMP_DIR="/local_scratch/${USER}/mapred_local_dir"

# Set this to the directory where Hadoop will store logfiles
export HADOOP_LOG_DIR="/local_scratch/${USER}/hadoop_log_dir"

# Set this to the path of OrangeFS shared libraries.
export JNI_LIBRARY_PATH="/opt/orangefs/lib"

# Explanation of construct used below:
#     https://stackoverflow.com/questions/9631228/how-to-smart-append-ld-library-path-in-shell-when-nounset
export LD_LIBRARY_PATH="/opt/orangefs/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# This is the current version of OrangeFS installed on Palmetto Cluster.
export ORANGEFS_VERSION="2.9.6"

# TODO document this
export ORANGEFS_STRIP_SIZE_AS_BLKSIZE=true

# Set this to a directory path that is shared by all compute nodes on your cluster.
#export MY_HADOOP_SHARED_DIR="${HOME}"
export MY_HADOOP_SHARED_DIR="/scratch2/${USER}"

# For saving out the log data from each node before it is erased.
export MY_HADOOP_LOG_SAVE_ENABLED=true
export MY_HADOOP_LOG_SAVE_DIR="${MY_HADOOP_SHARED_DIR}/myHadoop-orangefs-logs-job-${PBS_JOBID}"

# The following is not needed on Palmetto because the config file path
# is the OrangeFS default path of /etc/pvfs2tab
#
# Set this to the path of your OrangeFS tabfile (client connection information)
#export PVFS2TAB_FILE="/opt/orangefs/ofstab"

# Set this to a comma separated list of OrangeFS ofs_name:port pairs present in your PVFS2TAB_FILE
# This is typically used for HDFS to determine which host:port
# pair runs the namenode you wish to contact. For OrangeFS, we set this such that the programmer understands
# which FS they are contacting in an environment that may run more than one OrangeFS cluster.
# Once the HCFS plugin calls into the JNI layer, the URI scheme and authority will be removed
# and the OrangeFS mount location prepended to the path since OrangeFS handles conversion of path
# prefix to target a specific system mentioned in the PVFS2TAB_FILE.
#
# MUST have the format <string>:<integer>. 
export MY_HADOOP_ORANGEFS_SYSTEMS="ofs001-orangefs:3334"

# Set this to a comma separated list of mount points
export MY_HADOOP_ORANGEFS_MOUNT_LOCATIONS="/scratch1"

# Set this to your desired default HCFS (This examples uses the first in the comma separated list
# of $MY_HADOOP_ORANGEFS_SYSTEMS with the ofs:// 'scheme' prepended.
export MY_HADOOP_ORANGEFS_DEFAULT_SYSTEM="ofs://$(echo ${MY_HADOOP_ORANGEFS_SYSTEMS} | cut -d, -f1)"

# Set this to be a OrangeFS directory DIRECTLY UNDER the mount point of your OrangeFS system.
# The mount point of your OrangeFS system will be prepended to this value.
# Entire directory ancestory need not exist.
# Missing directories will be created automatically provided you have the proper permissions.
export MAPRED_DFS_DIR="${USER}/mapred"

set +x

function configure_and_start {
    #### Set this to the directory where Hadoop configs should be generated
    # Don't change the name of this variable (HADOOP_CONF_DIR) as it is
    # required by Hadoop - all config files will be picked up from here
    #
    # Make sure that this path is accessible by all nodes
    export HADOOP_CONF_DIR="${MY_HADOOP_SHARED_DIR}/myHadoop-orangefs-conf-${PBS_JOBID}"

    #### Set up the configuration
    echo "Set up the configurations for myHadoop"
    if ./bin/pbs-configure.bash; then
        echo "pbs-configure.bash completed successfully."
    else
        echo "pbs-configure.bash failed!" >&2
        exit 1
    fi
    echo

    #### Start the Hadoop cluster
    echo "Start Hadoop MapReduce daemons"
    ${HADOOP_PREFIX}/bin/start-mapred.sh
    echo
}

function stop_and_cleanup {
    #### Stop the Hadoop cluster
    echo "Stopping Hadoop MapReduce daemons"
    ${HADOOP_PREFIX}/bin/stop-mapred.sh
    echo

    #### Clean up the working directories after job completion
    echo "Cleaning up working directories."
    if ${MY_HADOOP_PREFIX}/bin/pbs-cleanup.bash; then
        echo "pbs-cleanup.bash completed successfully."
    else
        echo "pbs-cleanup.bash failed!" >&2
        exit 1
    fi
    echo
}
