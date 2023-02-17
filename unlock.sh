#!/bin/bash

NORMAL="\e[39m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
WEIRD="\e[35m"

# Validation pre tasks
type jq > /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERR]${NORMAL} This script requires jq. Install jq first"
    exit 1
fi
if [ ! -f "config.json" ]; then
    echo -e "${RED}[ERR]${NORMAL} This script requires a 'config.json' file! Create it first"
    exit 1
fi
CHECK=$(cat config.json | jq empty)
RES=$?
if [ $RES -ne 0 ]; then
    echo -e "${RED}[ERR]${NORMAL} This error comes from your 'config.json'. You will find more information about it above"
    exit 1
fi

# Validation a file is passed

if [ -z $1 ] ; then
	echo "This script needs a file as argument"
	echo "Usage: bash ./unlock.sh fileWithUUID"
        exit 0
fi


# Load Ceph configuration
declare -A config
result=( $(cat config.json | jq -r '.nova | keys[]') )
for type in "${result[@]}"; do
    config[nova-$type]=$(jq -r ".nova.$type" config.json)
done

result=( $(cat config.json | jq -r '.cinder | keys[]') )
for type in "${result[@]}"; do
    config[cinder-$type]=$(jq -r ".cinder.$type" config.json)
done

# funcs
function func_nova (){
    TYPE=$(openstack server show $1 -c OS-EXT-AZ:availability_zone -f value)
    if [[ -v "config[nova-$TYPE]" ]] ; then
        POOL=${config["nova-$TYPE"]}
        remove_lock $POOL $1\_disk
    else
        echo -e "${RED}[ERR]${NORMAL} Cannot determine ceph pool for vm $1 "
    fi
}

function remove_lock()
{
    if [ -z $1 ] ||  [ -z $2 ]
    then
        echo -e "${RED}[ERR]${NORMAL} One or both mandatory variable is empty: pool name: '$1' rbd name is '$2'"
        return 1
    fi
    POOL=$1
    BLOCK=$2
    echo -e "${BLUE}[CMD]${NORMAL} rbd -p $POOL lock list $BLOCK"
    IS_LOCKED=$(rbd -p $POOL lock list $BLOCK | wc -l)
    if [ $IS_LOCKED -eq 0 ]
    then
        echo -e "${GREEN}[INF]${NORMAL} Disk $BLOCK has no lock to remove"
    else
        read -r -a vars <<< $(rbd -p $POOL lock list $BLOCK  | tail -1)
        echo -e "${BLUE}[CMD]${NORMAL} rbd -p $POOL lock remove $BLOCK \"${vars[1]} ${vars[2]}\" ${vars[0]}"
        rbd -p  $POOL lock remove $BLOCK "${vars[1]} ${vars[2]}" ${vars[0]}
        # add check
        echo -e "${GREEN}[INF]${NORMAL} lock on $BLOCK removed."
    fi
}

function func_cinder_volume()
{
    LEN=$(openstack server show $1 -c volumes_attached -f json | jq '.["volumes_attached"] | length')
    if [ $LEN -eq 0 ]
    then
        echo -e "${GREEN}[INF]${NORMAL} Server $1 has no attached volumes"
    else
        for vol in $(openstack server show $1 -c volumes_attached -f json | jq -r '.["volumes_attached"] | .[].id ')
        do
            # Manage case VM without cinder volume attached
            if [ -z $vol ];then
                echo -e "${RED}[ERR]${NORMAL} Variable vol is empty:$vol.It should not happen";
            else
                echo -e "${GREEN}[INF]${NORMAL} Unlocking $vol"
                func_cinder $vol
            fi
        done
    fi
}

function func_cinder()
{
    vol=$1
    TYPE=$(openstack volume show $vol -c type -f value)
    if [[ -v "config[cinder-$TYPE]" ]] ; then
        POOL=${config["cinder-$TYPE"]}
        BLOCK=volume-$vol
        echo -e "${GREEN}[INF]${NORMAL} remove_lock $POOL $BLOCK"
        remove_lock $POOL $BLOCK
    else
        echo -e "${RED}[ERR]${NORMAL} Cannot CINNDERR determine ceph pool for vm $1 "
    fi
}


# tasks
for i in $(cat $1)
do
    IS_CINDER=$(openstack server show $i -f value -c image)
    if [ $? -eq 1 ];
    then
        echo -e "${YELLOW}[WARN]${NORMAL} $i is not a valid instance. Check if a volume matches this ID"
        VOL=(openstack volume show $i -f value -c id)
        if [ $? -eq 0 ]
        then
            echo -e "${GREEN}[INF]${NORMAL} $i is an ID from cinder "
            func_cinder $i
        else
            echo -e "${WEIRD}[ERR]${NORMAL} $i is not a valid volume and not a nova disk. Verify your IDs"
        fi
    else
        echo -e "${GREEN}[INF]${NORMAL} Checking VM type of $i"
        if [[ -z "$IS_CINDER"  || "$IS_CINDER" == "N/A (booted from volume)" ]]
        then
            echo -e "${GREEN}[INF]${NORMAL} This server booted on Cinder volume"
            func_cinder_volume $i
        else
            echo -e "${GREEN}[INF]${NORMAL} This server booted on Nova disk"
            func_nova $i
            # User can attach cinder volumes
            echo -e "${GREEN}[INF]${NORMAL} Checking if this nova vm use some cinder volumes"
            func_cinder_volume $i
        fi
    fi
done
