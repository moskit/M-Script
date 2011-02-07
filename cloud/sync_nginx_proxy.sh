#!/usr/bin/env bash
# Copyright (C) 2008-2011 Igor Simonov (me@igorsimonov.com)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


rcommand=${0##*/}
rpath=${0%/*}
#*/ (this is needed to fix vi syntax highlighting)
DIFF=`which diff 2>/dev/null`
[ -z "$DIFF" ] && echo "Diff utility not found, exiting" && exit 1
possible_options="cluster"
necessary_options=""
[ "X$*" == "X" ] && echo "Can't run without options. Possible options are: ${possible_options}" && exit 1
for s_option in "${@}"
do
  found=0
  case ${s_option} in
  --*=*)
    s_optname=`expr "X$s_option" : 'X[^-]*-*\([^=]*\)'`  
    s_optarg=`expr "X$s_option" : 'X[^=]*=\(.*\)'` 
    ;;
  --*)
    s_optname=`expr "X$s_option" : 'X[^-]*-*\([^=]*\)'`    
    s_optarg='yes' 
    ;;
  *=*)
    echo "Wrong syntax: options must start with a double dash"
    exit 1
    ;;
  *)
    s_param=${s_option}
    s_optname=''
    s_optarg=''
    ;;
  esac
  for option in `echo $possible_options | sed 's/,//g'`; do 
    [ "X$s_optname" == "X$option" ] && eval "$option=${s_optarg}" && found=1
  done
  [ "X$s_option" == "X$s_param" ] && found=1
  if [[ found -ne 1 ]]; then 
    echo "Unknown option: $s_optname"
    exit 1
  fi
done
if [ "X$help" == "Xyes" ] ; then
  echo "Usage: ${0##*/} <options>"
  echo 
  echo "Without options all clusters defined in conf/cloud.conf will be synced"
  echo
  echo "Options:"
  echo
  echo "  --cluster=clustername    - syncs only this single cluster."
  echo "                             No port number allowed here! Port(s) will"
  echo "                             be taken from conf/cloud.conf"
  exit 0
fi
found=0

for option in `echo $necessary_options | sed 's/,//g'`; do
  [ "X$(eval echo \$$option)" == "X" ] && missing_options="${missing_options}, --${option}" && found=1
done
if [[ found -eq 1 ]]; then
  missing_options=${missing_options#*,}
  echo "Necessary options: ${missing_options} not found"
  exit 1
fi

source ${rpath}/../conf/cloud.conf
PATH="${EC2_TOOLS_BIN_PATH}:${PATH}"
TMPDIR=/tmp/m_script/cloud
install -d $TMPDIR
install -d $NGINX_PROXY_CLUSTER_CONF_DIR
if [ -z "$cluster" ] ; then
  CLUSTERS=`for CLUSTER in $APP_SERVERS; do names="${names}\n${CLUSTER%:*}"; done; printf "$names" | sort | uniq`
fi

for cluster in "$cluster $CLUSTERS" ; do
  for CLUSTER in $APP_SERVERS; do
    if [ "X${CLUSTER%:*}" == "X$cluster" ] ; then
      ports="$ports ${CLUSTER#*:}"
    fi
  done
  mv $TMPDIR/${cluster}.servers.ips $TMPDIR/${cluster}.servers.ips.prev
  for IP in `ec2-describe-instances -F "cluster=$cluster" --show-empty-fields --region $EC2_REGION | grep '^INSTANCE' | awk '{print $18}'` ; do
    for PORT in $ports ; do
      echo "$IP:$PORT" >> $TMPDIR/${cluster}.servers.ips
    done
  done
  [ -z `$DIFF $TMPDIR/${cluster}.servers.ips.prev $TMPDIR/${cluster}.servers.ips` ] && continue
  
  echo "upstream $cluster {" > $NGINX_PROXY_CLUSTER_CONF_DIR/${cluster}.conf
  echo "  ip_hash;" >> $NGINX_PROXY_CLUSTER_CONF_DIR/${cluster}.conf
  while read IP; do
    echo "  server ${IP};" >> $NGINX_PROXY_CLUSTER_CONF_DIR/${cluster}.conf
  done<$TMPDIR/${cluster}.servers.ips
  echo "}">> $NGINX_PROXY_CLUSTER_CONF_DIR/${cluster}.conf
done


