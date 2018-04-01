#!/bin/bash

# ----------------------------- kiwi bash lib start -------------------------------------

# Make sure to execute this script with bash. Bash works well on suse, redhat, aix.##
# 确保以bash执行此脚本。Bash在suse、redhat、aix上表现很出色。##
[ -z "$BASH" ] && echo "Please use bash to run this script [ bash $0 ] or make sure the first line of this script [ $0 ] is [ #!/bin/bash ]." && exit 1

# Set the bash debug info style to pretty format. +[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
# 设置bash的调试信息为漂亮的格式。+[T: <Time>, L: <LineNumber>, S: <ScriptName>, F: <Function>]##
[ -c /dev/stdout ] && export PS4_COLOR="32"
[ ! -c /dev/stdout ] && export PS4_COLOR=""
export PS4='+[$(debug_info=$(printf "T: %s, L:%3s, S: %s, F: %s" "$(date +%H%M%S)" "$LINENO" "$(basename $(cd $(dirname ${BASH_SOURCE[0]}) && pwd))/$(basename ${BASH_SOURCE[0]})" "$(for ((i=${#FUNCNAME[*]}-1; i>=0; i--)) do func_stack="$func_stack ${FUNCNAME[i]}"; done; echo $func_stack)") ; [ -z "$PS4_COLOR" ] && echo ${debug_info:0:94} ; [ -n "$PS4_COLOR" ] && echo -e "\e[${PS4_COLOR}m${debug_info:0:80}\e[0m")]: '

# 保存调试状态，用于调用子脚本。调用子脚本样例：bash $DEBUG_SWITCH subscript.sh##
# Save the debug state to invoke the subscript. Invoke the subscript example: bash $DEBUG_SWITCH subscript.sh##
(echo "${SHELLOPTS}" | grep -q "xtrace") && export DEBUG_SWITCH=-x

# Get the absolute path of this script.##
# 获取脚本的绝对路径。##
BASE_DIR=$(cd $(dirname $0) && pwd)
BASE_NAME=$(basename $0 .sh)

# 设置日志文件。##
# Set the log file.##
log=$BASE_DIR/$BASE_NAME.log

function print_error()
{
    echo "[$(date "+%F %T")] ERROR: $*" | tee -a $log 1>&2
}

function print_info()
{
    echo "[$(date "+%F %T")] INFO: $*" | tee -a $log
}

function log_error()
{
    [ -n "$log" ] && echo "[$(date "+%F %T")] ERROR: $*" >>$log
}

function log_info()
{
    [ -n "$log" ] && echo "[$(date "+%F %T")] INFO: $*" >>$log
}

function die()
{
    print_error "$*"
    print_error "See log [ $log ] for details."
    exit 1
}

# ----------------------------- kiwi bash lib end ---------------------------------------

[ $# -eq 0 ] && echo "Usage: sh $0 <path...>" && exit 1

# 搜索路径，多个路径以空格分开，支持环境变量##
# search_path="/home/app1 ${APP2_HOME}"##
search_path="$@"

# 旧包目录存在且不为空，备份此目录##
[ -d "$BASE_DIR/old" ] && [ -n "$(ls -A $BASE_DIR/old)" ] && mv $BASE_DIR/old $BASE_DIR/old_$(date +%Y%m%d%H%M%S)

mkdir -p $BASE_DIR/new
mkdir -p $BASE_DIR/old

>$BASE_DIR/new_jar_path.txt
>$BASE_DIR/new_war_path.txt
>$BASE_DIR/old_jar_path.txt
>$BASE_DIR/old_war_packed_path.txt
>$BASE_DIR/old_war_unpacked_path.txt

find $BASE_DIR/new -type f -name "*.jar" >$BASE_DIR/new_jar_path.txt
find $BASE_DIR/new -type f -name "*.war" >$BASE_DIR/new_war_path.txt

# 处理jar包##
while read new_jar_path
do
    # 为了让如下的两个包能够匹配，需要对版本标记进行预处理，使用通配符搜索##
    # com.xdc.soft-1.0.0-SNAPSHOT.jar##
    # com.xdc.soft-1.0.0-20160314.123852-178.jar##

    new_jar_name=$(basename $new_jar_path)
    new_jar_name_wildcard=$(echo $new_jar_name | sed 's/-SNAPSHOT.jar/-*.jar/')
    new_jar_name_wildcard=$(echo $new_jar_name_wildcard | sed 's/-[0-9]*.[0-9]*-[0-9]*.jar/-*.jar/')

    find_jar_para="$find_jar_para -o -type f -name $new_jar_name_wildcard"
done <$BASE_DIR/new_jar_path.txt

if [ -n "$find_jar_para" ]; then
    find_jar_cmd="find $search_path ${find_jar_para#*-o}"
    $find_jar_cmd >$BASE_DIR/old_jar_path.txt

    # 替换jar包##
    while read new_jar_path
    do
        new_jar_name=$(basename $new_jar_path)
        new_jar_name_wildcard=$(echo $new_jar_name | sed 's/-SNAPSHOT.jar/-*.jar/')
        new_jar_name_wildcard=$(echo $new_jar_name_wildcard | sed 's/-[0-9]*.[0-9]*-[0-9]*.jar/-*.jar/')

        echo "-----------------------------------------------------------------------"
        echo "Handling $new_jar_name"
        echo "-----------------------------------------------------------------------"
        while read old_jar_path
        do
            old_jar_name=$(basename $old_jar_path)
            old_jar_name_wildcard=$(echo $old_jar_name | sed 's/-SNAPSHOT.jar/-*.jar/')
            old_jar_name_wildcard=$(echo $old_jar_name_wildcard | sed 's/-[0-9]*.[0-9]*-[0-9]*.jar/-*.jar/')

            if [ "${new_jar_name_wildcard}" = "${old_jar_name_wildcard}" ]; then
                echo "replace to: $old_jar_path"
                cp $old_jar_path $BASE_DIR/old/$old_jar_name
                cp $new_jar_path $old_jar_path
            fi
        done <$BASE_DIR/old_jar_path.txt
        echo
    done <$BASE_DIR/new_jar_path.txt
fi

# 处理war包##
while read new_war_path
do
    new_war_name=$(basename $new_war_path)
    find_war_packed_para="$find_war_packed_para -o -type f -name $new_war_name"
    find_war_unpacked_para="$find_war_unpacked_para -o -type d -name ${new_war_name%.*}"
done <${BASE_DIR}/new_war_path.txt

if [ -n "$find_war_packed_para" -a -n "$find_war_unpacked_para" ]; then
    find_war_packed_cmd="find $search_path ${find_war_packed_para#*-o}"
    $find_war_packed_cmd >$BASE_DIR/old_war_packed_path.txt

    find_war_unpacked_cmd="find $search_path ${find_war_unpacked_para#*-o}"
    $find_war_unpacked_cmd >$BASE_DIR/old_war_unpacked_path.txt

    while read new_war_path
    do
        new_war_name=$(basename $new_war_path)
        echo "-----------------------------------------------------------------------"
        echo "Handling $new_war_name"
        echo "-----------------------------------------------------------------------"

        # 替换压缩的war包##
        while read old_war_packed_path
        do
            old_war_packed_name=$(basename $old_war_packed_path)
            if [ "$old_war_packed_name" = "$new_war_name" ]; then
                echo "replace to: $old_war_packed_path"
                cp $old_war_packed_path $BASE_DIR/old/$new_war_name
                cp $new_war_path $old_war_packed_path
            fi
        done <$BASE_DIR/old_war_packed_path.txt

        # 替换解压缩的war包##
        while read old_war_unpacked_path
        do
            old_war_unpacked_name=$(basename $old_war_unpacked_path)
            if [ "$old_war_unpacked_name" = "${new_war_name%.war}" ]; then
                echo "replace to: ${old_war_unpacked_path}"
                user=$(ls -l -d $old_war_unpacked_path | awk '{print $3}')
                group=$(ls -l -d $old_war_unpacked_path | awk '{print $4}')

                $(cd $old_war_unpacked_path && zip -qr $BASE_DIR/old/$new_war_name ./ && rm -rf $old_war_unpacked_path)
                unzip -qo $new_war_path -d $old_war_unpacked_path
                chmod -R 770 $old_war_unpacked_path
                chown -R $user:$group $old_war_unpacked_path
            fi
        done <$BASE_DIR/old_war_unpacked_path.txt
        echo
    done <$BASE_DIR/new_war_path.txt
fi
