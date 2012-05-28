#!/bin/bash
# Auto-download Google Reader Starred ImageBoard feed items
# Set Google Reader Mobile item number to 20 a page

# Tested on Bash 4.2 on Mac OS X 10.7.4
# Results may vary depending on the version of `sed` you have

# TODO : Unstar image after successful download

READER_DIR="http://www.google.com/reader/m/view/user/-/state/com.google/starred"

NOTIFY=growlnotify
DOWNLOAD_DIR=~/Downloads

SVC="reader"
. auth

echo -n "Checking Google Reader "
list=""; num_post=0
for po in $( curl -s -H 'Authorization: GoogleLogin auth='"${AUTH}" "$READER_DIR" | grep 'dir="ltr"' | sed 's/.*href="\(.*\)&amp.*/\1/' ); do
	content=$( curl -s -H 'Authorization: GoogleLogin auth='"${AUTH}" "$po" )
	ibl=$( grep -G "/post/show/.*_blank" <<< "$content" | sed 's/.*href="\(http.*\)" target.*/\1/' )
	if [ -n "$ibl" ]; then
		list=$list$ibl$'\n' #'
		(( num_post++ ))
		echo -n "o"
		# $( grep Remove.star <<< "$content" | sed 's/.*href="\(.*\)" accesskey.*/\1/' )
	else
		echo -n "."
	fi
done && echo
echo "Imageboard posts found: $num_post"
[ $num_post -eq 0 ] && exit 0

echo "Last image: $( tail -n 2 <<< "$list" )"
echo
echo "Fetching image links... "
dld=""; num_dld=0
for ib in $( sort <<< "$list" | uniq ); do
	echo -n "$ib... "
	content="$( wget -q -O - "$ib" )"
	pre=$( grep -G "a href=.*/image/.*class" <<< "$content" | sed -e 's/.*\(http.*\)/\1/' -e 's/\([^"]*\).*/\1/' | grep -v "sample" | uniq )
	if [ -n "$pre" ]; then
		dld[$(( num_dld*2 ))]=$ib; dld[$(( num_dld*2+1 ))]=$pre
		(( num_dld++ ))
		echo "exists."
	else
		reason="$( sed -n '/status-notice/{n;p;n;n;n;n;p;}' <<< "$content" | grep Reason | sed  's/.*Reason:\(.*\) MD5.*/\1/' )"
		echo "was deleted. Reason:${reason}"
		alt_source="$( grep "Source: " <<< "$content" | sed 's/.*a href="\([^"]*\)" target.*/\1/' )" #'
		[ -n "$alt_source" ] && echo "Source: $alt_source"
	fi
done

[ $num_dld -eq 0 ] && exit 0

cd $DOWNLOAD_DIR
echo -n "Downloading $num_dld Image"
if [ $num_dld -gt 1 ]; then echo "s"; else echo; fi
for (( a=0, b=1; a<num_dld*2; a+=2, b+=2 )) do echo -n "[`date +%R`] ${dld[$a]}... " && wget -q ${dld[$b]} && echo "Ok"; done

if [ "$NOTIFY" == "growlnotify" ]; then
	growlnotify "Google Reader Imageboards" -m "Done downloading" --image ~/Pictures/icons/GoogleReader.icns -n "Google Reader ImageBoards"
fi