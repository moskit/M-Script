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
possible_options="cluster help"
necessary_options=""
#[ "X$*" == "X" ] && echo "Can't run without options. Possible options are: ${possible_options}" && exit 1
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

for var in APP_SERVERS NGINX_PROXY_CLUSTER_CONF_DIR NGINX_RC_SCRIPT NGINX_RELOAD_COMMAND ; do
  [ -z "`eval echo \\$\$var`" ] && echo "$var is not defined! Define it in conf/cloud.conf please." && exit 1
done
PATH="${EC2_TOOLS_BIN_PATH}:${PATH}"
export JAVA_HOME EC2_HOME EC2_PRIVATE_KEY EC2_CERT EC2_REGION PATH

TMPDIR=/tmp/m_script/cloud
install -d $TMPDIR
install -d $NGINX_PROXY_CLUSTER_CONF_DIR

if [ -z "$cluster" ] ; then
  CLUSTERS=`for CLUSTER in $APP_SERVERS; do names="${names}\n${CLUSTER%:*}"; done; printf "$names" | sort | uniq` ; CLUSTERS=`echo $CLUSTERS`
else
  CLUSTERS="$cluster"
fi
changed=0
for cluster in "$CLUSTERS" ; do
  cluster=${cluster#* }; cluster=${cluster% *}
  for CLUSTER in $APP_SERVERS; do
    if [ "X${CLUSTER%:*}" == "X$cluster" ] ; then
      ports="$ports ${CLUSTER#*:}"
    fi
  done
  [ -f $TMPDIR/${cluster}.servers.ips ] && mv $TMPDIR/${cluster}.servers.ips $TMPDIR/${cluster}.servers.ips.prev || ${rpath}/update_servers_list.sh
  for IP in `cat $TMPDIR/ec2.servers.ips | awk -F'|' '{print $1" "$14}' | grep "$cluster" | awk '{print $1}'` ; do
    for PORT in $ports ; do
      PORT=${PORT#* }; PORT=${PORT% *}
      echo "$IP:$PORT" >> $TMPDIR/${cluster}.servers.ips
    done
  done
  [ -f $TMPDIR/${cluster}.servers.ips.prev ] && [ -f $TMPDIR/${cluster}.servers.ips ] && [ -z "`$DIFF -q $TMPDIR/${cluster}.servers.ips.prev $TMPDIR/${cluster}.servers.ips`" ] && continue
  if [ `cat $TMPDIR/${cluster}.servers.ips | grep -v ^$ | wc -l` -gt 0 ] ; then
    changed=1
    echo "upstream $cluster {" > $NGINX_PROXY_CLUSTER_CONF_DIR/${cluster}.conf
    echo "  ip_hash;" >> $NGINX_PROXY_CLUSTER_CONF_DIR/${cluster}.conf
    while read IP; do
      echo "  server ${IP};" >> $NGINX_PROXY_CLUSTER_CONF_DIR/${cluster}.conf
    done<$TMPDIR/${cluster}.servers.ips
    echo "}">> $NGINX_PROXY_CLUSTER_CONF_DIR/${cluster}.conf
  else
    echo "IP list is empty! Exiting.." >> ${rpath}/../cloud.log
    exit 1
  fi
done

[ "X$changed" == "X1" ] && $NGINX_RC_SCRIPT $NGINX_RELOAD_COMMAND || exit 0

