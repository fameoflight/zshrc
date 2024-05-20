#!/usr/bin/env bash
testfiles=$(python test_files.py | sort | awk "NR % ${CIRCLE_NODE_TOTAL} == ${CIRCLE_NODE_INDEX}")

echo $testfiles

if [ -z "$testfiles" ]
then
    echo "no tests to run on this machine"
else
    cd app && export LD_LIBRARY_PATH=../symmetry-cffi/lib/current/ste-shared-libraries && py.test $testfiles
    OUT=$?
    if [ $OUT -eq 0 ] ||  [ $OUT -eq 5 ]; then
       exit 0
    else
       exit $OUT
    fi
fi
