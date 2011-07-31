#!/bin/bash
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
IFS1=$IFS
IFS='
'
echo ""
echo "Running services"
echo "----------------"
echo ""

for LINE in `cat "${rpath}/../conf/services.conf"|grep -v ^$|grep -v ^#|grep -v ^[[:space:]]*#` ; do
  LINE=`echo "$LINE" | sed 's|[[:space:]]*$||'`
  thepath=`echo "$LINE" | sed 's|[[:space:]]*recursive||'`
  if [ -d "$thepath" ] ; then
    if [[ "$LINE" =~ [[:space:]]*recursive$ ]] ; then
      find "$thepath" -name "*\.pid" | while read pidfile ; do
        pid=`cat "$pidfile"|sed 's|\r||'`
        if [ -f "/proc/$pid/comm" ] ; then
          pcomm=`cat /proc/$pid/comm`
          printf "$pcomm"
          m=`expr length $pcomm`;l=`expr 20 - $m`;for ((n=1; n <= $l; n++)); do printf " "; done
          printf "PID $pid"
          m=`expr length $pid`;l=`expr 20 - $m`;for ((n=1; n <= $l; n++)); do printf " "; done
          printf "$pidfile\n"
          echo "$pidfile|$pid" >> /tmp/m_script/services.tmp
        else
          echo "<***> Stale pidfile found: $pidfile. Process with ID $pid doesn't exist!"
        fi
      done
    else
      find "$thepath" -maxdepth 1 -name "*\.pid" | while read pidfile ; do
        pid=`cat "$pidfile"|sed 's|\r||'`
        if [ -d "/proc/$pid" ] ; then
          if [ -f "/proc/$pid/comm" ] ; then
            pcomm=`cat /proc/$pid/comm`
          else
            pcomm=`cat /proc/$pid/cmdline`
          fi
          printf "$pcomm"
          m=`expr length $pcomm`;l=`expr 20 - $m`;for ((n=1; n <= $l; n++)); do printf " "; done
          printf "PID $pid"
          m=`expr length $pid`;l=`expr 20 - $m`;for ((n=1; n <= $l; n++)); do printf " "; done
          printf "$pidfile\n"
          echo "$pidfile|$pid" >> /tmp/m_script/services.tmp
        else
          echo "<***> Stale pidfile found: $pidfile. Process with ID $pid doesn't exist!"
        fi
      done
    fi
  elif [ -f "$thepath" ] ; then
    pid=`cat "$thepath"|sed 's|\r||'`
    if [ -d "/proc/$pid" ] ; then
      if [ -f "/proc/$pid/comm" ] ; then
        pcomm=`cat /proc/$pid/comm`
      else
        pcomm=`cat /proc/$pid/cmdline`
      fi
      printf "$pcomm"
      m=`expr length $pcomm`;l=`expr 20 - $m`;for ((n=1; n <= $l; n++)); do printf " "; done
      printf "PID $pid"
      m=`expr length $pid`;l=`expr 20 - $m`;for ((n=1; n <= $l; n++)); do printf " "; done
      printf "$pidfile\n"
      echo "$pidfile|$pid" >> /tmp/m_script/services.tmp
    else
      echo "<***> Stale pidfile found: $thepath. Process with ID $pid doesn't exist!"
    fi
  else
    echo "<***> Path $thepath doesn't exist!"
  fi
done
prevlist=`cat "${rpath}/../services.list" 2>/dev/null| grep -v '^#' | grep -v '^[:space:]*#'`
currlist=`cat /tmp/m_script/services.tmp 2>/dev/null| grep -v '^#' | grep -v '^[:space:]*#'`
if [ `echo $prevlist | wc -l` -ne 0 ] && [ `echo $currlist | wc -l` -ne 0 ] ; then
  for LINE in $currlist ; do
    if [ `echo "$prevlist" | grep -c "^${LINE}$"` -eq 0 ] ; then
      service=`echo $LINE | cut -d'|' -f1`
      pid=`echo $LINE | cut -d'|' -f2`
      if [ -f "/proc/$pid/comm" ] ; then
        pcomm=`cat /proc/$pid/comm`
      else
        pcomm=`cat /proc/$pid/cmdline`
      fi
      if [ $(echo "$prevlist" | grep -c "^$service") -eq 0 ] ; then
        echo "<**> Service $pcomm with pidfile $service is a new service"
      fi
    fi
  done
  for LINE in $prevlist ; do
    if [ `echo "$currlist" | grep -c "^${LINE}$"` -eq 0 ] ; then
      service=`echo $LINE | cut -d'|' -f1`
      pid=`echo $LINE | cut -d'|' -f2`
      if [ -f "/proc/$pid/comm" ] ; then
        pcomm=`cat /proc/$pid/comm`
      else
        pcomm=`cat /proc/$pid/cmdline`
      fi
      if [ $(echo "$currlist" | grep -c "^$service") -eq 0 ] ; then
        echo "<***> Service $pcomm with pidfile $service stopped!"
      else
        echo "<**> Service $pcomm with pidfile $service restarted"
      fi
    fi
  done
fi
cat /tmp/m_script/services.tmp > "${rpath}/../services.list"
rm -f /tmp/m_script/services.tmp
IFS=$IFS1

