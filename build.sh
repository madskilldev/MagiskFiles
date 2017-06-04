#!/bin/bash

export GIT_EDITOR=true
export GIT_MERGE_AUTOEDIT=no

APKFILE='app-debug.apk'
CMP="diff --quiet --ignore-submodules=dirty @{upstream}"
MAGISKVER='13'
MAGISKMANVER='5.0'
verCode="$(date +%y%m%d)"
[[ "$(uname -a)" =~ "Darwin" ]] && repl_command="sed -i ''" || repl_command="sed -i"

ok() { echo -e '\033[0;32m[\xe2\x9c\x93]\033[0m'; }
fail() { echo -e '\033[0;31m[\xe2\x9c\x97]\033[0m'; }

edit_magisk_files() { 
$repl_command "s|topjohnwu/MagiskManager/update/|kantjer/MagiskFiles/master/updates/|" Magisk/MagiskManager/app/src/main/java/com/topjohnwu/magisk/asyncs/CheckUpdates.java && \
$repl_command "s/versionName \".*\"/versionName \"${MAGISKMANVER}.${verCode}\"/" Magisk/MagiskManager/app/build.gradle && \
$repl_command "s/showthread.php?t=3432382/showthread.php?t=3521901/" Magisk/MagiskManager/app/src/main/java/com/topjohnwu/magisk/AboutActivity.java && return 0 || return 1; }

update_updates() {
	if [ -f Magisk-v${MAGISKVER}-${verCode}.zip ]; then
cat << EOF > updates/magisk_update.json
{
  "app": {
    "version": "stub",
    "versionCode": "10",
    "link": "https://github.com/topjohnwu/MagiskManager/releases/download/v3.0/MagiskManager-stub.apk",
    "changelog": "  - Upgrade on Play Store!"
  },
  "magisk": {
    "version": "${MAGISKVER}.${verCode}",
    "versionCode": "${verCode}",
    "link": "https://raw.githubusercontent.com/kantjer/MagiskFiles/master/Magisk-v${MAGISKVER}-${verCode}.zip",
    "changelog": "Check the link",
    "note": "https://forum.xda-developers.com/showthread.php?t=3521901"
  },
  "uninstall": {
    "filename": "Magisk-v${MAGISKVER}-${verCode}-Uninstaller.zip",
    "link": "https://raw.githubusercontent.com/kantjer/MagiskFiles/master/Magisk-v${MAGISKVER}-${verCode}-Uninstaller.zip"
  }
}
EOF
	fi

	if [ -f MagiskManager-v${MAGISKMANVER}-${verCode}.apk ]; then
cat << EOF > updates/magisk_manager_update.txt
lastest_version=${verCode}
apk_file=MagiskManager-v${MAGISKMANVER}-${verCode}.apk
download_url=https://raw.githubusercontent.com/kantjer/MagiskFiles/master/\$apk_file
EOF
	fi
}

signapp() {
	echo -n "Signing  MagiskManager-v${MAGISKMANVER}-${verCode}.apk...	"
	if [ -f MagiskManager/app/build/outputs/apk/${APKFILE} ]; then
		java -jar Java/signapk.jar MagiskManager/app/src/main/assets/public.certificate.x509.pem MagiskManager/app/src/main/assets/private.key.pk8 MagiskManager/app/build/outputs/apk/${APKFILE} MagiskManager-v${MAGISKMANVER}-${verCode}.apk
		rm -f MagiskManager/app/build/outputs/apk/${APKFILE}
		ok
	else
		fail
	fi
}

checkorigin() {
echo -n "Checking for origin updates...			"; git fetch >/dev/null 2>&1 && ok || fail
if ! git ${CMP}; then 
	echo -n "Updating local files from origin repo...	"
	git pull origin master && git reset --hard HEAD >/dev/null 2>&1 && git push origin master && ok || fail
	echo "Running build.sh again."
	./build.sh
	exit 0
else
	echo "No origin updates found."
fi
}

cleanup() {
	git -C Magisk reset --hard HEAD >/dev/null 2>&1
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
	
	cd "${0%/*}"
    trap cleanup EXIT

	start=$(date +%s.%N)
	[ "$1" == "-i" ] && { ignore_origin=1; shift; }
	
	case $1 in
		cleanup)
			cleanup;;
		setup)
			echo -e -n ".DS_Store\nMagisk\n" >> .git/info/exclude
			rm -rf Magisk >/dev/null 2>&1
			git clone --recursive https://github.com/topjohnwu/Magisk.git
			;;
		sign)
			signapp;;
		*)
			[ -z "$ignore_origin" ] && checkorigin
			echo -n "Checking for @topjohnwu updates...		"; git -C Magisk fetch >/dev/null 2>&1 && ok || fail
	
			if ! git -C Magisk ${CMP} || [ -n "$1" ]; then 
				rebuild=1; 
			fi
	
			if [ -n "$rebuild" ]; then
				if [ -z "$1" ] && ! git -C Magisk ${CMP}; then
					echo -e -n "Updating Magisk...				" && s=0
					git -C Magisk fetch >/dev/null 2>&1 || s=1
					git -C Magisk reset --hard origin/master >/dev/null 2>&1 || s=1
					git -C Magisk pull --recurse-submodules >/dev/null 2>&1 || s=1
					git -C Magisk submodule update --recursive >/dev/null 2>&1 || s=1
					[ "$s" -eq "0" ] && ok || fail
				fi
				echo -e -n "Editing  Magisk files...			" && git -C Magisk checkout master >/dev/null 2>&1 && edit_magisk_files && ok || fail
				echo -e -n "Building Magisk and Magisk Manager...		"
				(cd Magisk; ./build.py clean >/dev/null 2>&1; ./build.py all ${MAGISKVER}.${verCode} ${verCode} >/dev/null 2>&1;)
				[[ -f Magisk/Magisk-v${MAGISKVER}.${verCode}.zip && -f Magisk/Magisk-uninstaller-20${verCode}.zip && -f Magisk/MagiskManager/app/build/outputs/apk/${APKFILE} ]] && ok || fail
				echo -e -n "Moving   Magisk-v${MAGISKVER}-${verCode}.zip...		"
				[ -f Magisk/Magisk-v${MAGISKVER}.${verCode}.zip ] && { ok; mv Magisk/Magisk-v${MAGISKVER}.${verCode}.zip Magisk-v${MAGISKVER}-${verCode}.zip; } || fail
				echo -e -n "Moving   Magisk-uninstaller-${verCode}.zip...	"
				(cd Magisk; ./build.sh uninstaller >/dev/null 2>&1;)
				[ -f Magisk/Magisk-uninstaller-20${verCode}.zip ] && { ok; mv Magisk/Magisk-uninstaller-20${verCode}.zip Magisk-v${MAGISKVER}-${verCode}-Uninstaller.zip; } || fail
				echo -e -n "Moving   MagiskManager-v${MAGISKMANVER}-${verCode}.apk...	"
				[ -f Magisk/MagiskManager/app/build/outputs/apk/${APKFILE} ] && { ok; mv Magisk/MagiskManager/app/build/outputs/apk/${APKFILE} MagiskManager-v${MAGISKMANVER}-${verCode}.apk; } || fail
				git -C Magisk reset --hard HEAD >/dev/null 2>&1
				updates=1
			fi
			
			keep=5
			if [[ `ls MagiskManager-v[0-9].[0-9]-[1-2][0-9][0-9][0-9][0-9][0-9].apk 2>/dev/null | wc -l` != "0" ]]; then
				find . -maxdepth 1 -name 'MagiskManager-v[0-9].[0-9]-[1-2][0-9][0-9][0-9][0-9][0-9].apk' -type f -printf '%T@@%p\0' |
				tr '\0\n' '\n\0' | sort -rn | tail -n "+$(($keep+1))" |
				cut -d @ -f2- | tr  '\0\n' '\n\0' | xargs -r0 rm -f
			fi
	
			if [[ `ls Magisk-v[0-9][0-9]-[1-2][0-9][0-9][0-9][0-9][0-9]-Uninstaller.zip 2>/dev/null | wc -l` != "0" ]]; then
				find . -maxdepth 1 -name 'Magisk-v[0-9][0-9]-[1-2][0-9][0-9][0-9][0-9][0-9]-Uninstaller.zip' -type f -printf '%T@@%p\0' |
				tr '\0\n' '\n\0' | sort -rn | tail -n "+$(($keep+1))" |
				cut -d @ -f2- | tr  '\0\n' '\n\0' | xargs -r0 rm -f
			fi
	
			if [[ `ls Magisk-v[0-9][0-9]-[1-2][0-9][0-9][0-9][0-9][0-9].zip 2>/dev/null | wc -l` != "0" ]]; then
				find . -maxdepth 1 -name 'Magisk-v[0-9][0-9]-[1-2][0-9][0-9][0-9][0-9][0-9].zip' -type f -printf '%T@@%p\0' |
				tr '\0\n' '\n\0' | sort -rn | tail -n "+$(($keep+1))" |
				cut -d @ -f2- | tr  '\0\n' '\n\0' | xargs -r0 rm -f
			fi
	
			if [ -n "$updates" ]; then
				echo -e -n "Updating update files...			" && update_updates && ok || fail
				echo -e -n "Pushing new files to github.com/kantjer...	"
				git add . && git commit -m "$verCode build" >/dev/null 2>&1 && git push origin >/dev/null 2>&1 && ok || fail
			fi
			;;
	esac
	
fi
