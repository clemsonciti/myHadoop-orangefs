#!/usr/bin/env bash

STAT_INTERVAL=15

qsub $1 | tail -n1 | xargs watch --interval=${STAT_INTERVAL} qstat
