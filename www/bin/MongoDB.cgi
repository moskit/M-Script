#!/bin/bash

scriptname=${0%.cgi}
scriptname=${scriptname##*/}
source "$PWD/../../lib/dash_functions.sh"
print_cgi_headers
print_nav_bar "MongoDB|Servers" "MongoDB/mongo_extended|Extended" "MongoDB/mongosharding|Sharding" "MongoDB/mongocollections|Collections" "MongoDB/mongologger|Log Monitor"
print_page_title "host:port" "Status" "Memory Res/Virt (Mbytes)" "Connections Current/Available" "Operations (N/sec)" "Locks Current/Overall  (%)" "Not In RAM / Page Faults  (N/sec)"

print_mongo_server() {
  local clname="$1"
  local host=`echo "$2" | cut -d'|' -f1`
  local role=`echo "$2" | cut -d'|' -f4`
  local roleprop=( `echo "$role" | tr '=' ' '` )
  local roleind=`echo $role | cut -b 1 | sed 's|.|\U&|'`
  if [ "_${roleprop[1]}" == "_true" ]; then
    [ ${roleprop[2]} -ne 0 ] && roleind="${roleind}D" || roleind="${roleind}H"
  fi
  if [ "_${roleprop[0]}" == "_slave" ]; then
    local roletitle="`echo -e "slave\n\nHidden: ${roleprop[1]}\nDelay: ${roleprop[2]}\nIndexes: ${roleprop[3]}\nPriority: ${roleprop[4]}\nVotes: ${roleprop[5]}\nTags: ${roleprop[6]}"`"
  else
    local roletitle="`echo -e "${roleprop[0]}\n\nPriority: ${roleprop[1]}\nVotes: ${roleprop[2]}\nTags: ${roleprop[3]}"`"
  fi
  port="${host##*:}"
  name="${host%:*}"
  nodeid="$clname|${name}:${port}"
  [ ${#name} -gt 14 ] && namep="${name:0:7}..${name:(-7)}" || namep=$name
  [ -d "$PWD/../$scriptname/$clname/${name}:${port}" ] && install -d "$PWD/../$scriptname/$clname/${name}:${port}"
  [ -n "$port" ] && wport=`expr $port + 1000`
  report=`cat "$PWD/../../standalone/$scriptname/${name}:${port}.report" 2>/dev/null`
  rawdata=`cat "$PWD/../../standalone/$scriptname/data/${name}:${port}.dat" 2>/dev/null`
  
  echo "<div class=\"server\" id=\"${nodeid}\">"
  
    echo "<div class=\"servername clickable\" id=\"${nodeid}_name\" onClick=\"showData('${nodeid}_name','/${scriptname}')\" title=\"${name}:${port}\">${namep}:${port}<span class=\"${roleind}\" title=\"${roletitle}\">${roleind}</span><div id=\"data_${nodeid}_name\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>" 2>/dev/null
    echo "<div class=\"status status_short clickable\" id=\"${nodeid}_http\" onclick=\"showURL('${nodeid}_http','http://${name}:${wport}','${scriptname}')\">HTTP<div id=\"data_${nodeid}_http\" class=\"dhtmlmenu\" style=\"display: none\"></div></div>"
    
    if [ "_`echo "$rawdata" | grep ^status= | cut -d'=' -f2`" == "_1" ] ; then
      echo "<div class=\"status status_short statusok clickable\" id=\"${nodeid}_status\" onclick=\"showDetails('${nodeid}_status','MongoDB/mongostatus')\">OK</div>"
    else
      echo "<div class=\"status status_short statuserr clickable\" id=\"${nodeid}_status\" onclick=\"showDetails('${nodeid}_status','MongoDB/mongostatus')\">Error</div>"
    fi
    
    echo "<div class=\"status\" id=\"${nodeid}_mem\">`echo "$rawdata" | grep ^memRes= | cut -d'=' -f2` / `echo "$rawdata" | grep ^memVir= | cut -d'=' -f2`</div>"

    connections=`echo "$report" | grep ' connections: ' | cut -d':' -f2 | sed 's| *||g'`
    echo "<div class=\"status\" id=\"${nodeid}_conn\">`echo "$connections" 2>/dev/null | head -1` / `echo "$connections" 2>/dev/null | tail -1`</div>" 2>/dev/null
    
    qps=`echo "$report" | grep '^Network requests per second' | cut -d':' -f2 | sed 's| *||g'`
    [ -n "$qps" ] || rps=`echo "$report" | grep '^Total' | awk '{print $2}'`
    
    echo "<div class=\"status clickable\" id=\"${nodeid}_qps\" onclick=\"showDetails('${nodeid}_qps','MongoDB/mongoqps')\">$qps</div>"
    
    locktime=`echo "$report" | grep '^Lock time ' | cut -d':' -f2 | sed 's| *||g'`
    echo "<div class=\"status clickable\" id=\"${nodeid}_locks\" onclick=\"showDetails('${nodeid}_locks','MongoDB/mongolocks')\">`echo "$locktime" 2>/dev/null | head -1` / `echo "$locktime" 2>/dev/null | tail -1`</div>" 2>/dev/null
    
    notinmemory=`echo "$report" | grep '^Records not found in memory' | cut -d':' -f2 | sed 's| *||g'`
    pagefaults=`echo "$report" | grep '^Page fault exceptions' | cut -d':' -f2 | sed 's| *||g'`
    echo "<div class=\"status clickable\" id=\"${nodeid}_recstats\" onclick=\"showDetails('${nodeid}_recstats','MongoDB/mongorecstats')\">`echo "$notinmemory" | head -1` / `echo "$pagefaults" | tail -1`</div>"
    
  echo "</div>"
  echo "<div class=\"details\" id=\"${nodeid}_details\"></div>"
}

IFS1=$IFS
IFS='
'
if [ `cat "$PWD/../../standalone/$scriptname/mongo_config_servers.list" 2>/dev/null | wc -l` -gt 0 ] ; then

  clustername="Configuration Servers"
  open_cluster "$clustername"
  close_cluster_line
  for s in `cat "$PWD/../../standalone/$scriptname/mongo_config_servers.list"` ; do
    print_mongo_server "$clustername" "$s"
  done
    
  close_cluster
  
# Standalone servers
elif [ `cat "$PWD/../../standalone/$scriptname/mongo_servers.list" 2>/dev/null | wc -l` -gt 0 ] ; then
  clustername="MongoDB Servers"
  open_cluster "$clustername"
  close_cluster_line
    for rs in `cat "$PWD/../../standalone/$scriptname/mongo_servers.list" | cut -d'|' -f3 | sort | uniq` ; do
      echo "<div class=\"server hilited\" id=\"$rs\">"
      echo "<div class=\"servername\" id=\"${rs}_name\">Replica Set: ${rs}</div>"
      echo "</div>"
      for s in `cat "$PWD/../../standalone/$scriptname/mongo_servers.list" | grep "|$rs|"` ; do
        print_mongo_server "$clustername" "$s"
      done
    done
### Not members of any RS
    for s in `cat "$PWD/../../standalone/$scriptname/mongo_servers.list" | grep ^.*\|$` ; do
      print_mongo_server "$clustername" "$s"
    done
    
  close_cluster
  
fi

# Shard servers
if [ `cat "$PWD/../../standalone/$scriptname/mongo_shards.list" 2>/dev/null | wc -l` -gt 0 ] ; then

  clustername="Shard Servers"
  open_cluster "$clustername"
  close_cluster_line
    for rs in `cat "$PWD/../../standalone/$scriptname/mongo_shards.list" | cut -d'|' -f2 | sort | uniq` ; do
      echo "<div class=\"server hilited\" id=\"$rs\">"
      echo "<div class=\"servername\" id=\"${rs}_name\">Replica Set: ${rs}</div>"
      echo "</div>"
      for s in `cat "$PWD/../../standalone/$scriptname/mongo_shards.list" | grep "|$rs|"` ; do
        print_mongo_server "$clustername" "$s"
      done
    done
### Not members of any RS
    for s in `cat "$PWD/../../standalone/$scriptname/mongo_shards.list" | grep ^.*\|$` ; do
      print_mongo_server "$s"
    done
  close_cluster
  
fi

if [ `cat "$PWD/../../standalone/$scriptname/mongo_mongos_servers.list" 2>/dev/null | wc -l` -gt 0 ] ; then

  clustername="Balancers"
  open_cluster "$clustername"
  close_cluster_line
  
    for s in `cat "$PWD/../../standalone/$scriptname/mongo_mongos_servers.list"` ; do
      print_mongo_server "$clustername" "$s"
    done
    
  close_cluster
  
fi
IFS=$IFS1

