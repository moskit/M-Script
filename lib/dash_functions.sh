#!/bin/bash
# Copyright (C) 2008-2012 Igor Simonov (me@igorsimonov.com)
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

dpath=$(readlink -f "$BASH_SOURCE")
dpath=${dpath%/*}
#*/

M_ROOT=$(readlink -f "$dpath/..")

source "$dpath/../conf/mon.conf"
source "$dpath/../conf/dash.conf"
[ -n "$timeshift" ] || timeshift=`cat "$M_TEMP"/timeshift 2>/dev/null` || timeshift=10
[ -n "$freqdef" ] || freqdef=$FREQ
timerange=`expr $slotline_length \* \( $freqdef - $timeshift \)` || timerange=10000

SQL=`which sqlite3 2>/dev/null`

print_cgi_headers() {
cat << "EOF"
Pragma: no-cache
Expires: 0
Content-Cache: no-cache
Content-type: text/html

EOF
}

print_page_title() {
  echo -e "<div class=\"dashtitle\">\n  <div class=\"server\">\n    <div class=\"servername\" id=\"title1\">${1}</div>"
  shift
  while [ -n "$1" ] ; do
    dfpptid=$(echo "$1" | tr -d '<>/' | tr ' ' '_')
    echo "<div class=\"status\" id=\"$dfpptid\"><b>${1}</b></div>"
    shift
  done
  echo -e "  </div>\n</div>"
  unset dfpptid
}

open_cluster() {
  dfocid="$1"
  shift
  [ -n "$1" ] && dfoconclick="$1"
  echo "<div class=\"cluster\" id=\"${dfocid}\">"
  echo -e "<div class=\"clustername\"><span id=\"${dfocid}_name\" `[ -n "$dfoconclick" ] && echo -n "class=\\"indent clickable\\" onclick=\\"showDetails('${dfocid}_name','${dfoconclick}')\\"" || echo -n "class=\\"indent\\""`>${dfocid##*|}</span>"
  unset dfoconclick
}

print_cluster_inline() {
  # print_cluster_inline "metric<|onclick><|style>" "metric2<|onclick2><|style2>" ...
  while [ -n "$1" ] ; do
    dfpcistatusarg="$1"
    if [ "X$dfpcistatusarg" == "X-" ]; then
      echo "<div id=\"${dfocid}_status\" class=\"clusterstatus\">&dash;</div>"
      shift
      continue
    fi
    dfpcistatus=`echo "$dfpcistatusarg" | cut -d'|' -f1`
    dfpcionclick=`echo "$dfpcistatusarg" | cut -s -d'|' -f2`
    dfpcistyle=`echo "$dfpcistatusarg" | cut -s -d'|' -f3`
    if [ -n "$dfpcionclick" ]; then
      classadded="clickable"
      onclick="onclick=\"showDetails('${dfolid}_$dfpcistatus','$dfpcionclick')\""
    else
      unset onclick classadded dfpcionclick
    fi
    [ -n "$dfpistyle"] && style="style=\"$dfpistyle\"" || unset style
    dfpcicont=`eval echo \\$$dfpcistatus`
    [ ${#dfpcicont} -gt 12 ] && dfpcicontalt=`echo -n "$dfpcicont" | cut -d'=' -f2 | tr -d '<>'` || unset dfpcicontalt
    echo "<div id=\"${dfocid}_status\" class=\"status $classadded\" $onclick $style title=\"$dfpcicontalt\">${dfpcicont}</div>"
    shift
  done
}

close_cluster_line() {
  echo "</div>"
  [ -n "$dfocid" ] && echo "<div class=\"details\" id=\"${dfocid}_details\"></div>"
}

close_cluster() {
  echo "</div>"
  unset dfocid
}

open_line() {
  # open_line "title<|style><|uniqkey>" "onclick"
  dfoltitle="$1"
  shift
  if [ -n "$1" ]; then
    dfolonclick=$1
    classadded="clickable"
  fi
  dfolkey=`echo "$dfoltitle" | cut -s -d'|' -f3`
  dfolnode="${dfoltitle%%|*}"
  dfolstyle=" `echo "$dfoltitle" | cut -s -d'|' -f2`"
  dfolnodep="${dfolnode:0:20}"
  [ -n "$dfocid" ] && dfolkey="${dfocid#*|}${dfolkey}"
  [ -n "$dfolkey" ] && dfolid="$dfolkey|$dfolnode" || dfolid="$dfolnode"
  echo -e "<div class=\"server${dfolstyle}\" id=\"${dfolid}\">\n<div class=\"servername $classadded\" id=\"${dfolid}_name\" onclick=\"showDetails('${dfolid}_name','${dfolonclick}')\">$dfolnodep</div>"
  unset dfolparent dfolnode dfolonclick dfolnodep
}

print_inline() {
  # print_inline "metric<|onclick><|style>" "metric2<|onclick2><|style2>" ...
  while [ -n "$1" ] ; do
    dfpistatusarg="$1"
    if [ "X$dfpistatusarg" == "X-" ]; then
      echo "<div id=\"${dfolid}_status\" class=\"clusterstatus\">&dash;</div>"
      shift
      continue
    fi
    dfpistatus=`echo "$dfpistatusarg" | cut -d'|' -f1`
    dfpionclick=`echo "$dfpistatusarg" | cut -s -d'|' -f2`
    dfpistyle=`echo "$dfpistatusarg" | cut -s -d'|' -f3`
    if [ -n "$dfpionclick" ]; then
      classadded="clickable"
      onclick="onclick=\"showDetails('${dfolid}_$dfpistatus','$dfpionclick')\""
    else
      unset onclick classadded dfpionclick
    fi
    [ -n "$dfpistyle"] && style="style=\"$dfpistyle\"" || unset style
    echo "<div class=\"status $classadded\" id=\"${dfolid}_$dfpistatus\" $onclick $style>`eval echo \"\\$$dfpistatus\"`</div>"
    shift
  done
  unset dfpistatus dfpionclick dfpistyle
}

close_line() {
  echo "</div>"
  echo "<div class=\"details\" id=\"${dfolid}_details\"></div>"
  unset dfolid
}

print_dashline() {
  dfpdonclick=$1
  dfpdsource=$2
  shift 2
  if [ -n "$dfpdsource" ]; then
    case $dfpdsource in
    folder)
      [ -d "$dpath/../www/${@}" ] || install -d "$dpath/../www/${@}"
      cat "$dpath/../www/${@}/dash.html" 2>/dev/null
      ;;
    database)
      dfpddbpath=$1
      shift
      dfpddbtable=$1
      ;;
    esac
  fi
  unset dfpdsource dfpddbpath dfpddbtable
}

print_dashlines() {
  dfpdsonclick=$1
  dfpdssource=$2
  shift 2
  if [ -n "$dfpdssource" ]; then
    case $dfpdssource in
    folder)
      [ -d "$dpath/../www/${@}" ] || install -d "$dpath/../www/${@}"
IFS1=$IFS; IFS='
'
      for server in `find "$dpath/../www/${@}/" -maxdepth 1 -mindepth 1 -type d | sort` ; do
        open_line "${server##*/}" "$dfpdsonclick" "${@##*/}"
        cat "$dpath/../www/${@}/${server##*/}/dash.html"
        close_line "${server##*/}"
      done
IFS=$IFS1
      ;;
    database)
      shift
      dfpdsdbpath=$1
      shift
      dfpdsdbtable=$1
      
      
      ;;
    esac
  fi
  unset dfpdsonclick dfpdssource dfpdsdbpath dfpdsdbtable
}

print_timeline() {
  dfptoldest=`date -d "-$timerange sec"`
  dfpthour=`date -d "$dfptoldest" +"%H"`
  echo -e "<div class=\"server\">\n<span class=\"servername\">${1}</span>"
  for ((n=0; n<$slotline_length; n++)) ; do
    dfpttimediff=`expr $n \* \( $freqdef - $timeshift \)`
    dfpttimestamp=`date -d "$dfptoldest +$dfpttimediff sec"`
    dfpthournew=`date -d "$dfpttimestamp" +"%H"`
    if [ "X$dfpthournew" == "X$dfpthour" ] ; then
      echo "<div class=\"chunk timeline\">&nbsp;</div>"
    else
      echo "<div class=\"chunk hour\">${dfpthournew}:00</div>"
      dfpthour=$dfpthournew
    fi
  done
  echo "</div>"
  unset dfptoldest dfpthour dfpttimediff dfpttimestamp dfpthournew
}

print_nav_bar() {
  # view0 is a special ID indicating updaterlevel = 0 in monitors.js
  # that is, clicking it is the same as clicking the corresponding upper tab
  # other buttons IDs become CGI scripts names (with .cgi extension)
  [ -z "$1" ] && exit 0
  [ "${1%%|*}" == "${0%.cgi}" ] && dfpnbactive=" active"
  echo -e "<div id=\"views\">\n<ul id=\"viewsnav\">\n<li class=\"viewsbutton$dfpnbactive\" id=\"view0\" onClick=\"initMonitors('${1%%|*}', 0)\">${1#*|}</li>"
    shift
    while [ -n "$1" ]; do
      # not printing if not exists
      if [ -x "$M_ROOT/www/bin/${1%%|*}.cgi" ]; then
        unset dfpnbactive
        [ "${1%%|*}" == "${0%.cgi}" ] && dfpnbactive=" active"
        echo -e "<li class=\"viewsbutton$dfpnbactive\" id=\"${1%%|*}\" onClick=\"initMonitors('${1%%|*}', 1)\">${1#*|}</li>\n"
      fi
      shift
    done
  echo -e "</ul>\n</div>"
  unset dfpnbactive
}

print_table_2() {
  echo "<div class=\"tr\"><div class=\"td1\">${1}</div><div class=\"td2\">${2}</div></div>"
}

load_css() {
  echo "<style type=\"text/css\">"
  cat "$M_ROOT/www/css/$1"
  echo "</style>"
}

