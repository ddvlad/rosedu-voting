#!/bin/bash

vote=../vote.bash
rundir=tmp

# Fake getent command.
export PATH="$PWD/bin:$PATH"

run_test() {
	dir=$1
	cp -r $dir $rundir
	echo "== Running $dir =="
	$vote $rundir/$dir
	if [ -f $rundir/$dir/results.txt ]; then
		echo "Final results:"
		cat $rundir/$dir/results.txt
	fi
	echo
}

rm -rf $rundir
mkdir $rundir

if ! [ -z $1 ]; then
	run_test $1
	exit 0
fi

for test in test-*; do
	run_test $test
done
