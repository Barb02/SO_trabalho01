#!/bin/bash

function check_arg_is_num(){      
    if ! [[ $1 =~ ^[0-9]+$ && $1 -gt 0 ]] ; then   # verificar se o argumento é válido
      echo "Erro. Argumento deve ser um número inteiro positivo." >&2
      exit 1
    fi
}

if [[ $# -lt 1 ]] ; then
    echo "Erro. Indique o número de segundos que serão usados para calcular as taxas de I/O." >&2
    exit 1
fi

if ! [[ ${@: -1} =~ ^[0-9]+$ && ${@: -1} -gt 0 ]]; then  # verificar se o ultimo argumento é válido
    echo "Erro. O último argumento tem de ser um inteiro positivo." >&2
    exit 1
fi

regex='.*'
user_regex='.*'
column=6                      # coluna para dar sort  
reverse=1                     
minimum_date=0
maximum_date=$(( (2**63)-1 )) # maior int
minimum_pid=0
maximum_pid=$(( (2**63)-1 ))  # maior int
lines=$(($(ls /proc/ | grep '[0-9]' | wc -l) * 2))  # multiplica por 2 pois mais processos podem ser criados entre esse ls e o próximo

while getopts ":wrc:u:p:s:e:m:M:" options; do
  case "${options}" in
    w)
      column=7
      ;;
    r)
      reverse=0
      ;;
    c) 
      regex=${OPTARG}
      ;;
    u)
      user_regex=${OPTARG}
      ;;
    p)
      lines=${OPTARG}
      check_arg_is_num $lines
      ;;
    s)
      minimum_date=$(date -d "${OPTARG}" +%s)
      if [[ $? == 1 ]]; then 
        exit 1
      fi
      ;;
    e)
      maximum_date=$(date -d "${OPTARG}" +%s)
      if [[ $? == 1 ]]; then 
        exit 1
      fi
      ;;
    m)
      minimum_pid=${OPTARG}
      check_arg_is_num $minimum_pid
      ;;
    M)
      maximum_pid=${OPTARG}
      check_arg_is_num $maximum_pid
      ;;
    ?) 
          echo -e "Opção inválida.\nUSO: sudo $0 [-w] [-r] [-c \"regex\"] [-u \"regex\"] [-p numproc] \
[-s datamin] [-e datamax] [-m pidmin] [-M pidmax] nsec" >&2
          exit 1
          ;;
  esac
done

if [[ ${OPTIND} != $# ]] ; then
    echo "Erro, faltam argumentos." >&2
    exit 1
fi

for pid in $(ls /proc/ | grep '[0-9]')
do

    if ! [[ -d "/proc/$pid" ]]; then
        continue    
    fi

    rbf=$(cat /proc/$pid/io 2>/dev/null)
    if [[ $? == 1 ]]; then 
        continue
    fi
    
    rchar_before[$pid]=$(echo $rbf | sed -n 1p | awk '{print $2}')
    wchar_before[$pid]=$(cat /proc/$pid/io | sed -n 2p | awk '{print $2}')

done

sleep ${@: -1}  # último argumento

for pid in ${!rchar_before[@]}
do
    if ! [[ -d "/proc/$pid" ]]; then
        continue    
    fi

    user=$(ls -l /proc/$pid/io | awk '{print $3}')
    date=$(ps -p $pid -o lstart | tail -n1 | awk '{print $2,$3,substr($4,1,5)}')
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
  format=$(echo -e "$format" | sort -gr -t ";" -k $column,$column)
  echo -e "COMM;USER;PID;READB;WRITEB;RATER;RATEW;DATE\n$format" | head -n $(($lines+1)) | column -s ";" -t
else
  format=$(echo -e "$format" | sort -g -t ";" -k $column,$column)
  echo -e "COMM;USER;PID;READB;WRITEB;RATER;RATEW;DATE$format" | head -n $(($lines+1)) | column -s ";" -t
fi