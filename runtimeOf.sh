if [[ -z $1 ]]
then
	echo "Usage:"
	echo "runtimeOf.sh <testname> [<engine>]"
else
	find PR-*/ -maxdepth 1 -iname '*_Regress_'"$2"'*' -type f -exec egrep 'Pass '"$1" '{}' \;
fi
echo "End."

