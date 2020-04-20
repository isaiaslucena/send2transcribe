#!/bin/bash

export TZ='America/Sao_Paulo'

IFS="
"

today=$(date +'%Y-%m-%d')
todayts=$(date +'%s')

appdir="${SEND_TRANSC_DIR}"
appconf="${SEND_TRANSC_CONF}"
urljson=$(jq --raw-output .urljson ${appconf})
urlfiles=$(jq --raw-output .urlfiles ${appconf})
urlmp3=$(jq --raw-output .urlmp3 ${appconf})
urlchecktrans=$(jq --raw-output .urlchecktrans ${appconf})
urlsavetrans=$(jq --raw-output .urlsavetrans ${appconf})
tmppath=$(jq --raw-output .tmppath ${appconf})
queuefile=${appdir}$(jq --raw-output .queuefile ${appconf})
transcribingfile=${appdir}$(jq --raw-output .transcribingfile ${appconf})
jsonfile=${tmppath}$(jq --raw-output .jsonfile ${appconf})
logpath=${appdir}"/log"
logfile=${appdir}"/log/send_trans_to_machine.log"

if [[ ! -d ${logpath} ]] ; then
	mkdir -p ${logpath}
fi

queuecount=0
w=1
while [[ ${w} -eq 1 ]] ; do
	arrc=$(($(jq ". | length" ${queuefile})))
	arr=$(($(jq ". | length" ${queuefile})-1))

	if [[ ${arrc} -ne ${queuecount} ]] ; then
		now=$(date +'%Y-%m-%d %H:%M:%S')
		echo ${now} "- The queue has" ${arrc} "files" >> "${logfile}"
	fi

	if [[ ${arrc} -gt 0 ]] ; then
		tcount=1
		for arrn in $(seq 0 ${arr}) ; do
			filename=$(jq --raw-output .[$arrn].file "${queuefile}")
			filemachine=$(jq --raw-output .[$arrn].machine "${queuefile}")
			arrnn=$(( ${arrn} + 1 ))
			# echo "File" ${arrnn}"/"${arrc}
			# echo "Filename:" ${filename}
			# echo "Machine:" ${filemachine}
			# echo

			if [[ ${tcount} -eq 1 ]] ; then
				firstfname=${filename}
				firstfmachine=${filemachine}
			elif [[ ${tcount} -eq 2 ]] ; then
				secondfname=${filename}
				secondfmachine=${filemachine}
				# echo "Sent" ${tcount} "files to transcribe. Bye!"
			elif [[ ${tcount} -ge 3 ]] ; then
				# echo "counter reach 3!"
				tcount=1
				break
			fi
			# echo ${tcount}
			let "tcount++"
		done

		# echo "first file" ${firstfname}
		# echo "second file" ${secondfname}
		# echo
		# echo

		actpids=()
		pids=$(pidof -x "send_trans_to_nosql.sh" | tr " " "\n")
		for pid in ${pids} ; do
			actpids+=(${pid})
		done

		pidsc="${#actpids[@]}"
		if [[ ${pidsc} -eq 0 ]] ; then
			now=$(date +'%Y-%m-%d %H:%M:%S')
			echo ${now} "- None pid!" >> "${logfile}"
			echo ${now} "-" ${firstfname} "- Starting transcribing file" >> "${logfile}"
			"${appdir}"/send_trans_to_nosql.sh "${firstfname}" "${firstfmachine}" &
			sleep 1

			now=$(date +'%Y-%m-%d %H:%M:%S')
			echo ${now} "-" ${firstfname} "- Removing file from queue" >> "${logfile}"
			#remove from queue
			delitem=$(jq --compact-output 'del(.[] | select(.file == "'${firstfname}'"))' "${queuefile}")
			echo "${delitem}" > "${queuefile}"

			now=$(date +'%Y-%m-%d %H:%M:%S')
			echo ${now} "-" ${firstfname} "- Adding file to trancribing" >> "${logfile}"
			#add to transcribing
			added=$(jq --compact-output --argjson iadd '{"file": "'${firstfname}'","machine":"'${firstfmachine}'"}' '. += [$iadd]' "${transcribingfile}")
			echo ${added} > "${transcribingfile}"



			now=$(date +'%Y-%m-%d %H:%M:%S')
			echo ${now} "-" ${secondfname} "- Starting transcribing file" >> "${logfile}"
			"${appdir}"/send_trans_to_nosql.sh "${secondfname}" "${secondfmachine}" &
			sleep 1

			now=$(date +'%Y-%m-%d %H:%M:%S')
			echo ${now} "-" ${secondfname} "- Removing file from queue" >> "${logfile}"
			#remove from queue
			delitem=$(jq --compact-output 'del(.[] | select(.file == "'${secondfname}'"))' "${queuefile}")
			echo "${delitem}" > "${queuefile}"

			now=$(date +'%Y-%m-%d %H:%M:%S')
			echo ${now} "-" ${firstfname} "- Adding file to transcribing" >> "${logfile}"
			#add to transcribing
			added=$(jq --compact-output --argjson iadd '{"file": "'${secondfname}'","machine":"'${secondfmachine}'"}' '. += [$iadd]' "${transcribingfile}")
			echo ${added} > "${transcribingfile}"

		elif [[ ${pidsc} -eq 1 ]] ; then
			now=$(date +'%Y-%m-%d %H:%M:%S')
			echo ${now} "- One pid!" >> "${logfile}"
			echo ${now} "-" ${firstfname} "- Starting transcribing file" >> "${logfile}"
			"${appdir}"/send_trans_to_nosql.sh "${firstfname}" "${firstfmachine}" &
			sleep 1

			now=$(date +'%Y-%m-%d %H:%M:%S')
			echo ${now} "-" ${firstfname} "- Removing file from queue" >> "${logfile}"
			#remove from queue
			delitem=$(jq --compact-output 'del(.[] | select(.file == "'${firstfname}'"))' "${queuefile}")
			echo "${delitem}" > "${queuefile}"

			now=$(date +'%Y-%m-%d %H:%M:%S')
			echo ${now} "-" ${firstfname} "- Adding file to transcribing" >> "${logfile}"
			#add to transcribing
			added=$(jq --compact-output --argjson iadd '{"file": "'${firstfname}'","machine":"'${firstfmachine}'"}' '. += [$iadd]' "${transcribingfile}")
			echo ${added} > "${transcribingfile}"

		# elif [[ ${pidsc} -eq 2 ]] ; then
			# echo "Two pids! Do nothing..."
		fi
	fi

	# echo
	queuecount=${arrc}
	sleep 10
done
