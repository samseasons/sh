# bash serve.sh a 1234

declare -A types=(
    ['css']='text/css'
    ['html']='text/html'
    ['ico']='image/x-icon'
    ['js']='application/javascript'
)

prepare() {
    folder=$1
    line=($2)
    file="${line[1]//'%20'/' '}"
    if [[ $file != '/'* || $file = '/' ]]; then
        file='/x.html'
        type='text/html'
    else
        type=${types[${file##*.}]}
    fi
    if [[ -e "$folder$file" ]]; then
        echo $'HTTP/1.\ncontent-type:'$type$'\n\n'"$(tr -d '\0' < "$folder$file")"
    fi
}

preparea() {
    folder=$1
    read line
    echo "$(prepare "$folder" "$line")"
}

prepareb() {
    folder=$1
    port=$2
    while read line; do
        if [[ $line = 'GET /'* ]]; then
            : $(echo "$(prepare "$folder" "$line")" | netcat -l -w 0 $port)
        fi
    done
}

serve() {
    folder=${1:-a}
    port=${2:-1234}
    if test "$(type -t socat)"; then
        echo 'localhost:'$port
        : $(socat tcp-l:$port,fork,reuseaddr exec:"$SHELL ${BASH_SOURCE[0]} \'$folder\' $port a" 2>&1)
    elif test "$(type -t netcat)"; then
        echo 'localhost:'$port
        netcat -6 -k -l -w 1 $port | $SHELL ${BASH_SOURCE[0]} "$folder" $port b
    else
        echo 'no'
    fi
}

case $3 in
    (a) preparea "${@}" ;;
    (b) prepareb "${@}" ;;
    (*) serve "${@}" ;;
esac