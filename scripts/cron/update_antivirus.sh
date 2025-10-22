#!/bin/bash

SRCDIR=`grep 'SRCDIR' /etc/mailcleaner.conf | cut -d ' ' -f3`
if [ "$SRCDIR" = "" ]; then
  SRCDIR=/usr/mailcleaner
fi

VARDIR=`grep 'VARDIR' /etc/mailcleaner.conf | cut -d ' ' -f3`
if [ "$VARDIR" = "" ]; then
  VARDIR=/var/mailcleaner
fi

SNAPSHOTHOST="https://mailcleanerdl.alinto.net"
SNAPSHOTPATH="/downloads/clamav-sigs.tgz"

. $SRCDIR/lib/lib_utils.sh
FILE_NAME=$(basename -- "$0")
FILE_NAME="${FILE_NAME%.*}"
RET=$(createLockFile "$FILE_NAME")
if [[ "$ret" -eq "1" ]]; then
  exit 0
fi

cd $VARDIR/spool/clamav/

if [ -f "$VARDIR/spool/clamav/main.cvd" ]; then
  echo "["`date "+%Y-%m-%d %H:%M:%S"`"] Already have final signature database snapshot." >> $VARDIR/log/clamav/freshclam.log
else
  echo "["`date "+%Y-%m-%d %H:%M:%S"`"] Downloading final signature database snapshot." >> $VARDIR/log/clamav/freshclam.log

  echo "["`date "+%Y-%m-%d %H:%M:%S"`"] Downloading $SNAPSHOTHOST$SNAPSHOTPATH" >> $VARDIR/log/clamav/freshclam.log
  curl --insecure --fail --compressed --connect-timeout "60" --remote-time --location --retry "0" --output $VARDIR/spool/clamav/clamav-sigs.tgz $SNAPSHOTHOST$SNAPSHOTPATH  2>&1 >> $VARDIR/log/clamav/freshclam.log
  RET=$?
  if [[ "$RET" -eq "0" ]]; then
    echo "["`date "+%Y-%m-%d %H:%M:%S"`"] Extracting clamav-sigs.tgz" >> $VARDIR/log/clamav/freshclam.log
    tar -xzf clamav-sigs.tgz
    chown -R clamav:clamav $VARDIR/spool/clamav/
    rm clamav-sigs.tgz
  else
    echo "["`date "+%Y-%m-%d %H:%M:%S"`"] Failed to download $SNAPSHOTHOST$SNAPSHOTPATH code ($RET)" >> $VARDIR/log/clamav/freshclam.log
  fi
fi

if [ -e $VARDIR/spool/mailcleaner/clamav-unofficial-sigs ]; then
   if [[ "$(shasum $VARDIR/spool/mailcleaner/clamav-unofficial-sigs | cut -d' ' -f1)" == "69c58585c04b136a3694b9546b77bcc414b52b12" ]]; then
      if [ ! -e $VARDIR/spool/clamav/unofficial-sigs ]; then
         echo "Installing Unofficial Signatures..." >> $VARDIR/log/clamav/freshclam.log
         mkdir $VARDIR/spool/clamav/unofficial-sigs
         /bin/chown clamav:clamav -R $VARDIR/spool/clamav/unofficial-sigs
         $SRCDIR/scripts/cron/clamav-unofficial-sigs.sh --force >> $VARDIR/log/clamav/freshclam.log
      else
         echo "Updating Unofficial Signatures..." >> $VARDIR/log/clamav/freshclam.log
         $SRCDIR/scripts/cron/clamav-unofficial-sigs.sh --update >> $VARDIR/log/clamav/freshclam.log
      fi
   else
      echo "$VARDIR/spool/mailcleaner/clamav-unofficial-sigs exists but does not contain the correct information. Please enter exactly:"
      echo "I have read the terms of use at: https://sanesecurity.com/usage/linux-scripts/"
   fi
fi

echo "["`date "+%Y-%m-%d %H:%M:%S"`"] Done." >> $VARDIR/log/clamav/freshclam.log
removeLockFile "$FILE_NAME"
