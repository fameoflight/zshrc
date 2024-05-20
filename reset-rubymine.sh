# Reset RubyMine evaluation period
# Note, this resets your configurations as well

function findprocess () {
	ps aux | grep --color=auto -i $1 | grep --color=auto -v grep
}
function killgrep () {
	cnt=$( find-process $1 | wc -l)
	echo -e "\nSearching for '$1' -- Found" $cnt "Running Processes .. "
	findprocess $1
	echo -e '\nTerminating' $cnt 'processes .. '
	ps aux | grep --color=auto -i $1 | grep --color=auto -v grep | awk '{print $2}' | xargs kill -9
	echo -e "Done!\n"
	echo "Running search again:"
	find-process "$1"
	echo -e "\n"
}

killgrep "rubymine"
rm -rf ~/Library/Preferences/RubyMine*

rm -rf ~/Library/Caches/RubyMine*

rm -rf ~/Library/Application\ Support/RubyMine*

rm -rf ~/Library/Logs/RubyMine*
