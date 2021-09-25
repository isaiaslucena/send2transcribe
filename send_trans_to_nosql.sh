#!/bin/bash

export TZ='America/Sao_Paulo'

IFS="
"

today=$(date +'%Y-%m-%d')
todayts=$(date +'%s')

machine="${1}"
file="${2}"
transc_machine="${3}"
transc_url="http://${transc_machine}:8025/asr-server/rest/recognize"

appdir="${SEND_TRANSC_DIR}"
appconf="${SEND_TRANSC_CONF}"
urljson=$(jq --raw-output .urljson "${appconf}")
urlfiles=$(jq --raw-output .urlfiles "${appconf}")
urlaudio=$(jq --raw-output .urlaudio "${appconf}")
urlvideo=$(jq --raw-output .urlvideo "${appconf}")
urlchecktrans=$(jq --raw-output .urlchecktrans "${appconf}")
urlsavetrans=$(jq --raw-output .urlsavetrans "${appconf}")
tmppath=$(jq --raw-output .tmppath "${appconf}")
queuefile=${appdir}$(jq --raw-output .queuefile "${appconf}")
transcribingfile=${appdir}$(jq --raw-output .transcribingfile "${appconf}")
jsonfile=${tmppath}$(jq --raw-output .jsonfile "${appconf}")
logfile=${appdir}"/log/send_trans_to_nosql.log"

file_without_extension=$(echo "${file}" | sed 's/.mp3\|.mp4//')
filename=$(echo "${file_without_extension}" | awk -F"_" '{print $2"_"$3"_"$4"_"$5}')
source=$(echo "${file_without_extension}" | awk -F"_" '{print $1}')
channel=$(echo "${file_without_extension}" | awk -F"_" '{print $4}')
state=$(echo "${file_without_extension}" | awk -F"_" '{print $5}')

file_wav=$(echo "${file}" | sed 's/.mp3\|.mp4/.wav/')

search_mp4=$(echo "${file}" | grep -e '.mp4')

if [[ -z "${search_mp4}" ]] ; then
  type="audio"
else
  type="video"
fi

file_url="${machine}${urlvideo}/${file_without_extension}"
file_wav_path="${tmppath}/${file_wav}"
ffmpeg -loglevel quiet -i "${file_url}" -ar 8k -filter:a "volume=10dB" -y "${file_wav_path}"
sleep 2

now=$(date +'%Y-%m-%d %H:%M:%S')
echo "${now} - ${file} - Transcribing file" >> "${logfile}"

resptransc="${tmppath}/resptransc_${file_without_extension}.json"
transcpayload="${tmppath}/payload_${file_without_extension}.json"

transcstart=$(date +'%Y-%m-%dT%H:%M:%S-03:00')
curl -s -o "${resptransc}" --header "Content-Type: audio/wav" --header "decoder.continuousMode: true" --data-binary "@${file_wav_path}" "${transc_url}"
transcend=$(date +'%Y-%m-%dT%H:%M:%S-03:00')

now=$(date +'%Y-%m-%d %H:%M:%S')
echo "${now} - ${file} - Transcribe done!" >> "${logfile}"

# rm -rf "${file_wav_path}"

now=$(date +'%Y-%m-%d %H:%M:%S')
echo "${now} - ${file} - Inserting transcription to Solr" >> "${logfile}"

res_transc_length=$(jq '. | length' "${resptransc}")
res_transc_last_index=$(("${res_transc_length}" - 1))

fulltext=""
fullwords=""

for index in $(seq 0 "${res_transc_last_index}") ; do
  status=$(jq --raw-output .["${index}"].result_status "${resptransc}")

  if [ "${status}" == 'RECOGNIZED' ] ; then
    text=$(jq --raw-output .["${index}"].alternatives[0].text "${resptransc}")
    words=$(jq --compact-output .["${index}"].alternatives[0].words "${resptransc}")

    fulltext="${fulltext} ${text}"
    fullwords="${fullwords} ${words}"
  fi
done

fullwords_with_escape=$(echo "${fullwords}" | sed 's/"/\\"/g')

created_at=$(date +'%Y-%m-%dT%H:%M:%S-03:00')
echo '{"type":"'${type}'","machine":"'${machine}'","source":"'${source}'","channel":"'${channel}'","state":"'${state}'","filename":"'${file}'","created_at":"'${created_at}'","transcribe_start":"'${transcstart}'","transcribe_end":"'${transcend}'","text_content":"'${fulltext}'","text_time":"'${fullwords_with_escape}'"}' > "${transcpayload}"
curl -s -o /dev/null -H "Content-Type: application/json" -d "@${transcpayload}" "${urlsavetrans}"
now=$(date +'%Y-%m-%d %H:%M:%S')
echo "${now} - ${file} - Insert done!" >> "${logfile}"

# rm -rf "${resptransc}"
# rm -rf "${transcpayload}"

now=$(date +'%Y-%m-%d %H:%M:%S')
echo "${now} - ${file} - Removing file from transcribing" >> "${logfile}"
# remove from transcribing
delitem=$(jq --compact-output 'del(.[] | select(.file == "'${file}'"))' "${transcribingfile}")
echo "${delitem}" > "${transcribingfile}"
