# bash bundle.sh a/a.js a/y.js

base64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789$_'

parse() {
    file=$1
    imported=$!2
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
        if [[ ${line#${line%%[! ]*}} = '//'* ]]; then
            continue
        fi
        if [[ !$remove && $line = *'/*'* && $line != *'//*'* ]]; then
            if [[ $line = *'*/'* ]]; then
                i=${line%%'*/'*}
                line=${line%%'/*'*}' '${line:${#i}+2}
            else
                line=${line%%'/*'*}
                remove=true
            fi
        fi
        if $remove; then
            if [[ $line = *'*/'* ]]; then
                i=${line%%'*/'*}
                line=${line:${#i}+2}
                remove=false
            else
                continue
            fi
        fi
        line=${line%${line%%[! ]*}}
        if [[ $line ]]; then
            text+=$line$'\n'
        fi
    done
    texta=$text

    resolve() {
        f=$1
        if [[ ${f::2} = './' ]]; then
            f=${f:2}
        fi
        if [[ ${f::1} != '.' && ${f::1} != '/' ]]; then
            IFS='/' read -r -a split <<< "$file"
            split=${split[@]::${#split[@]}-1}
            i=''
            for j in $split; do
                i+=$j'/'
            done
            f=$i$f
        elif [[ $f = '../'* ]]; then
            i=0
            while [[ $f = '../'* ]]; do
                f=${f:3}
                i=$((i + 1))
            done
            IFS='/' read -r -a split <<< "$file"
            split=${split[@]::${#split[@]}-i-1}
            i=''
            for j in $split; do
            	i+=$j'/'
            done
            f=$i$f
        fi
        if [[ ${f:${#f}-3} != '.js' ]]; then
            f+='.js'
        fi
        echo "$f"
    }

    declare -A files=([$file]='')
    order=()
    i=${text%%'import '*}
    i=${#i}
    [ $i = ${#text} ] && i=-1
    while [[ $i -ne -1 ]]; do
        if [[ $i -ne 0 && ${text:i-1:1} != $'\n' && ${text:i-1:1} != ' ' ]]; then
            text=${text:i+6}
            i=${text%%'import '*}
            i=${#i}
            [ $i = ${#text} ] && i=-1
            continue
        fi
        i=$((i + 6))
        while [[ ${text:i:1} = ' ' ]]; do
            i=$((i + 1))
        done
        text=${text:i}
        i=${text%%'from'*}
        i=${#i}
        j=${text%%"'"*}
        k=${text%%'"'*}
        names=()
        if [[ $i -lt ${#j} && $i -lt ${#k} ]]; then
            while [[ $i -lt ${#text} ]]; do
                j=${text:i-1:1}
                k=${text:i+4:1}
                if [[ ($j = ' ' || $j = '}') && ($k = ' ' || $k = "'" || $k = '"') ]]; then
                    break
                fi
                i=$((i + 4))
                j=${text:i}
                j=${j%%'from'*}
                i=$((i + ${#j}))
            done
            IFS=' ,{}' read -ra names <<< "${text::i}"
            i=$((i + 5))
            while [[ ${text:i:1} = ' ' ]]; do
                i=$((i + 1))
            done
        else
            i=0
        fi
        f=${text:i:1}
        if [[ $f = "'" || $f = '"' ]]; then
            text=${text:i+1}
            f=$(resolve "${text%%$f*}")
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
        [ $i = ${#text} ] && i=-1
    done
    modules[$file]=''
    for i in "${order[@]}"; do
        modules[$file]+=$i$'\n'
    done
    for i in "${order[@]}"; do
        if [[ ! "${imported[@]}" =~ "$i" ]]; then
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
    exporta=('async' 'class' 'const' 'default' 'function' 'let' 'var')
    repeata=($'\n' ' ' '(' ',' '.' '[')
    text=$texta
    i=${text%%'export '*}
    i=${#i}
    [ $i = ${#text} ] && i=-1
    while [[ $i -ne -1 ]]; do
        text=${text:i+7}
        for name in "${exporta[@]}"; do
            i=${text%%$name*}
            i=${#i}
            [ $i = ${#text} ] && i=-1
            if [[ $i -ne -1 && $i -lt 3 ]]; then
                text=${text:i+${#name}}
            fi
        done
        names=''
        if [[ $text = *$'\n'* ]]; then
            names=${text%%$'\n'*}
        fi
        i=0
        while [[ ${names:i:1} = ' ' ]] do
            i=$((i + 1))
        done
        if [[ ${names:i:1} = '{' ]]; then
            names=${names:i+1}
            IFS=',' read -r -a split <<< "${names%%'}'*}"
        else
            split=()
            i=${names%%'='*}
            i=${#i}
            j=${names%%'('*}
            j=${#j}
            if [[ $i == ${#names} || ($j != ${#names} && $i -gt $j) ]]; then
                split+=("$names")
            else
                while [[ $names = *'='* ]]; do
                    i=${names%%'='*}
                    split+=("$i")
                    i=${#i}
                    names=${names:i}
                    if [[ $names = *','* ]]; then
                        i=${names%%','*}
                        names=${names:${#i}}
                    else
                        break
                    fi
                done
            fi
        fi
        for name in "${split[@]}"; do
            while [[ "${repeata[@]}" =~ ${name::1} ]]; do
                name=${name:1}
            done
            for i in "${repeata[@]}"; do
                if [[ $name = *"$i"* ]]; then
                    name=${name%%$i*}
                fi
            done
            files[$file]+=$name$'\n'
        done
        i=${text%%'export '*}
        i=${#i}
        [ $i = ${#text} ] && i=-1
    done

    replace() {
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
            cont=false
            textb=${text:a-7:7}$next
            for name in "${exporta[@]}"; do
                if [[ $textb = *"$name"'_'* ]]; then
                    cont=true
                    break
                fi
            done
            if [[ $cont = true || $base64 = *"${text:a+i:1}"* || $base64"'." = *"${text:a-1:1}"* ]]; then
                a=$((a + i))
                continue
            fi
            text=${text::a}$next${text:a+i}
            a=$((a + j))
        done
        echo "$text"
    }

    text=$texta
    for f in "${!files[@]}"; do
        string=${f::-3}
        string=$(echo -n $string | tr -c $base64 '_')
        IFS=$'\n' read -d '' -r -a ref <<< "${files[$f]}"
        for name in "${ref[@]}"; do
            text=$(replace "$text" "$name" "$name"'_'"$string")
        done
    done
    IFS=$'\n' read -d '' -r -a lines <<< "$text"
    text=''
    for line in "${lines[@]}"; do
        a=${line#${line%%[! ]*}}
        if [[ $a = 'export default '* ]]; then
            line=${a:15}
        elif [[ $a = 'export '* ]]; then
            line=${a:7}
            a=${line#${line%%[! ]*}}
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
            parse "$file" "${imported[@]}"
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