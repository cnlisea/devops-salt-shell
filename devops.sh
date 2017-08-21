#!/bin/bash
# auth release or rollback application service files for ECS application server
# by authors lisea 2017-02-08 Eamil: cnlisea@126.com
# error code  
#   1: not Usage argument 
#   2: filename not exist 
#   3: backup directory not exist
#   4: salt directory not exist
#   5: rollback flag error

backup_dir='/mnt/cmbcs-release-data'
backup_prefix='cmbcs-api-'
backup_postfix='.tgz'
filename=devops.tar.gz

salt_target='cmbcs-app-node*'
salt_dir='/srv/salt/release/files'
salt_env='release'
salt_server_name='cmbcs'

release() {
  [ -d ${backup_dir} ] || exit 3
  [ -d ${salt_dir} ] || exit 4
  if [ ! -f $1 ]; then
    retval=2
    echo -e "\033[32m$1 file not exist! code ${retval}\033[0m"
    exit ${retval}
  fi
  # backup
  cp $1  ${backup_dir}/${backup_prefix}`date +%Y%m%d%H%M%S`${backup_postfix}

  salt_exec $1 && return 0
}

rollback() {
  flag=1
  [ -d ${backup_dir} ] || exit 3
  [ -d ${salt_dir} ] || exit 4
  [ -z $1 ] || flag=$1 
  # flag range judge [0,3]
  backup_num=`ls -l ${backup_dir} | grep ${backup_prefix}| wc -l`
  if [ ${backup_prefix} -le ${flag} -o 0 -ge ${flag} ]; then
    echo -e "\033[32mUsage: $0 rollback {1|2|3}, default 1\033[0m"
    exit 5
  fi

  # Access to rollback the version of the file name
  #rollbackfile=`ls -lr ${backup_dir} | sed -n '3p' | awk '{print $NF}'`
  rollbackfile=`ls -l ${backup_dir} | grep ${backup_prefix} | awk '{print $NF}' | sed -r "s/^${backup_prefix}([0-9]+)${backup_postfix}$/\1/g" | sort -r | sed -nr "$[$flag+1]s/^(.*)$/${backup_prefix}\1${backup_postfix}/gp"`
  echo "rollbackfile: ${rollbackfile}"
  
  # get a line on the released version file name
  removefile=`ls -l ${backup_dir} | grep cmbcs-api | awk '{print $NF}' | sed -r "s/^${backup_prefix}([0-9]+)${backup_postfix}$/\1/g" | sort -r | sed -nr "1s/^(.*)$/${backup_prefix}\1${backup_postfix}/gp"`
  echo "removefile: ${removefile}"
  # Delete a line on the released version
  rm -f ${backup_dir}/${removefile} 
  salt_exec ${backup_dir}/${rollbackfile} && return 0
}

# saltstack cmd exec
salt_exec() {
  if [ -f ${salt_dir}/${filename} ];then
     rm -f ${salt_dir}/${filename}
  fi
  # copy file for salt directory
  cp $1  ${salt_dir}/${filename}
  # exec salt
  salt "${salt_target}" state.highstate env=${salt_env} && return 0
}

start() {
  salt "${salt_target}" supervisord.start ${salt_server_name} && return 0
}

restart() {
  salt "${salt_target}" supervisord.restart ${salt_server_name} && return 0
}

stop() {
  salt "${salt_target}" supervisord.stop ${salt_server_name} && return 0
}

status() {
  salt "${salt_target}" supervisord.status ${salt_server_name} && return 0
}

logs() {
  salt "${salt_target}" cmd.run "cat /data/go_work/src/cmbcs/logs/cmbcs.log | grep -v nomatch"
}

#logs() {
#  salt "${salt_target}" cmd.run "cat /data/go_work/src/cmbcs/logs/cmbcs.log"
#}

version() {
  salt "${salt_target}" cmd.run "cat /data/go_work/src/cmbcs/conf/app.conf | grep ServerName"
}

case "$1" in
  release)
    release $2 && exit 0
    $1
    ;;
  rollback)
    rollback $2 && exit 0
    $1
    ;;
  start)
    start && exit 0
    $1
    ;;
  restart)
    restart && exit 0
    $1
    ;;
  stop)
    stop && exit 0
    $1
    ;;
  status)
    status && exit 0
    $1
    ;;
  logs)
    logs && exit 0
    $1
    ;;
  version)
    version && exit 0
    $1
    ;;
  *)
    echo $"Usage: $0 {release|rollback|start|restart|status}"
    exit 1
esac
