#!/bin/bash

appdir="${SEND_TRANSC_DIR:default}"
pid=$(pidof -x "send_trans_to_queue.sh")
if [[ -z ${pid} ]] ; then
	echo "send_trans_to_queue.sh is not running!"
	echo ${appdir}"/send_trans_to_queue.sh &"
else
	echo "send_trans_to_queue.sh is running!"
fi
