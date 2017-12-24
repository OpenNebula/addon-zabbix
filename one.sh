#!/bin/bash

ONEVM_FILE=/tmp/onevm.out
ONEHOST_FILE=/tmp/onehost.out
ONEDATASTORE_FILE=/tmp/onedatastore.out
ONEVNET_FILE=/tmp/onevnet.out

# Select, sum or average values from all resources in the list
scount() {
    awk "{ if( \"$1\" == \"avg\" || \"$1\" == \"\" ) {sum+=$ 2} else {if($ 1 == \"$1\") {printf(\"%.0f\n\", $ 2)}} } END { if( \"$1\" == \"avg\" ) { printf(\"%.0f\n\", sum/NR) } if( \"$1\" == \"\" ) { printf(\"%.0f\n\", sum) } }"
}

percent(){
    echo "$1" "$2" | awk '{printf("%.0f\n", $1*100/$2)}'
}

difference(){
    echo "$1" "$2" | awk '{printf("%.0f\n", $1-$2)}'
}

list_hosts_param() {
    xmlstarlet sel -s -t -c "//HOST_POOL/HOST/ID/text()|//HOST_POOL/HOST/HOST_SHARE/$1" $ONEHOST_FILE | sed -e 's/<[^/<]*>/\t/g' -e 's/<\/[^<]*>/\n/g'
}

list_datastores_param() {
    xmlstarlet sel -s -t -c "//DATASTORE_POOL/DATASTORE/ID/text()|//DATASTORE_POOL/DATASTORE/$1" $ONEDATASTORE_FILE | sed -e 's/<[^/<]*>/\t/g' -e 's/<\/[^<]*>/\n/g'
}

list_vnets_leases_used() {
    xmlstarlet sel -s -t -c "//VNET_POOL/VNET[not(boolean(./PARENT_NETWORK_ID/text()[1]))]/ID/text()|//VNET_POOL/VNET[not(boolean(./PARENT_NETWORK_ID/text()[1]))]/USED_LEASES" $ONEVNET_FILE | \
        sed -e 's/<[^/<]*>/\t/g' -e 's/<\/[^<]*>/\n/g'
}

list_vnets_leases_total() {
    xmlstarlet sel -s -t -c '//VNET_POOL/VNET[not(./PARENT_NETWORK_ID/text())]/ID|//VNET_POOL/VNET[not(./PARENT_NETWORK_ID/text())]/AR_POOL/AR/SIZE' -n $ONEVNET_FILE | \
        sed -e 's/<\/SIZE>\(<ID>\)/\n\1/g' -e 's/\(<[^<]*>\)\{1,\}/\t/g' -e 's/\t\t//' | \
        awk '{for (i=2; i<=NF; i++) sum+=$i }{print $ 1 " " sum; sum=0 }' | tr ' ' '\t'
}

host_mem() {
    if [ -z "$3" ]; then
        list_hosts_param "$1" | scount "$2" | awk '{ printf( "%.0f\n", $1 * 1048576)}'
    else
        OPERATION="$1"
        PARAM1="$(host_mem "$2" "$4")"
        PARAM2="$(host_mem "$3" "$4")"
        $OPERATION $PARAM1 $PARAM2
    fi
}
host_cpu() {
    if [ -z "$3" ]; then
        list_hosts_param "$1" | scount "$2"
    else
        OPERATION="$1"
        PARAM1="$(host_cpu "$2" "$4")"
        PARAM2="$(host_cpu "$3" "$4")"
        $OPERATION $PARAM1 $PARAM2
    fi
}

datastore_space() {
    if [ -z "$3" ]; then
        list_datastores_param "$1" | scount "$2" | awk '{ printf( "%.0f\n", $1 * 1048576)}'
    else
        OPERATION="$1"
        PARAM1="$(datastore_space "$2" "$4")"
        PARAM2="$(datastore_space "$3" "$4")"
        $OPERATION $PARAM1 $PARAM2
    fi
}

vnet_leases(){
    if [ -z "$3" ]; then
        case "$1" in
            USED  ) list_vnets_leases_used "$1" | scount "$2" ;;
            TOTAL ) list_vnets_leases_total "$1" | scount "$2" ;;
            FREE  ) vnet_leases difference TOTAL USED "$2"
        esac
    else
        OPERATION="$1"
        PARAM1="$(vnet_leases "$2" "$4")"
        PARAM2="$(vnet_leases "$3" "$4")"
        $OPERATION $PARAM1 $PARAM2
    fi
}

hosts() {
    if [ -z "$1" ]; then
        xmlstarlet sel -s -t -v "/*/*/ID" -n $ONEHOST_FILE | wc -l
    else
        xmlstarlet sel -s -t -c '//HOST_POOL/HOST/ID/text()|//HOST_POOL/HOST/STATE' -n $ONEHOST_FILE | sed -e 's/<[^/<]*>/\t/g' -e 's/<\/[^<]*>/\n/g' | \
          awk '{init=0; monitoring_monitored=1; monitored=2; error=3; disabled=4; monitoring_error=5; monitoring_init=6; monitoring_disabled=7; offline=8}{ if( $ 2 == '$1' ){print $ 1} }' | wc -l
    fi
}

vms() {
    if [ -z "$1" ]; then
        xmlstarlet sel -s -t -v "/*/*/ID" -n $ONEVM_FILE | wc -l
    else
        xmlstarlet sel -s -t -c '//VM_POOL/VM/ID/text()|//VM_POOL/VM/STATE|//VM_POOL/VM/LCM_STATE' -n /tmp/onevm.out | \
            sed -e 's/<\/LCM_STATE>/\n/g' -e 's/\(<[^<]*>\)\{1,\}/\t/g' -e 's/\t\t//' | \
            awk '{init=0; pending=1; hold=2; active=3; stopped=4; suspended=5; poweroff=8; undeployed=9; clonning=10; split("16 19 60", lcm_unknown);
            split("36 37 38 39 40 41 42 44 46 47 48 49 50 61", lcm_failed) }
            { if("'$1'" == "unknown"){ for (i=1;i in lcm_unknown;i++) if($ 3 == lcm_unknown[i]){print $ 1}}}
            { if("'$1'" == "failed"){ if($ 3 == 7 ||$ 3 == 11){print $ 1}}}
            { if("'$1'" == "failed"){ for (i=1;i in lcm_failed;i++) if($ 3 == lcm_failed[i]){print $ 1}}}
            { if( !("'$1'" == "failed") && !("'$1'" == "unknown") && $ 2 == '$1' ){print $ 1} }' | wc -l
    fi
}

datastores() {
    xmlstarlet sel -s -t -v "/*/*/ID" -n $ONEDATASTORE_FILE | wc -l
}

vnets() {
    xmlstarlet sel -s -t -v "/*/*/ID" -n $ONEVNETS_FILE | wc -l
}

case "$1" in
    hosts      ) hosts      "$2" ;;
    vms        ) vms        "$2" ;;
    datastores ) datastores "$2" ;;
    vnets      ) vnets      "$2" ;;
    host_total_mem       ) host_mem TOTAL_MEM "$2" ;;
    host_free_mem        ) host_mem FREE_MEM  "$2" ;;
    host_used_mem        ) host_mem USED_MEM  "$2" ;;
    host_mem_usage       ) host_mem MEM_USAGE "$2" ;;
    host_total_cpu       ) host_cpu TOTAL_CPU "$2" ;;
    host_free_cpu        ) host_cpu FREE_CPU  "$2" ;;
    host_used_cpu        ) host_cpu USED_CPU  "$2" ;;
    host_cpu_usage       ) host_cpu CPU_USAGE "$2" ;;
    host_pfree_mem       ) host_mem percent FREE_MEM TOTAL_MEM    "$2" ;;
    host_pused_mem       ) host_mem percent USED_MEM TOTAL_MEM    "$2" ;;
    host_pfree_cpu       ) host_cpu percent FREE_CPU TOTAL_CPU    "$2" ;;
    host_pused_cpu       ) host_cpu percent USED_CPU TOTAL_CPU    "$2" ;;
    host_pcpu_usage      ) host_cpu percent CPU_USAGE TOTAL_CPU   "$2" ;;
    host_pmem_usage      ) host_cpu percent MEM_USAGE TOTAL_MEM   "$2" ;;
    host_pused_mem_usage ) host_cpu percent USED_CPU CPU_USAGE    "$2" ;;
    host_pused_cpu_usage ) host_cpu percent USED_MEM MEM_USAGE    "$2" ;;
    host_unused_mem      ) host_mem difference MEM_USAGE USED_MEM "$2" ;;
    host_unused_cpu      ) host_cpu difference CPU_USAGE USED_CPU "$2" ;;
    datastore_total_space ) datastore_space TOTAL_MB "$2" ;;
    datastore_free_space  ) datastore_space FREE_MB  "$2" ;;
    datastore_used_space  ) datastore_space USED_MB  "$2" ;;
    datastore_pfree_space ) datastore_space percent FREE_MB TOTAL_MB "$2" ;;
    datastore_pused_space ) datastore_space percent USED_MB TOTAL_MB "$2" ;;
    vnet_used_leases  ) vnet_leases USED  "$2" ;;
    vnet_free_leases  ) vnet_leases FREE  "$2" ;;
    vnet_total_leases ) vnet_leases TOTAL "$2" ;;
    vnet_pused_leases ) vnet_leases percent USED TOTAL "$2" ;;
    vnet_pfree_leases ) vnet_leases percent FREE TOTAL "$2" ;;
esac

