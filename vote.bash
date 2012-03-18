#!/bin/bash

user_list="userlist.txt"	# List of users who can vote.
candidate_list="candidates.txt"	# List of candidates.
num_votes_file="num_votes.txt"	# Number of votes each voter can cast.

vote_filename="vote.txt"	# File in which a user votes.
votes="votes"			# Directory where votes will be placed.
final_results="results.txt"	# Final results file name.

usage() {
	echo -e "ROSEdu vote script, version 0.1"
	echo
	echo -e "Usage: $0 [directory]"
	echo -e "If directory is omitted, the current directory is used."
	echo -e "Config files:"
	echo -e "* $user_list - list of local users who can vote;"
	echo -e "* $candidate_list - list of candidate IDs;"
	echo -e "  A candidate ID is not necessarily a valid username."
	echo -e "* $num_votes_file - contains a single number, which"
	echo -e "  is the number of votes each user can cast."
	echo
	echo -e "Each user votes in a file called $vote_filename in"
	echo -e "their home.  The script does some checks to ensure"
	echo -e "there are no invalid, double, or too few/many votes."
	echo
	echo -e "Results are placed in $final_results, with individual"
	echo -e "votes in $votes/.  There is no way that I know of to"
	echo -e "find out who voted for who."
	exit 0
}

if [ "x$1" == "x--help" ]; then
	usage
fi

# If a directory isn't specified, run in the current one.
if [ -n $1 ]; then
	cd $1
fi

if [ ! -f $user_list ] || [ ! -f $candidate_list ] || [ ! -f $num_votes_file ]
then
	echo -e "Please make sure that the following files exist:"
	echo -e "\t$user_list - list of the login names of all the voters"
	echo -e "\t$candidate_list - list of IDs of all the candidates"
	echo -e "\t$num_votes_file - file contains a single number, the"
	echo -e "\t  number of votes each user can cast"
	echo -e "Candidate IDs cannot contain whitespace and must be listed"
	echo -e "one per line."
	exit 1
fi

num_votes=$(cat $num_votes_file)
# Make sure it's really a number, taken from
# <http://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash>.
if ! [[ "$num_votes" =~ ^[0-9]+$ ]] ; then
	echo "$num_votes_file does not contain a valid number"
	exit 1
fi

if [ -d $votes ] || [ -f $final_results ]; then
	echo -e "Please make sure that neither the $votes directory "
	echo -e "nor the $final_results file exist.  This is where the "
	echo -e "results will be placed."
	exit 1
fi

# If any user has invalid votes, report in this global variable.
error=0

check_user_vote() {
	user=$1
	if ! getent passwd $user &> /dev/null; then
		echo "$user - user does not exist"
		error=1
		return
	fi

	home=$(getent passwd $user | cut -d: -f6)
	votefile=$home/$vote_filename
	if [ ! -f $votefile ]; then
		echo "$user - no vote file"
		error=1
		return
	fi

	# Check correct number of votes.
	# TODO should we warn when too few votes or not?
	count=$(cat $votefile | wc -l)
	if [ $count -gt $num_votes ]; then
		echo "$user - too many votes"
		error=1
		return
	fi
	if [ $count -lt $num_votes ]; then
		echo "$user - too few votes"
		error=1
		# But proceed, in case they also misspelled names.
	fi

	# Check that votes are actually listed candidates.
	for c in $(cat $votefile | sed 's/ //g'); do
		if ! grep -iq "^$c\$" $candidate_list; then
			echo "$user - has invalid vote"
			error=1
		fi
	done

	# Check that the user has not voted with same candidate twice.
	sorted_count=$(cat $votefile | sed 's/ //g' | sort | uniq | wc -l)
	if [ $count -ne $sorted_count ]; then
		echo "$user - voted for same person twice"
		error=1
	fi
}

for user in $(cat $user_list); do
	check_user_vote $user
done

if [ $error -eq 1 ]; then
	echo "Please fix the errors and rerun the script."
	exit 2
fi

# These are used to change ownership of the vote files.
run_user=$(whoami)
run_group=$(id -gn)

# Proceed to actually copy the votes files to the result directory.
mkdir $votes
for user in $(cat $user_list); do
	home=$(getent passwd $user | cut -d: -f6)
	votefile=$home/$vote_filename
	dest=$(mktemp -p $votes XXXXXX)
	mv $votefile $dest
	chown $run_user:$run_group $dest
	# Clean spaces from the votes and switch to lowercase, hoping to
	# minimize the misspellings and the like.
	sed -i -e 's/ //g' $dest
	# There is no way to do tr in place, this is ugly, but it works.
	tmp=$(mktemp)
	tr '[A-Z]' '[a-z]' < $dest > $tmp
	mv $tmp $dest
done

# Count'em!
cat $votes/* | sort | uniq -c | sort -rn > $final_results

echo -e "Final results are in $final_results"
