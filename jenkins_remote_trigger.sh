#!/bin/bash

# *************************************************************
function success() {
    prompt="$1"
    echo -e -n "\033[1;32m$prompt"
    echo -e -n '\033[0m'
    echo -e -n "\n"
}
function error() {
    prompt="$1"
    echo -e -n "\033[1;31m$prompt"
    echo -e -n '\033[0m'
    echo -e -n "\n"
}
function info() {
    prompt="$1"
    echo -e -n "\033[1;36m$prompt"
    echo -e -n '\033[0m'
    echo -e -n "\n"
}
# *************************************************************

usage()
{
    cat << USAGE >&2
Usage:
    -h HOST     | --host=HOST                       Jenkins host
    -j JOBNAME  | --jobname=test-build-job          The name of the jenkins job to trigger
    -p JOBPARAM | --jobparam=environment=uat&test=1 Jenkins job paramiters
    -q          | --quiet                           Don't output any status messages
    -t TIMEOUT  | --timeout=TIMEOUT                 Timeout in minutes, zero for no timeout
USAGE
    exit 1
}

# process arguments
while [[ $# -gt 0 ]]
do
    case "$1" in
        -q | --quiet)
        QUIET=1
        shift 1
        ;;
        -h)
        HOST="$2"
        if [[ $HOST == "" ]]; then break; fi
        shift 2
        ;;
        --host=*)
        HOST="${1#*=}"
        shift 1
        ;;
        -t)
        TIMEOUT="$2"
        if [[ $TIMEOUT == "" ]]; then break; fi
        shift 2
        ;;
        --timeout=*)
        TIMEOUT="${1#*=}"
        shift 1
        ;;
        -j)
        JOBNAME="$2"
        if [[ $JOBNAME == "" ]]; then break; fi
        shift 2
        ;;
        --jobname=*)
        JOBNAME="${1#*=}"
        shift 1
        ;;
        -p)
        JOBPARAM="$2"
        if [[ $JOBPARAM == "" ]]; then break; fi
        shift 2
        ;;
        --jobparam=*)
        JOBPARAM="${1#*=}"
        shift 1
        ;;
        --)
        shift
        CLI="$@"
        break
        ;;
        --help)
        usage
        ;;
        *)
        echoerr "Unknown argument: $1"
        usage
        ;;
    esac
done

TIMEOUT=${TIMEOUT:-30}
QUIET=${QUIET:-0}

TRIGGERURL="${HOST}/job/${JOBNAME}/buildWithParameters?${JOBPARAM}"

if [ $QUIET -eq 0 ];then
    info "Making request to trigger $JOBNAME job at: "
    echo "     ${TRIGGERURL}"
    info ""
fi

TMP=`curl -s -D - -X POST "$TRIGGERURL"`
QID=`echo "$TMP" | grep Location | cut -d "/" -f 6`

QUEUE_URL="${HOST}/queue/item/${QID}/api/json?pretty=true"

sleep 1

while curl -v $QUEUE_URL 2>&1 | egrep -q "BlockedItem|WaitingItem";   
do
    if [ $QUIET -eq 0 ];then
        info "Waiting for queued job to start.."
    fi
    sleep 5
done

JOBID=$(curl -s "$QUEUE_URL" | jq --raw-output '.executable.number')
JOBURL=$(curl -s "$QUEUE_URL" | jq --raw-output '.executable.url')

if [ -z "$JOBID" ];
then
    if [ $QUIET -eq 0 ];then
        error "Error creating job."
    fi
    exit 1
fi

if [ $QUIET -eq 0 ];then
    success ""
    success "Jenkins job $JOBID created, waiting to complete.."
    success ""
fi

STATUS=""
while [ "$STATUS" != 200 ]
do
  sleep 1
  STATUS=`curl -s -o /dev/null -w "%{http_code}" "${JOBURL}"consoleText`
done

JOBURLJSON="$JOBURL"api/json?pretty=true
BUILDING=$(curl -s "$JOBURLJSON" |jq --raw-output '.building')
while $BUILDING; do
    BUILDING=$(curl -s "$JOBURLJSON" |jq --raw-output '.building')
    if [ $QUIET -eq 0 ];then
        info "Building.."
    fi
    sleep 10
done

JOBSTATUS=$(curl -s "$JOBURLJSON" |jq --raw-output '.result')

if [ $QUIET -eq 0 ];then
    NOTIFY=error
    if [ "$JOBSTATUS" == "SUCCESS" ]; then
        NOTIFY=success
    fi
    $NOTIFY ""
    $NOTIFY "Job $JOBID finished with status: $JOBSTATUS"
    $NOTIFY ""
fi

[[ "$JOBSTATUS" == "SUCCESS" ]]