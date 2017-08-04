#!/usr/bin/env bash

#set -x

if [ "${HADOOP_CONF_DIR}" != "" ]; then
    echo "Generating Hadoop configuration in directory: ${HADOOP_CONF_DIR}"
else 
    echo "Location of configuration directory not specified!"
    exit 1
fi

# get the number of nodes from PBS_NODEFILE and confirm there are at least 2 nodes
if [ -e ${PBS_NODEFILE} ]; then
    
    PBS_NODES="$(cat ${PBS_NODEFILE})"
    NUM_PBS_NODES=$(echo "${PBS_NODES}" | wc -l)
    
    echo "Received ${NUM_PBS_NODES} nodes from PBS"

    # Ensure number of PBS nodes is >= 2. One for the JT and at least one slave.
    if [ "$NUM_PBS_NODES" -lt "2" ]; then
        echo "Number of nodes received from PBS is less than 2. myHadoop-orangefs job requires at least 2 nodes."
        exit 1
    fi
else 
    echo "PBS_NODEFILE is unavailable"
    exit 1
fi

# create the config, data, and log directories
rm -rf ${HADOOP_CONF_DIR}
mkdir -p ${HADOOP_CONF_DIR}

# first copy over all default Hadoop configs
cp ${HADOOP_PREFIX}/conf/* ${HADOOP_CONF_DIR}

# pick the master node as the first node in the ${PBS_NODEFILE} file
head -n1 ${PBS_NODEFILE} > ${HADOOP_CONF_DIR}/jt

# TODO: Test usage of IPoIB on Palmetto Cluster.
# Use IB interface instead of what PBS gave us.
#sed -i 's/.palmetto/-ib0.palmetto/g' $HADOOP_CONF_DIR/jt

MASTER_NODE=$(cat ${HADOOP_CONF_DIR}/jt)

echo "JobTracker will be: ${MASTER_NODE}"
echo

# every node in the ${PBS_NODEFILE} file, except for the first, becomes a slave
sed 1,1d ${PBS_NODEFILE} > ${HADOOP_CONF_DIR}/slaves

# TODO: Test usage of IPoIB on Palmetto Cluster.
# Use IB interface instead of what PBS gave us.
#sed -i 's/.palmetto/-ib0.palmetto/g' $HADOOP_CONF_DIR/slaves

# update the mapred configs
cp -f \
    ${MY_HADOOP_PREFIX}/etc/core-site.xml \
    ${MY_HADOOP_PREFIX}/etc/mapred-site.xml \
    ${HADOOP_CONF_DIR}/

sed -i 's:HADOOP_TMP_DIR:'"${HADOOP_TMP_DIR}"':g' ${HADOOP_CONF_DIR}/core-site.xml
sed -i 's MY_HADOOP_ORANGEFS_DEFAULT_SYSTEM '"${MY_HADOOP_ORANGEFS_DEFAULT_SYSTEM}"' g' ${HADOOP_CONF_DIR}/core-site.xml
sed -i 's MY_HADOOP_ORANGEFS_SYSTEMS '"${MY_HADOOP_ORANGEFS_SYSTEMS}"' g' ${HADOOP_CONF_DIR}/core-site.xml
sed -i 's MY_HADOOP_ORANGEFS_MOUNT_LOCATIONS '"${MY_HADOOP_ORANGEFS_MOUNT_LOCATIONS}"' g' ${HADOOP_CONF_DIR}/core-site.xml

sed -i 's/<value>.*:/<value>'"${MASTER_NODE}"':/g' ${HADOOP_CONF_DIR}/mapred-site.xml
sed -i 's MAPRED_DFS_DIR '"${MAPRED_DFS_DIR}"' g' ${HADOOP_CONF_DIR}/mapred-site.xml
sed -i 's/MAX_MAP_TASKS_PER_SLAVE/'${MAX_MAP_TASKS_PER_SLAVE}'/g' ${HADOOP_CONF_DIR}/mapred-site.xml
sed -i 's/MAX_REDUCE_TASKS_PER_SLAVE/'${MAX_REDUCE_TASKS_PER_SLAVE}'/g' ${HADOOP_CONF_DIR}/mapred-site.xml

# update the HADOOP log directory
echo "" >> ${HADOOP_CONF_DIR}/hadoop-env.sh
echo "# Overwrite location of the log directory" >> ${HADOOP_CONF_DIR}/hadoop-env.sh
echo "export HADOOP_LOG_DIR=${HADOOP_LOG_DIR}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh

# Adds OrangeFS specific environment variables to hadoop-env.sh
# ===============================================================================================
echo "# JAVA_HOME location on scheduled nodes" >> ${HADOOP_CONF_DIR}/hadoop-env.sh
echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh

echo "# OrangeFS specific variables:" >> ${HADOOP_CONF_DIR}/hadoop-env.sh
echo "export JNI_LIBRARY_PATH=${JNI_LIBRARY_PATH}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh
echo "export HADOOP_CLASSPATH=${JNI_LIBRARY_PATH}/orangefs-hadoop1-${ORANGEFS_VERSION}.jar:${JNI_LIBRARY_PATH}/orangefs-jni-${ORANGEFS_VERSION}.jar" >> ${HADOOP_CONF_DIR}/hadoop-env.sh

echo "export ORANGEFS_STRIP_SIZE_AS_BLKSIZE=${ORANGEFS_STRIP_SIZE_AS_BLKSIZE}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh

if [ -z "${PVFS2TAB_FILE}" ]; then
    unset ${PVFS2TAB_FILE} # Handles case where $PVFS2TAB_FILE is empty string
    echo "Using default PVFS2 'tabfile' path of /etc/pvfs2tab"
else
    echo "export PVFS2TAB_FILE=${PVFS2TAB_FILE}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh
fi
# ===============================================================================================

# Creates HADOOP_{LOG,TMP}_DIR on all slaves
for node in ${PBS_NODES}; do
    create_cmd="echo Configuring node: ${node};"
    create_cmd="${create_cmd} rm -rf ${HADOOP_LOG_DIR} ${HADOOP_TMP_DIR};"
    create_cmd="${create_cmd} mkdir -p ${HADOOP_LOG_DIR} ${HADOOP_TMP_DIR};"
    create_cmd="${create_cmd} touch ${HADOOP_CONF_DIR};" # Forces invalidation of NFS cache?

    ssh ${node} ${create_cmd}
done
