# Definition of the expand lvm function
export LV_NAME=$1
export CAPACITY="$2"

# Validate inputs
if [ $LV_NAME == "--help" ]; then
	echo " "
	echo "Usage: expand_lvm LV_NAMD CAPACITY" >&2
	echo " "
	echo "LV_NAME is the name of the logical volume as listed in lvs" >&2
	echo "CAPACITY is the desired new capacity of the LV" >&2
	echo "    +100%FREE    Expands the LV to fill 100% of the available capacity on the partition" >&2
	echo "    +50%FREE     Expands the LV to fill  50% of the available capacity on the partition" >&2
	echo " "
	exit 1
fi
if [ -z "$LV_NAME" ]; then
	echo " "
	echo "Usage: expand_lvm LV_NAMD CAPACITY" >&2
	echo " "
	echo "LV_NAME is the name of the logical volume as listed in lvs" >&2
	echo "CAPACITY is the desired new capacity of the LV" >&2
	echo "    +100%FREE    Expands the LV to fill 100% of the available capacity on the partition" >&2
	echo "    +50%FREE     Expands the LV to fill  50% of the available capacity on the partition" >&2
	echo " "
	exit 1
fi
if [ -z "$CAPACITY" ]; then
	echo " "
	echo "Usage: expand_lvm LV_NAMD CAPACITY" >&2
	echo " "
	echo "LV_NAME is the name of the logical volume as listed in lvs" >&2
	echo "CAPACITY is the desired new capacity of the LV" >&2
	echo "    +100%FREE    Expands the LV to fill 100% of the available capacity on the partition" >&2
	echo "    +50%FREE     Expands the LV to fill  50% of the available capacity on the partition" >&2
	echo " "
	exit 1
fi

# Detect VG name containing the LV
VG_NAME=$(lvs --noheadings -o vg_name --select lv_name="$LV_NAME" | awk '{print $1}')
if [ -z "$VG_NAME" ]; then
	echo "Error: Could not find VG for LV $LV_NAME." >&2
	exit 1
fi

# Detect PV name
PV_NAME=$(vgs --noheadings -o pv_name "$VG_NAME" | awk '{print $1}')
if [ -z "$PV_NAME" ]; then
	echo "Error: Could not find PV for VG $VG_NAME." >&2
	exit 1
fi

# Detect Disk name
DISK="/dev/$(lsblk -no pkname "$PV_NAME" | head -n 1)"

if [ -z "$DISK" ]; then
	echo "Error: Could not find disk for PV $PV_NAME." >&2
	exit 1
fi

# Check mount point
MOUNT_POINT=$(lsblk -o MOUNTPOINT -n "/dev/$VG_NAME/$LV_NAME" | head -n 1)
if [ -z "$MOUNT_POINT" ]; then
	echo "Error: Could not find mount point for LV $LV_NAME." >&2
	exit 1
fi

# Resize partition
PARTITION=$(echo "$PV_NAME" | grep -o '[0-9]\+$')
parted --script "$DISK" resizepart "$PARTITION" 100% || {
	echo "Error: Failed to resize partition $PARTITION on $DISK." >&2
	exit 1
}

# Resize PV
pvresize "$PV_NAME" || {
	echo "Error: Failed to resize PV $PV_NAME." >&2
	exit 1
}

# Extend LV and resize filesystem
lvextend -l $CAPACITY "/dev/$VG_NAME/$LV_NAME" --resizefs || {
	echo "Error: Failed to extend LV $LV_NAME." >&2
	exit 1
}

echo "Successfully expanded LV $LV_NAME."
exit 0
