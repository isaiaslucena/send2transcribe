#!/bin/bash

export TZ='America/Sao_Paulo'

IFS="
"
today=$(date +'%Y-%m-%d')
todayts=$(date +'%s')

file="${1}"
machine="${2}"
transcurl="http://"${machine}

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
logfile=${appdir}"/log/send_trans_to_nosql.log"

fileo=$(echo ${file} | awk -F"_" '{print $2"_"$3"_"$4"_"$5}')
sourceo=$(echo ${file} | awk -F"_" '{print $1}')
filemp3=${file}.mp3
downfileurl=${urlmp3}"?source="${sourceo}"&file="${fileo}
mp3path=${tmppath}"/"${filemp3}
curl -s -o "${mp3path}" "${downfileurl}"
sleep 2

now=$(date +'%Y-%m-%d %H:%M:%S')
echo ${now} "-" ${file} "- Transcribing file" >> "${logfile}"
ts=$(date +'%s')
resptransc=${tmppath}"/resptransc_"${ts}".json"
transcpayload=${tmppath}"/payload_"${ts}".json"
transcstart=$(date +'%Y-%m-%dT%H:%M:%SZ')
curl -s -o "${resptransc}" -X POST "${transcurl}" -H 'cache-control: no-cache' --data-binary "@"${mp3path}
transcend=$(date +'%Y-%m-%dT%H:%M:%SZ')
now=$(date +'%Y-%m-%d %H:%M:%S')
echo ${now} "-" ${file} "- Transcribing file done!" >> "${logfile}"
rm -rf "${mp3path}"

now=$(date +'%Y-%m-%d %H:%M:%S')
echo ${now} "-" ${file} "- Inserting transcription of file to Solr" >> "${logfile}"
resptext=$(jq --compact-output .text "${resptransc}")
respparts=$(jq --compact-output .parts "${resptransc}")
respdur=$(jq --raw-output .duration "${resptransc}")
echo '{"type":"radio","filename":"'${file}'","timestart":"'${transcstart}'","timeend":"'${transcend}'","duration":"'${respdur}'","text":'${resptext}',"parts":'${respparts}'}' > ${transcpayload}
curl -s -o /dev/null -H "Content-Type: application/json" -d "@"${transcpayload} "${urlsavetrans}"
# now=$(date +'%Y-%m-%d %H:%M:%S')
# echo ${now} "- Inserting transcription of file" ${file} "to Solr done!" >> "${logfile}"

rm -rf "${resptransc}"
rm -rf "${transcpayload}"

now=$(date +'%Y-%m-%d %H:%M:%S')
echo ${now} "-" ${file} "- Removing file from transcribing" >> "${logfile}"
# #remove from transcribing
delitem=$(jq --compact-output 'del(.[] | select(.file == "'${file}'"))' "${transcribingfile}")
echo "${delitem}" > "${transcribingfile}"
