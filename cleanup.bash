#!/bin/bash

user_list="userlist.txt"	# List of users who can vote.
vote_filename="vote.txt"	# File in which a user votes.

if ! [ -f $user_list ]; then
	echo "$user_list not found."
	exit 1
fi

for user in $(cat $user_list); do
	home=$(getent passwd $user | cut -d: -f6)
	votefile=$home/$vote_filename
	if [ -f $votefile ]; then
		echo "Existing votefile for user $user removed."
		rm -f $votefile
	fi
done

echo "All vote files deleted."
