#!/usr/bin/env bash

#set -x

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

# Run the save and cleanup commands on each node of the job
for node in ${PBS_NODES}; do

    # Exports all .log and .out files before removing them.
    if [ "${MY_HADOOP_LOG_SAVE_ENABLED}" = true ] ; then
        save_cmd="echo Saving Hadoop log files node: ${node} to shared directory: ${MY_HADOOP_LOG_SAVE_DIR};"
        save_cmd="${save_cmd} mkdir -p ${MY_HADOOP_LOG_SAVE_DIR};"
        save_cmd="${save_cmd} cp -r ${HADOOP_LOG_DIR}/* ${MY_HADOOP_LOG_SAVE_DIR}/;"
    fi

    # Cleans up working directories of Hadoop cluster
    cleanup_cmd="echo Cleaning up node: ${node};"
    cleanup_cmd="${cleanup_cmd} rm -rf ${HADOOP_TMP_DIR} ${HADOOP_LOG_DIR};"

    ssh ${node} ${save_cmd} ${cleanup_cmd}
done
