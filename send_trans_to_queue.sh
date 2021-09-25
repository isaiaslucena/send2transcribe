#!/bin/bash

export TZ='America/Sao_Paulo'

IFS="
"

today=$(date +'%Y-%m-%d')
todayts=$(date +'%s')

# today="2020-11-02"
# todayts=$(date -d "${today}" +'%s')

appdir="${SEND_TRANSC_DIR}"
appconf="${SEND_TRANSC_CONF}"
urljson=$(jq --raw-output .urljson "${appconf}")
urlfiles=$(jq --raw-output .urlfiles "${appconf}")
urlmp3=$(jq --raw-output .urlmp3 "${appconf}")
urlchecktrans=$(jq --raw-output .urlchecktrans "${appconf}")
urlsavetrans=$(jq --raw-output .urlsavetrans "${appconf}")
tmppath=$(jq --raw-output .tmppath "${appconf}")
queuefile="${appdir}"$(jq --raw-output .queuefile "${appconf}")
transcribingfile="${appdir}"$(jq --raw-output .transcribingfile "${appconf}")
jsonfile="${tmppath}"$(jq --raw-output .jsonfile "${appconf}")
logpath="${appdir}/log"
logfile="${appdir}/log/send_trans_to_queue.log"

if [[ ! -d "${logpath}" ]] ; then
	mkdir -p "${logpath}"
fi

now=$(date +'%Y-%m-%d %H:%M:%S')
echo "${now} - Starting script" >> "${logfile}"

if [[ ! -d "${tmppath}" ]] ; then
	now=$(date +'%Y-%m-%d %H:%M:%S')
	echo "${now} - Creating directory ${tmppath}"
	mkdir -p "${tmppath}"
fi

if [[ ! -f ${queuefile} ]] ; then
	now=$(date +'%Y-%m-%d %H:%M:%S')
	echo "${now} - Creating file ${queuefile}"
	echo "[]" > "${queuefile}"
elif [[ -z $(cat "${queuefile}") ]] ; then
	now=$(date +'%Y-%m-%d %H:%M:%S')
	echo "${now} - The file ${queuefile} its empty!"
	echo "${now} - Creating file ${queuefile}"
	echo "[]" > "${queuefile}"
fi

if [[ ! -f ${transcribingfile} ]] ; then
	now=$(date +'%Y-%m-%d %H:%M:%S')
	echo "${now} - Creating file ${transcribingfile}"
	echo "[]" > "${transcribingfile}"
fi

# get the conf json
curl -s -o "${jsonfile}" "${urljson}"

machines_length=$(( $(jq ". | length" "${jsonfile}") - 1 ))
# for device in $(jq "keys | ." ${jsonfile} | awk -F"[\"\"]" '{print $2}' | grep .) ; do
for machine_index in $(seq 0 "${machines_length}") ; do
	machine=$(jq --raw-output .["${machine_index}"].machine "${jsonfile}")
	# machine_conf=$(jq --raw-output .["${machine_index}"].conf "${jsonfile}")
	machine_conf_length=$(( $(jq ".[${machine_index}].conf[] | length" "${jsonfile}") - 1 ))
	now=$(date +'%Y-%m-%d %H:%M:%S')
	echo "${now} - Machine ${machine}" >> "${logfile}"
	# echo "${machine_conf_length}"
	# read
	for source in $(jq ".[${machine_index}].conf | keys" "${jsonfile}" | awk -F"[\"\"]" '{print $2}' | grep .) ; do
		# now=$(date +'%Y-%m-%d %H:%M:%S')
		# echo "${now} - ${source}" >> "${logfile}"
		for channel_index in $(seq 0 "${machine_conf_length}") ; do
			channel_state=$(jq --raw-output .["${machine_index}"].conf."${source}"["${channel_index}"].state "${jsonfile}")
			channel_name=$(jq --raw-output .["${machine_index}"].conf."${source}"["${channel_index}"].name ${jsonfile} | sed 's/ /-/g')
			channel_transc=$(jq --raw-output .["${machine_index}"].conf."${source}"["${channel_index}"].transc "${jsonfile}")
			channel_transc_machine=$(jq --raw-output .["${machine_index}"].conf."${source}"["${channel_index}"].transc_machine "${jsonfile}")
			channel="${channel_name}_${channel_state}"

			if [[ "${channel_transc}" == 'true' ]] ; then
				# now=$(date +'%Y-%m-%d %H:%M:%S')
				# echo "${now} - ${channel} must transcribe!" >> "${logfile}"

				files_list_url="${machine}${urlfiles}/${source}/${today}/${channel_name}/${channel_state}"
				files_list=$(curl -s "${files_list_url}")
				files_list_length=$(( $(echo "${files_list}" | jq ". | length") - 1 ))
				for file_index in $(seq 0 ${files_list_length}) ; do
					file=$(echo "${files_list}" | jq --raw-output .["${file_index}"])
					filename=$(echo "${files_list}" | jq --raw-output .["${file_index}"] | sed -e 's/.mp4//g')
					file_date=$(echo ${file} | awk -F"_" '{print $1}')
					file_time=$(echo ${file} | awk -F"_" '{print $2}' | sed -e 's/-/:/g')
					file_channel=$(echo ${file} | awk -F"_" '{print $3}')
					file_state=$(echo ${file} | awk -F"_" '{print $4}')
					finalfile="${source}_${file}"

					file_datetime="${file_date} ${file_time}"
					timestamp_filedate=$(date -d "${file_datetime}" +'%s')
					now_timestamp=$(date '+%s')
					file_timestamp_plus_five_minutes=$(date -d "$(echo "${file_datetime}") $(echo '5 minutes')" '+%s')

					# now=$(date +'%Y-%m-%d %H:%M:%S')
					# echo "${now} - ${finalfile}"
					# echo "${now} - File datetime ${file_datetime}"
					# echo "${now} - ${finalfile}"

					if [[ "${now_timestamp}" -gt "${file_timestamp_plus_five_minutes}" ]] ; then
						channel_transc_time_length=$(( $(jq ".[${machine_index}].conf.${source}[${channel_index}].transc_time | length" "${jsonfile}") - 1 ))
						for time_index in $(seq 0 "${channel_transc_time_length}") ; do
							start=$(jq --raw-output .["${machine_index}"].conf."${source}"["${channel_index}"].transc_time["${time_index}"].start "${jsonfile}")
							end=$(jq --raw-output .["${machine_index}"].conf."${source}"["${channel_index}"].transc_time["${time_index}"].end "${jsonfile}")
							start_datetime="${today} ${start}"
							end_datetime="${today} ${end}"
							timestamp_start=$(date -d "${start_datetime}" +'%s')
							timestamp_end=$(date -d "${end_datetime}" +'%s')

							# now=$(date +'%Y-%m-%d %H:%M:%S')
							# echo "${now} - ${finalfile} - start time ${start_datetime}"
							# echo "${now} - ${finalfile} - end time ${end_datetime}"

							if [[ "${timestamp_filedate}" -ge "${timestamp_start}" ]] && [[ "${timestamp_filedate}" -le ${timestamp_end} ]] ; then
								# now=$(date +'%Y-%m-%d %H:%M:%S')
								# echo "${now} - ${file} its inside time interval" >> "${logfile}"

								# verify if the file exists on queue
								queue_exists=$(jq '.[] | select(.file == "'${finalfile}'")' "${queuefile}")
								# verify if the file is transcribing
								is_transcribing=$(jq '.[] | select(.file == "'${finalfile}'")' "${transcribingfile}")
								if [[ -z "${queue_exists}" ]] && [[ -z "${is_transcribing}" ]] ; then
									# verify if the file exists on noSQL
									# file_exist=$(curl -s ${urlchecktrans}"?type=radio&filename="${finalfile})
									file_exist=$(curl -s "${urlchecktrans}?machine=${machine}&filename=${finalfile}")
									# file_exist=0
									# read
									if [[ "${file_exist}" -eq 0 ]] ; then
										now=$(date +'%Y-%m-%d %H:%M:%S')
										echo "${now} - ${finalfile} - Sending to queue..." >> "${logfile}"
										added=$(jq --compact-output --argjson iadd '{"machine": "'${machine}'","file": "'${finalfile}'","transc_machine":"'${channel_transc_machine}'"}' '. += [$iadd]' "${queuefile}")
										echo "${added}" > "${queuefile}"
										# echo >> "${logfile}"
										break
									else
										echo "The file ${finalfile} already on Solr!"
									fi
								else
									echo "The file ${finalfile} already on queue!"
								fi
							fi
						done
					fi
				done
			fi
		done
		echo >> "${logfile}"
	done
done

now=$(date +'%Y-%m-%d %H:%M:%S')
echo "${now} - End script" >> "${logfile}"
echo >> "${logfile}"
