#!/bin/bash

[ -n "$BASH_VERSION" ] || exit 1

work() {
  local id="$1"
  local param="$2"
  local lv=user-data/vm-"$id"-disk-0
  local conf="$(find /etc/pve/nodes -name "$id.conf")"
  local mnt=/tmp/mnt-"$id"
  mkdir -p "$mnt"
  local list="$mnt"/etc/apt/sources.list
  echo "******************** WORKING ON VM ID $id ($param remaining) ********************"
  lvchange -y -ay "$lv"
  tune2fs -f -E clear_mmp /dev/"$lv"
  #e2fsck -y -f /dev/"$lv" || true
  mount /dev/"$lv" "$mnt"
  if [ -f "$list" ]; then
    sed -i 's/mirrors\.tuna\.tsinghua\.edu\.cn/mirrors.ustc.edu.cn/g' "$list" &&
      echo "Run sed on CT $id"
  else
    echo "CT $id does not contain /etc/apt/sources.list"
  fi
  local size="$(df -BM --output=size "$mnt" | awk 'NR==2{print $1+0}')"
  local used="$(df -BM --output=used "$mnt" | awk 'NR==2{print $1+0}')"
  echo "Size of VM $id: ${used}M / ${size}M"
  umount "$mnt"
  if [ $used -gt 0 -a $used -lt 12288 ]; then
    echo "Shrinking VM $id to 16G"
    tune2fs -f -E clear_mmp /dev/"$lv"
    e2fsck -y -f /dev/"$lv"
    resize2fs -p /dev/"$lv" 15G
    lvresize -y -f -L 16G "$lv" || true
    tune2fs -f -E clear_mmp /dev/"$lv"
    resize2fs -p /dev/"$lv"
    test -n "$conf" && sed -i '/^rootfs:/s/size=[0-9]\+G/size=16G/' "$conf"
  elif [ $used -ge 12288 -a $used -lt 24576 -a $size -gt 32768 ]; then
    echo "Shrinking VM $id to 32G"
    tune2fs -f -E clear_mmp /dev/"$lv"
    e2fsck -y -f /dev/"$lv"
    resize2fs -p /dev/"$lv" 31G
    lvresize -y -f -L 32G "$lv" || true
    tune2fs -f -E clear_mmp /dev/"$lv"
    resize2fs -p /dev/"$lv"
    test -n "$conf" && sed -i '/^rootfs:/s/size=[0-9]\+G/size=32G/' "$conf"
  fi
  lvchange -y -an "$lv"
}

total=$(<${1:-disks.txt} wc -l)
for id in $(<"${1:-disks.txt}"); do
  work "$id" "$((total-=1))"
done
