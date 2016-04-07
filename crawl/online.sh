#!/bin/sh

BASEDIC=$1

# TASK_NUM=50
TASK_NUM=20
STARTDATE=20120625
BASEDIR=/yew/murawaki/crawl-data-daily
LOG_FILE=$BASEDIR/log
TMP_BASE=$BASEDIR/tmp
DIC_BASE=/data/murawaki/crawl-data-daily/dic
PROGRAM_BASE=$HOME/research/lebyr/crawl

mkdir -p $BASEDIR/state
GXP_OPTS="-a cpu_factor=0.25 -a state_dir=$BASEDIR/state"
MASTER_HOST=`hostname`
MASTER_PORT=20333

if [ -f "$BASEDIC" ]; then
    WORKER_OPT="--basedic $BASEDIC"
fi

MASTER_PROGRAM="nice -19 perl $PROGRAM_BASE/master.pl --port=$MASTER_PORT"
WORKER_PROGRAM="nice -19 perl $PROGRAM_BASE/worker.pl --master=$MASTER_HOST:$MASTER_PORT --safeMode --debug $WORKER_OPT"
SEEKER_PROGRAM="nice -19 perl $PROGRAM_BASE/seeker.pl --master=$MASTER_HOST:$MASTER_PORT --startdate=$STARTDATE --tmpdir=$TMP_BASE"

echo $MASTER_PROGRAM
$MASTER_PROGRAM &
MASTER_PID=$!
sleep 5
echo $SEEKER_PROGRAM
$SEEKER_PROGRAM &
SEEKER_PID=$!

echo gxp js
for ((i=1;i<=$TASK_NUM;i+=1)); do
    echo "sh -c \" $WORKER_PROGRAM --dicdir=$DIC_BASE/dic_$i >> $LOG_FILE 2>&1 \""
done | gxpc js -a work_fd=0 $GXP_OPTS

kill $SEEKER_PID
kill $MASTER_PID
