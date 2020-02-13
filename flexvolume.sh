#!/bin/bash

SOCKETPATH='/usr/libexec/kubernetes/kubelet-plugins/volume/exec/nect.com~s3flex/socket'

usage() {
	err "Invalid usage. Usage: "
	err "\t$0 init"
	err "\t$0 mount <mount dir> <json params>"
	err "\t$0 unmount <mount dir>"
	exit 1
}

err() {
	echo -ne $* 1>&2
}

log() {
	echo -ne $* >&1
}

ismounted() {
	MOUNT=`findmnt -n ${MNTPATH} 2>/dev/null | cut -d' ' -f1`
	if [ "${MOUNT}" == "${MNTPATH}" ]; then
		echo "1"
	else
		echo "0"
	fi
}

domount() {
	MNTPATH=$1
	shift
	DATA=$*

	if [ $(ismounted) -eq 1 ] ; then
		log "{\"status\": \"Success\"}"
		exit 0
	fi

	mkdir -p ${MNTPATH} &> /dev/null

	CURLOUT=`curl -s --fail --show-error --unix-socket "$SOCKETPATH" -X POST "http://localhost${MNTPATH}" -d "$DATA" 2>&1`
	if [ $? -ne 0 ]; then
		CURLOUT=`echo "$CURLOUT" | sed 's/"//g'`
		err "{ \"status\": \"Failure\", \"message\": \"Failed to mount ${MNTPATH}, see: $CURLOUT\"}"
		exit 1
	fi
	log "{\"status\": \"Success\"}"
	exit 0
}

unmount() {
	MNTPATH=$1
	if [ $(ismounted) -eq 0 ] ; then
		log "{\"status\": \"Success\"}"
		exit 0
	fi

	umount ${MNTPATH} &> /dev/null
	if [ $? -ne 0 ]; then
		err "{ \"status\": \"Failed\", \"message\": \"Failed to unmount volume at ${MNTPATH}\"}"
		exit 1
	fi
	rmdir ${MNTPATH} &> /dev/null

	log "{\"status\": \"Success\"}"
	exit 0
}

op=$1

if [ "$op" = "init" ]; then
	log "{\"status\": \"Success\", \"capabilities\": { \"attach\": false }}"
	exit 0
fi

if [ $# -lt 2 ]; then
	usage
fi

shift

case "$op" in
	mount)
		domount $*
		;;
	unmount)
		unmount $*
		;;
	*)
		usage
esac

exit 1