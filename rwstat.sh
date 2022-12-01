#!/bin/bash

if [[ $# < 1 ]] ; then
    echo "Erro, indique o número de segundos que serão usados para calcular as taxas de I/O." >&2
    exit 1
fi

if ! [[ "${@: -1}" =~ ^[0-9]+$ && ${@: -1} > 0 ]]; then  # verificar se o ultimo argumento é um int
    echo "O último argumento tem de ser um inteiro positivo." >&2
    exit 1
fi

regex='.*'
user_regex='.*'
column=4                      # coluna para dar sort  
reverse=1                     # 1 -> sort de menor para maior | 0 -> sort de maior para menor
minimum_date=0
maximum_date=$(( (2**63)-1 )) # maior int
minimum_pid=0
maximum_pid=$(( (2**63)-1 ))  # maior int
lines=$(($(ls -v /proc/ | grep '[0-9]' | wc -l) * 2))

while getopts ":wrc:u:p:s:e:m:M:" options; do
  case "${options}" in
    w)
      column=7
      if [[ $reverse -eq 1 ]];then   # temos de dar reverse no -w pois o $reverse é 1 by default
        reverse=0
      else
        reverse=1
      fi
      ;;
    r)
      if [[ $reverse -eq 1 ]];then
        reverse=0
      else
        reverse=1
      fi
      ;;
    c) 
      regex=${OPTARG}
      ;;
    u)
      user_regex=${OPTARG}
      ;;
    p)
      lines=${OPTARG}
      ;;
    s)
      minimum_date=$(date -d "${OPTARG}" +%s)
      ;;
    e)
      maximum_date=$(date -d "${OPTARG}" +%s)
      ;;
    m)
      minimum_pid=${OPTARG}
      ;;
    M)
      maximum_pid=${OPTARG}
      ;;
    ?) 
          echo -e "Opção inválida.\nUSO: sudo $0 [-w] [-r] [-c \"regex\"] [-u \"regex\"] [-p numproc] \
[-s datamin] [-e datamax] [-m pidmin] [-M pidmax] nsec" >&2
          exit 1
          ;;
esac
done

for pid in $(ls -v /proc/ | grep '[0-9]')
do

    if ! [[ -d "/proc/$pid" ]]; then
        continue    
    fi
    
    rchar_before[$pid]=$(cat /proc/$pid/io | sed -n 1p | awk '{print $2}')
    wchar_before[$pid]=$(cat /proc/$pid/io | sed -n 2p | awk '{print $2}')

done

sleep ${@: -1}  # último argumento

for pid in $(ls -v /proc/ | grep '[0-9]')
do

    if ! [[ -d "/proc/$pid" ]]; then
        continue    
    fi

    user=$(ls -l /proc/$pid/io | awk '{print $3}')
    date=$(ls -l /proc/$pid/io | awk '{print $6,$7,$8}')
    date_seconds=$(date +%s -d "$date")
    name=$(cat /proc/$pid/comm )

    rchar_after=$(cat /proc/$pid/io | sed -n 1p | awk '{print $2}')
    wchar_after=$(cat /proc/$pid/io | sed -n 2p | awk '{print $2}')    
    rchar=$((rchar_after-rchar_before[$pid]))
    wchar=$((wchar_after-wchar_before[$pid]))
    
    if [[ $name =~ $regex && $user =~ $user_regex && $date_seconds -ge $minimum_date && $date_seconds -le $maximum_date && $pid -ge $minimum_pid && $pid -le $maximum_pid ]];then  
      format+="\n$(echo -e "$name;$user;$pid;$rchar;$wchar;$(awk "BEGIN {print $rchar/${@: -1}}");$(awk "BEGIN {print $wchar/${@: -1}}");$date")"
    fi
done

if [[ $reverse -eq 1 ]];then
  format=$(echo -e "$format" | sort -n -t ";" -k $column,$column)
else
  format=$(echo -e "$format" | sort -nr -t ";" -k $column,$column)
fi

echo -e "COMM;USER;PID;READB;WRITEB;RATER;RATEW;DATE$format" | head -n $(($lines+1)) | column -s ";" -t
