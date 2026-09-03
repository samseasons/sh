# bash bundle.sh a/a.js a/y.js

base64='$0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz'

resolve() {
    f=$1
    file=$2
    if [[ $f = './'* ]]; then
        f=${f#??}
    fi
    i=${f::1}
    if [[ $i != '.' && $i != '/' ]]; then
        f=${file%'/'*}'/'$f
    elif [[ $f = '../'* ]]; then
        while [[ $f = '../'* ]]; do
            f=${f#???}
            file=${file%'/'*}
        done
        f=${file%'/'*}'/'$f
    fi
    if [[ $f != *'.js' ]]; then
        f+='.js'
    fi
    echo "$f"
}

substitute() {
    text=$1
    past=$2
    next=$3
    a=0
    i=${#past}
    j=${#next}
    while [[ ${text:a} = *"$past"* ]]; do
        b=${text:a}
        b=${b%%$past*}
        a=$((a + ${#b}))
        if [[ ${#text} -lt $((a + i + 1)) ]]; then
            echo "$text"
            return
        fi
        if [[ $base64 = *"${text:a+i:1}"* || ($a -gt 0 && $base64"\"'." = *"${text:a-1:1}"*) ]]; then
            a=$((a + i))
            continue
        fi
        text=${text::a}$next${text:a+i}
        a=$((a + j))
    done
    echo "$text"
}

parse() {
    file=$1
    modules=$2
    texts=$3
    if [[ -e "$file" ]]; then
        text=$(<"$file")
    else
        texts[$file]=''
        return
    fi
    while [[ $text = *$' \n'* ]]; do
        text=${text//$' \n'/$'\n'}
    done
    while [[ $text = *$'\n\n'* ]]; do
        text=${text//$'\n\n'/$'\n'}
    done
    IFS=$'\n' read -d '' -r -a lines <<< "$text"
    remove=false
    text=''
    for line in "${lines[@]}"; do
        if [[ ${line#"${line%%[![:blank:]]*}"} = '//'* ]]; then
            continue
        fi
        if [[ !$remove && $line = *'/*'* && $line != *'//*'* ]]; then
            i=${line%%'*/'*}
            i=${#i}
            if [[ $i -ne ${#line} ]]; then
                line=${line%%'/*'*}' '${line:i+2}
            else
                line=${line%%'/*'*}
                remove=true
            fi
        fi
        if $remove; then
            i=${line%%'*/'*}
            i=${#i}
            if [[ $i -ne ${#line} ]]; then
                line=${line:i+2}
                remove=false
            else
                continue
            fi
        fi
        line=${line%"${line##*[![:blank:]]}"}
        if [[ $line ]]; then
            text+=$line$'\n'
        fi
    done
    texta=$text
    declare -A files=([$file]='')
    order=()
    i=${text%%'import '*}
    i=${#i}
    while [[ $i -ne ${#text} ]]; do
        if [[ $i -ne 0 ]]; then
            j=${text:i-1:1}
            if [[ $j != $'\t' && $j != $'\n' && $j != ' ' ]]; then
                text=${text:i+6}
                i=${text%%'import '*}
                i=${#i}
                continue
            fi
        fi
        i=$((i + 6))
        while [[ ${text:i:1} = ' ' ]]; do
            i=$((i + 1))
        done
        text=${text:i}
        i=${text%%'from'*}
        i=${#i}
        j=${text%%'"'*}
        k=${text%%"'"*}
        names=()
        if [[ $i -lt ${#j} && $i -lt ${#k} ]]; then
            while [[ $i -lt ${#text} ]]; do
                j=${text:i-1:1}
                k=${text:i+4:1}
                if [[ ($j = ' ' || $j = '}') && ($k = ' ' || $k = '"' || $k = "'") ]]; then
                    break
                fi
                i=$((i + 4))
                j=${text:i}
                j=${j%%'from'*}
                i=$((i + ${#j}))
            done
            IFS=' ,{}' read -r -a names <<< "${text::i}"
            i=$((i + 5))
            while [[ ${text:i:1} = ' ' ]]; do
                i=$((i + 1))
            done
        else
            i=0
        fi
        f=${text:i:1}
        if [[ $f = '"' || $f = "'" ]]; then
            text=${text:i+1}
            f=$(resolve "${text%%$f*}" "$file")
            if [[ ! "${order[@]}" =~ "$f" ]]; then
                files[$f]=''
                order+=("$f")
            fi
            for name in "${names[@]}"; do
                files[$f]+=$name$'\n'
            done
        fi
        i=${text%%'import '*}
        i=${#i}
    done
    modules[$file]=''
    for i in "${order[@]}"; do
        modules[$file]+=$i$'\n'
    done
    for i in "${order[@]}"; do
        if [[ ! "${!texts[@]}" =~ "$i" ]]; then
            if [[ ! "${!modules[@]}" =~ "$i" ]]; then
                return
            else
                IFS=$'\n' read -d '' -r -a mods <<< "${modules[$i]}"
                if [[ ! "${mods[@]}" =~ "$file" ]]; then
                    return
                fi
            fi
        fi
    done
    declares=('async' 'class' 'const' 'default' 'function' 'let' 'var')
    defines=($'\n' ' ' '(' ',' '.' '[')
    text=$texta
    i=${text%%'export '*}
    i=${#i}
    while [[ $i -ne ${#text} ]]; do
        text=${text:i+7}
        for name in "${declares[@]}"; do
            i=${text%%$name*}
            i=${#i}
            if [[ $i -ne ${#text} && $i -lt 3 ]]; then
                text=${text:i+${#name}}
            fi
        done
        names=''
        i=${text%%$'\n'*}
        if [[ ${#i} -ne ${#text} ]]; then
            names=$i
        fi
        i=0
        while [[ ${names:i:1} = ' ' ]] do
            i=$((i + 1))
        done
        split=()
        if [[ ${names:i:1} = '{' ]]; then
            names=${names:i+1}
            IFS=',' read -r -a split <<< "${names%%'}'*}"
        else
            i=${names%%'('*}
            i=${#i}
            j=${names%%'='*}
            k=${#j}
            if [[ $k -eq ${#names} || ($i -lt $k && $i -ne ${#names}) ]]; then
                split+=("$names")
            else
                i=$k
                while [[ $i -ne ${#names} && ${names:i+1:1} != '>' ]]; do
                    split+=("$j")
                    names=${names:i}
                    j=${names%%','*}
                    j=${#j}
                    if [[ $j -eq ${#names} ]]; then
                        break
                    fi
                    names=${names:j}
                    j=${names%%'='*}
                    i=${#j}
                done
            fi
        fi
        for name in "${split[@]}"; do
            while [[ "${defines[@]}" =~ ${name::1} ]]; do
                name=${name#?}
            done
            for i in "${defines[@]}"; do
                j=${name%%$i*}
                if [[ ${#j} -ne ${#name} ]]; then
                    name=$j
                fi
            done
            files[$file]+=$name$'\n'
        done
        i=${text%%'export '*}
        i=${#i}
    done
    text=$texta
    for f in "${!files[@]}"; do
        path=${f%???}
        path=$(echo -n $path | tr -c $base64 '_')
        IFS=$'\n' read -d '' -r -a names <<< "${files[$f]}"
        for name in "${names[@]}"; do
            text=$(substitute "$text" "$name" "$name"'_'"$path")
        done
    done
    IFS=$'\n' read -d '' -r -a lines <<< "$text"
    text=''
    for line in "${lines[@]}"; do
        a=${line#"${line%%[![:blank:]]*}"}
        if [[ $a = 'export default '* ]]; then
            line=${a:15}
        elif [[ $a = 'export '* ]]; then
            line=${a:7}
            a=${line#"${line%%[![:blank:]]*}"}
            if [[ ${a::1} = '{' ]]; then
                continue
            fi
        fi
        if [[ $line && $a != 'import '* ]]; then
            text+=$line$'\n'
        fi
    done
    texts[$file]=$text
}

build() {
    file=${1:-a/a.js}
    output=${2:-a/y.js}
    imported=()
    imports=("$file")
    declare -A modules
    declare -A texts
    while [[ ${#imports[@]} -ne 0 ]]; do
        file=${imports[0]}
        if [[ "${imported[@]}" =~ "$file" ]]; then
            imports=("${imports[@]:1}")
        else
            parse "$file" "${modules[@]}" "${texts[@]}"
            IFS=$'\n' read -d '' -r -a mods <<< "${modules[$file]}"
            imports=("${mods[@]}" "${imports[@]}")
            if [[ "${!texts[@]}" =~ "$file" ]]; then
                imported+=("$file")
            fi
        fi
    done
    text=''
    for file in "${imported[@]}"; do
        text+=${texts[$file]}
    done
    echo -n "$text" > "$output"
}

build "$1" "$2"