#!/bin/bash

appdir="${SEND_TRANSC_DIR}"
pid=$(pidof -x "send_trans_to_machine.sh")
if [[ -z ${pid} ]] ; then
	echo "send_trans_to_machine.sh is not running!"
	"${appdir}"/send_trans_to_machine.sh &
else
	echo "send_trans_to_machine.sh is running!"
fi
