#! /bin/bash

# Script to automate some of the common tasks with MegaRAID.
# Has limited capability based on current needs.
# Script tested and used with megacli 8.07.14;
# output format variations may render it incorrect for other versions.
# Would be good to adapt to storcli.

set -e
MY_NAME=`basename $0`

# config parameters : BEGIN 

MEGACMD="MegaCli64"

# tmp file to manipulate command output
WORKFILE="/tmp/${MY_NAME}.tmp.txt"

# CMD_MODE can be "delete", "create" or "check_config"
CMD_MODE="check_config"
# CONFIRM=n is useful to see what create and delete would do
# without actually performing the change
CONFIRM="n" # "n" here will skip create and delete commands

ADID=0 # adapter id

# delete-specific section

# VD 0 could be for OS; use caution
SKIP_VDS="0" # space-separated list; will not delete these

# create specific section

# RAID_TYPE: "raid6", "jbod"
# jbod currently creates single-disk RAID-0
RAID_TYPE="jbod" 
NUM_CREATE=0 # limit to this many virtual drives created. 0 means no limit
VD_DISKS=12 # used only for raid6
SU_SZ_KB=128 # stripe unit size; used only for raid6
CALC_SU_SZ="y" # use a calculated value for stripe unit size

# script allows init for raid6 to be skipped
# this may be useful for testing
# but if skipped, init should be done manually before using
SKIP_INIT="n" 

# config parameters : END 

function print_usage
{
    echo "Usage: "
    echo "      ${MY_NAME} --help"
    echo "      ${MY_NAME} --command=check_config"
    echo "      ${MY_NAME} --command=delete [--skip_vds=<comma separated vd list>] [--confirm={y|n}]"
    echo "      ${MY_NAME} --command=create --type=jbod [--create_limit=<num>] [--confirm={y|n}]"
    echo "      ${MY_NAME} --command=create --type=raid6 [--num_disks=<num>] [--create_limit=<num>] [--skip_init={y|n}] [--stripe_unit_size_kb=<su_sz>] [--confirm={y|n}]"
}

# process command line 

if [ "$1" = "--help" ]; then
    print_usage
    exit 0
fi

while [ "$1" != "" ]; do
    cmd_param=`echo $1 | awk -F= '{print $1}'`
    cmd_value=`echo $1 | awk -F= '{print $2}'`

    case "$cmd_param" in
	--command)
	    CMD_MODE="$cmd_value"
	    ;;
	--skip_vds)
	    commalist_vds="$cmd_value"
	    SKIP_VDS=`echo $commalist_vds | tr ',' ' '`
	    ;;
	--confirm)
	    CONFIRM="$cmd_value"
	    ;;
	--type)
	    RAID_TYPE="$cmd_value"
	    ;;
	--create_limit)
	    NUM_CREATE="$cmd_value"
	    ;;
	--num_disks)
	    VD_DISKS="$cmd_value"
	    ;;
	--stripe_unit_size_kb)
	    SU_SZ_KB="$cmd_value"
	    CALC_SU_SZ="n"
	    ;;
	--skip_init)
	    SKIP_INIT="$cmd_value"
	    ;;
	*)
	    print_usage
	    exit 1
    esac
    shift
done

# end process command line

# get list of enclosures
ENCL_LIST=`${MEGACMD} -EncInfo -a${ADID} | grep "Device ID" | awk '{print $NF}'`

# get list of virtual drives
VD_LIST=`${MEGACMD} -LDInfo -Lall -a${ADID} | grep -e "Virtual Drive" | grep "Target Id" | awk '{print $3}'`

if [ "${CMD_MODE}" = "delete" ]; then

    # mark virtual drives to be preserved
    for vd in ${VD_LIST}; do
	VDS[${vd}]=0
    done
    for vd in ${SKIP_VDS}; do
	VDS[${vd}]=1
    done
    delete_vds=""
    for vd in ${VD_LIST}; do
	if [ ${VDS[vd]} -ne 1 ]; then
	    delete_vds="${delete_vds} ${vd}"
	fi
    done

    echo "Command: Delete"
    echo "Skipping Virtual Drives: ${SKIP_VDS}"
    echo "Confirmation: ${CONFIRM}"
    echo

    echo "Deleting Virtual Drives: ${delete_vds}"
    if [ "${CONFIRM}" = "y" ]; then
	for vd in ${delete_vds}; do
	    ${MEGACMD} -CfgLdDel -L${vd} -Force -a${ADID}
	done
    else
	echo "no confirmation. skipping delete..."
    fi
    # could exit here, but...
    # exit later after printing config info

fi

# get list of drives in each enclosure
for encl in ${ENCL_LIST}; do
    ENCL_DRIVES[${encl}]="" # all drives
    ENCL_USED[${encl}]="" # used drives
    ENCL_AVAIL[${encl}]="" # available drives
done
${MEGACMD} -PDList -a${ADID} | grep -e "Enclosure Device ID:" -e "Slot Number" > ${WORKFILE} || true
while read line; do
    line_type=`echo $line | awk '{print $1}'`
    if [ "${line_type}" = "Enclosure" ]; then
	current_encl=`echo $line | awk '{print $NF}'`
    elif [ "${line_type}" = "Slot" ]; then
	slot=`echo $line | awk '{print $NF}'`
	ENCL_DRIVES[${current_encl}]="${ENCL_DRIVES[current_encl]} ${slot}"
    else
	echo "output format mismatch, exiting"
	exit 1
    fi
done <${WORKFILE}

# get list of used drives in each enclosure
${MEGACMD} -LdPdInfo -a${ADID} | grep -e "Virtual Drive" -e "Enclosure Device ID:" -e "Slot Number" > ${WORKFILE} || true
while read line; do
    line_type=`echo $line | awk '{print $1}'`
    if [ "${line_type}" = "Virtual" ]; then
	:
    elif [ "${line_type}" = "Enclosure" ]; then
	current_encl=`echo $line | awk '{print $NF}'`
    elif [ "${line_type}" = "Slot" ]; then
	slot=`echo $line | awk '{print $NF}'`
	ENCL_USED[${current_encl}]="${ENCL_USED[current_encl]} ${slot}"
    else
	echo "output format mismatch, exiting"
	exit 1
    fi
done <${WORKFILE}

# generate list of available drives in each enclosure
for encl in ${ENCL_LIST}; do
    for drv in ${ENCL_DRIVES[encl]}; do
	avail=1
	for udrv in ${ENCL_USED[encl]}; do
	    if [ "$drv" = "$udrv" ]; then
		avail=0 || true
	    fi
	done
	if [ $avail -eq 1 ]; then
	    ENCL_AVAIL[$encl]="${ENCL_AVAIL[encl]} ${drv}"
	fi
    done
done

TOT_AVAIL=0 # total number of available drives
echo "Printing Config:"
for encl in ${ENCL_LIST}; do
    echo "Enclosure $encl :"
    echo -n "    Drives: "
    echo ${ENCL_DRIVES[encl]}
    echo -n "    Used drives: "
    echo ${ENCL_USED[encl]}
    echo -n "    Available drives: "
    echo ${ENCL_AVAIL[encl]}
    num_avail=`echo ${ENCL_AVAIL[encl]} | wc -w`
    TOT_AVAIL=`expr $TOT_AVAIL + $num_avail` || true
done
echo

if [ "$CMD_MODE" = "delete" ] || [ "$CMD_MODE" = "check_config" ]; then
    exit 0
elif [ "$CMD_MODE" != "create" ]; then
    print_usage
    exit 1
fi

function calc_r6su
# stripe unit size for RAID-6
# tries to keep stripe size below 2MB
# pass: number of disks in RAID-6 VD
# return: stripe unit size in KB
{
    local num_disks=${1}

    local su_sz_kb=256 # preferred su size
    local min_su_sz_kb=64 # minimum su size

    local data_disks=`expr $num_disks - 2`
    local stripe_sz_kb=`expr $su_sz_kb \* ${data_disks}`

    while [ $stripe_sz_kb -ge 2048 ]; do
	new_su_sz_kb=`expr $su_sz_kb / 2` || true
	if [ $new_su_sz_kb -lt $min_su_sz_kb ]; then
	    break
	else
	    su_sz_kb=${new_su_sz_kb}
	fi
	stripe_sz_kb=`expr $su_sz_kb \* ${data_disks}`
    done

    echo $su_sz_kb
}

if [ -z "${NUM_CREATE}" ] || [ $NUM_CREATE -eq 0 ]; then
    CREATE_LIMIT=`expr ${TOT_AVAIL} + 1` # upper limit on no. of virtual drives
else
    CREATE_LIMIT=${NUM_CREATE}
fi

created_vds=0
if [ "$RAID_TYPE" = "jbod" ]; then

    echo "Command: Create"
    echo "Type: jbod"
    echo "Limit: $NUM_CREATE virtual drives"
    echo "Confirmation: ${CONFIRM}"
    echo

    for encl in ${ENCL_LIST}; do
	for drv in ${ENCL_AVAIL[encl]}; do
	    echo "creating virtual drive with drive: ${encl}:${drv}"
	    if [ "${CONFIRM}" = "y" ]; then
		${MEGACMD} -CfgLdAdd -r0[${encl}:${drv}] WB -a${ADID} 
	    else
		echo "no confirmation. skipping create..."
	    fi
	    created_vds=`expr $created_vds + 1`
	    if [ $created_vds -eq $CREATE_LIMIT ]; then
		echo "reached limit for virtual drives created. exiting..."
		exit 0
	    fi
	done
	echo "completed scanning of available drives in encl: ${encl}"
    done

elif [ "$RAID_TYPE" = "raid6" ]; then

    echo "Command: Create"
    echo "Type: raid6"
    echo "Number of disks in a virtual drive: ${VD_DISKS}"
    echo "Limit: $NUM_CREATE virtual drives"
    echo "Skip Initialization: ${SKIP_INIT}"
    echo "Confirmation: ${CONFIRM}"
    echo

    if [ -z "${VD_DISKS}" ] || [ ${VD_DISKS} -lt 3 ]; then
	echo "for raid6, number of disks should be >= 3.  skipping create..."
	exit 1
    fi
    if [ "${CALC_SU_SZ}" = "y" ]; then
	su_sz=$(calc_r6su ${VD_DISKS})
    else
	su_sz=${SU_SZ_KB}
    fi
    echo "creating raid6 configuration with su $su_sz KB "

    for encl in ${ENCL_LIST}; do
	pd_list=""
	drv_count=0
	for drv in ${ENCL_AVAIL[encl]}; do
	    if [ "${pd_list}" = "" ]; then
		pd_list="${encl}:${drv}"
	    else
		pd_list="${pd_list},${encl}:${drv}"
	    fi
	    drv_count=`expr ${drv_count} + 1`
	    if [ ${drv_count} -eq ${VD_DISKS} ]; then
		echo "creating raid6 virtual drive with drives: $pd_list"
		if [ "${CONFIRM}" = "y" ]; then
		    ${MEGACMD} -CfgLdAdd -r6[${pd_list}] WB -strpsz${su_sz} -a${ADID} | tee $WORKFILE
		    vd_id=`cat $WORKFILE | grep "Created VD" | awk '{print $NF}'`
		    if [ "$SKIP_INIT" = "y" ]; then
			echo "skipping init on virtual drive ${vd_id}"
			echo "start init manually with command: ${MEGACMD} -LdInit -Start -full -L${vd_id} -a${ADID}"
			echo "Command to monitor init progress: ${MEGACMD} -LdInit -ShowProg -L${vd_id} -a${ADID}"
		    else
			echo "starting init on virtual drive ${vd_id}"
			${MEGACMD} -LdInit -Start -full -L${vd_id} -a${ADID}
			echo "Command to monitor init progress: ${MEGACMD} -LdInit -ShowProg -L${vd_id} -a${ADID}"
		    fi
		else
		    echo "no confirmation. skipping create..."
		fi
		created_vds=`expr $created_vds + 1`
		if [ $created_vds -eq $CREATE_LIMIT ]; then
		    echo "reached limit for virtual drives created. exiting..."
		    exit 0
		fi
		pd_list=""
		drv_count=0
	    fi
	done
	echo "completed scanning of available drives in encl: ${encl}"
    done

else
    print_usage
fi

