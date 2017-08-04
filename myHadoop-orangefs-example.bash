#!/usr/bin/env bash

#PBS -q workq
#PBS -N TestDFSIO-myHadoop-orangefs
#PBS -l select=3:ncpus=8:mem=8gb:interconnect=10ge,place=scatter,walltime=00:30:00
#PBS -j oe

#set -x

cd "${PBS_O_WORKDIR}"

### Run the myHadoop environment script to set the appropriate variables
#
# Note: ensure that the variables are set correctly in bin/setenv.bash
. bin/setenv.bash

# NCPUS environment variable is set to your requested amount above
export MAX_REDUCE_TASKS_PER_SLAVE=1
export MAX_MAP_TASKS_PER_SLAVE=$(expr ${NCPUS} - 1 - ${MAX_REDUCE_TASKS_PER_SLAVE})
export NUM_PBS_NODES=$(cat ${PBS_NODEFILE} | wc -l)
export NUM_SLAVES=$(expr ${NUM_PBS_NODES} - 1)

# Configure and start your dynamic Hadoop cluster
configure_and_start

#### Run your jobs here
# =============================================================================
echo "Running some test Hadoop jobs"

# Basic test: 'ls' some OrangeFS files
${HADOOP_PREFIX}/bin/hadoop \
    --config $HADOOP_CONF_DIR fs -ls ofs://ofs001-orangefs:3334/${USER}

${HADOOP_PREFIX}/bin/hadoop \
    --config $HADOOP_CONF_DIR fs -lsr ofs://ofs001-orangefs:3334/benchmarks

# ~ TestDFSIO ~
TEST_DFSIO_FILE_COUNT=$(expr ${MAX_MAP_TASKS_PER_SLAVE} \* ${NUM_SLAVES})
TEST_DFSIO_FILE_SIZE_MB=1000 # 1GB

# WRITE
echo "Beginning to run TestDFSIO 'write'."
${HADOOP_PREFIX}/bin/hadoop \
    --config $HADOOP_CONF_DIR \
    jar $HADOOP_PREFIX/hadoop-test-1.2.1.jar \
    TestDFSIO \
    -write -nrFiles ${TEST_DFSIO_FILE_COUNT} -fileSize ${TEST_DFSIO_FILE_SIZE_MB}
echo "Done running TestDFSIO 'write'."

# READ
echo "Beginning to run TestDFSIO 'read'."
${HADOOP_PREFIX}/bin/hadoop \
    --config $HADOOP_CONF_DIR \
    jar $HADOOP_PREFIX/hadoop-test-1.2.1.jar \
    TestDFSIO \
    -read -nrFiles ${TEST_DFSIO_FILE_COUNT} -fileSize ${TEST_DFSIO_FILE_SIZE_MB}
echo "Done running TestDFSIO 'read'."

# Sleep for a while to enable inspection of WebUIs
#sleep 600 # 10 minutes
# =============================================================================

# Stop and cleanup your dynamic Hadoop cluster
stop_and_cleanup