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
logfile=${appdir}"/log/send_trans_to_queue.log"

now=$(date +'%Y-%m-%d %H:%M:%S')
echo ${now} "- Starting script" >> "${logfile}"

if [[ ! -d ${tmppath} ]] ; then
	now=$(date +'%Y-%m-%d %H:%M:%S')
	echo ${now} "- Creating directory" ${tmppath} >> "${logfile}"
	mkdir -p ${tmppath}
fi

if [[ ! -f ${queuefile} ]] ; then
	now=$(date +'%Y-%m-%d %H:%M:%S')
	echo ${now} "- Creating file" ${queuefile} >> "${logfile}"
	echo "[]" > ${queuefile}
elif [[ -z $(cat ${queuefile}) ]] ; then
	now=$(date +'%Y-%m-%d %H:%M:%S')
	echo ${now} "- The file" ${queuefile} "its empty!" >> "${logfile}"
	echo ${now} "- Creating file" ${queuefile} >> "${logfile}"
	echo "[]" > ${queuefile}
fi

if [[ ! -f ${transcribingfile} ]] ; then
	now=$(date +'%Y-%m-%d %H:%M:%S')
	echo ${now} "- Creating file" ${transcribingfile} >> "${logfile}"
	echo "[]" > ${transcribingfile}
fi

#get the conf json
curl -s -o "${jsonfile}" ${urljson}

for device in $(jq "keys | ." ${jsonfile} | awk -F"[\"\"]" '{print $2}' | grep .) ; do
	arrn=$(($(jq ".${device} | length" ${jsonfile})-1))
	for devicen in $(seq 0 ${arrn}) ; do
		state=$(jq --raw-output .${device}[${devicen}].state ${jsonfile})
		name=$(jq --raw-output .${device}[${devicen}].name ${jsonfile} | sed 's/ /-/g')
		savedisk=$(jq --raw-output .${device}[${devicen}].disk ${jsonfile})
		savediskn=$(printf %02d $(echo ${savedisk} | tr -d '[A-Za-z\/]'))
		savedisknm=$(echo ${savedisk} | awk -F"/" '{print $3}')
		source=$(echo "${savedisk}" | sed -e 's/\/disks\///g')
		transc=$(jq --raw-output .${device}[${devicen}].transc ${jsonfile})
		transcmachine=$(jq --raw-output .${device}[${devicen}].transc_machine ${jsonfile})
		devicename=$(echo ${device} | awk -F"_" '{print $1}' | tr '[:upper:]' '[:lower:]')
		radio=${name}_${state}
		sourcename=${devicename}${savediskn}

		if [[ "${transc}" == 'true' ]] ; then
			# echo >> "${logfile}"
			# echo >> "${logfile}"
			# echo ${radio} "must transcribe!" >> "${logfile}"

			lfilesurl=${urlfiles}"?source="${savedisknm}"&date="${today}"&radio="${radio}
			lfiles="${tmppath}/lfilesr.json"
			curl -s -o "${lfiles}" ${lfilesurl}
			arrlf=$(($(jq ". | length" ${lfiles})-1))
			for filen in $(seq 0 ${arrlf}) ; do
				file=$(jq --raw-output .[${filen}] ${lfiles} | sed -e 's/.mp3//g')
				filemp3=$(jq --raw-output .[${filen}] ${lfiles})
				filedate=$(echo ${file} | awk -F"_" '{print $1}')
				filetime=$(echo ${file} | awk -F"_" '{print $2}' | sed -e 's/-/:/g')
				fileradio=$(echo ${file} | awk -F"_" '{print $3}')
				filestate=$(echo ${file} | awk -F"_" '{print $4}')
				finalfile=${savedisknm}"_"${file}

				filedatetime=${filedate}" "${filetime}
				tsfiledate=$(date -d "${filedatetime}" +'%s')
				tsnow=$(date '+%s')
				tsfiletenm=$(date -d "$(echo ${filedatetime}) $(echo '10 minutes')" '+%s')

				# now=$(date +'%Y-%m-%d %H:%M:%S')
				# echo ${now} "-" ${finalfile} >> "${logfile}"
				# echo ${now} "- File datetime" $(date -d "${filedatetime}" '+%Y-%m-%d %H:%M:%S') >> "${logfile}"
				# echo "${finalfile}"

				if [[ ${tsnow} -gt ${tsfiletenm} ]] ; then
					arrnt=$(($(jq ".${device}[${devicen}].transc_time | length" ${jsonfile})-1))
					for timen in $(seq 0 ${arrnt}) ; do
						start=$(jq --raw-output .${device}[${devicen}].transc_time[${timen}].start ${jsonfile})
						end=$(jq --raw-output .${device}[${devicen}].transc_time[${timen}].end ${jsonfile})
						sdatetime=${today}" "${start}
						edatetime=${today}" "${end}
						tsstart=$(date -d "${sdatetime}" +'%s')
						tsend=$(date -d "${edatetime}" +'%s')

						# now=$(date +'%Y-%m-%d %H:%M:%S')
						# echo ${now} "-" ${finalfile} "- start time" ${sdatetime}
						# echo ${now} "-" ${finalfile} "- end time" ${edatetime}

						if [[ ${tsfiledate} -ge ${tsstart} ]] && [[ ${tsfiledate} -le ${tsend} ]] ; then
							# now=$(date +'%Y-%m-%d %H:%M:%S')
							# echo ${now} "-" ${finalfile} "- Its inside time interval" >> "${logfile}"

							#verify if the file exists on queue
							queueexists=$(jq '.[] | select(.file == "'${finalfile}'")' "${queuefile}")
							#verify if the file is transcribing
							istranscribing=$(jq '.[] | select(.file == "'${finalfile}'")' "${transcribingfile}")
							if [[ -z ${queueexists} ]] && [[ -z ${istranscribing} ]] ; then
								#verify if the file exists on noSQL
								fileexist=$(curl -s ${urlchecktrans}"?type=radio&filename="${finalfile})
								if [[ ${fileexist} -eq 0 ]] ; then
									now=$(date +'%Y-%m-%d %H:%M:%S')
									echo ${now} "-" ${finalfile} "- Sending to queue..." >> "${logfile}"
									added=$(jq --compact-output --argjson iadd '{"file": "'${finalfile}'","machine":"'${transcmachine}'"}' '. += [$iadd]' "${queuefile}")
									echo ${added} > "${queuefile}"
									# echo >> "${logfile}"
									break
								# else
								# 	echo "The file" ${finalfile} "already on Solr!" >> "${logfile}"
								fi
							# else
							# 	echo "The file" ${finalfile} "already on queue or transcription!" >> "${logfile}"
							fi
						fi
					done
				fi
			done
			rm -rf "${lfiles}"
		fi
	done
	# echo >> "${logfile}"
done

now=$(date +'%Y-%m-%d %H:%M:%S')
echo ${now} "- End script" >> "${logfile}"
echo >> "${logfile}"
