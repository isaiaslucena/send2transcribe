#!/bin/bash -x

if [[ ! -v SEND_TRANSC_DIR ]] ; then
    echo "SEND_TRANSC_DIR is not set"
    export SEND_TRANSC_DIR="/home/isaiasneto/applications/send2transc"
elif [[ -z "${SEND_TRANSC_DIR}" ]] ; then
    echo "SEND_TRANSC_DIR is set and its empty"
    export SEND_TRANSC_DIR="/home/isaiasneto/applications/send2transc"
else
    echo "SEND_TRANSC_DIR has the value: ${SEND_TRANSC_DIR}"
fi

if [[ ! -v SEND_TRANSC_CONF ]] ; then
    echo "SEND_TRANSC_CONF is not set"
    export SEND_TRANSC_CONF=${SEND_TRANSC_DIR}"/send2transc.json"
elif [[ -z "${SEND_TRANSC_CONF}" ]] ; then
    echo "SEND_TRANSC_CONF is set and its empty"
    export SEND_TRANSC_CONF=${SEND_TRANSC_DIR}"/send2transc.json"
else
    echo "SEND_TRANSC_CONF has the value: ${SEND_TRANSC_CONF}"
fi