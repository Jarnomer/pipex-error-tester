# Small 42 Pipex tester by Jankku, based on script created by librity
# https://github.com/librity/ft_pipex/blob/master/scripts/compare.sh

R="\033[0;31m" # Red
G="\033[0;32m" # Green
Y="\033[0;33m" # yellow
B="\033[0;34m" # Blue
P="\033[0;35m" # Purple
C="\033[0;36m" # Cyan

RB="\033[1;31m" # Bold
GB="\033[1;32m"
YB="\033[1;33m"
BB="\033[1;34m"
PB="\033[1;35m"
CB="\033[1;36m"

RC="\033[0m" # Reset Color
FLL="========================="
FLLTITLE="========================"

run_pipex() {
	printf "${P}${FLL}${RC}${RB} PIPEX ${P}${FLL}${RC}\n"
	printf "${GB}Command:${RC} ./pipex $1 \"$2\" \"$3\" $4\n\n"
	printf "${BB}Output:\n${RC}"
	./pipex "$1" "$2" "$3" "$4"
	printf "${RC}\n${CB}Exit Code: ${RC}$?\n"
}

run_shell() {
	printf "${P}${FLL}${RC}${RB} SHELL ${P}${FLL}${RC}\n"
	printf "${GB}Command:${RC} < $1 $2 | $3 > $4\n\n"
	printf "${BB}Output:\n${RC}"
	eval "< $1 $2 | $3 > $4"
	printf "${RC}\n${CB}Exit Code: ${RC}$?\n"
}

show_diff() {
	printf "${P}${FLL}=${RC}${RB} DIFF ${P}${FLL}=${RC}\n"
	/usr/bin/diff "$1" "$2"
	printf "${RC}\n"
}

print_terminator() {
	printf "${P}${FLLTITLE}${RC} ${GB}FINISHED ${P}${FLLTITLE}${RC}\n\n"
	read -p "Continue?" -n 1 -r
}

print_title() {
	printf "\033c" #clear terminal
	printf "${P}${FLLTITLE}${RC}${GB} TEST $6 ${P}${FLLTITLE}${RC}\n"
	printf "\n${BB}TESTING:${RC}\t${C}$5${RC}\n"
	printf "$1\t$2\t$3\t$4${RC}\n"

}

print_main_title() {
	printf "\033c" #clear terminal
	printf "${P}${FLLTITLE}${FLLTITLE}=${RC}
${PB}|\t\t\t\t\t\t|
${PB}|${CB}\t     PIPEX TESTER BY JANKKU\t\t${PB}|
${PB}|\t\t\t\t\t\t|
${PB}|${RB}\t     TESTING ERROR HANDLING\t\t${PB}|
${PB}|\t\t\t\t\t\t|
${P}${FLLTITLE}${FLLTITLE}=${RC}\n\n"
}

compare() {
	run_pipex "$1" "$2" "$3" "$4"
	run_shell "$1" "$2" "$3" "$5"
	show_diff "$4" "$5"
	print_terminator
}

trap handle_ctrlc SIGINT
handle_ctrlc() {
	rm ${in1} ${out1} ${out2} ${bin1}
	exit
}

i=1
NAME=pipex
in1=infile
out1=outfile1
out2=outfile2
bin1=ppx_tmp

touch ${in1}
touch ${out1}
touch ${out2}

NAME=pipex
if [ -f "$NAME" ]; then
	print_main_title
	read -p "Continue?" -n 1 -r
else
	printf "${RB}ERROR: ${RC}${Y}binary <$NAME> not found${RC}"
	rm ${in1} ${out1} ${out2}
	exit
fi

cp pipex ${bin1}

print_title "${RB}☒ infile" "${GB}☑ command" "${GB}☑ command" "${GB}☑ outfile" \
			"INFILE DOES NOT EXIST\n" "$i"
compare noinfile "ls" "wc" ${out1} ${out2}

i=$((i+1))
print_title "${RB}☒ infile" "${RB}☒ command" "${GB}☑ command" "${GB}☑ outfile" \
			"INFILE DOES NOT EXIST, INVALID CMD1\n" "$i"
compare noinfile "xxx" "wc" ${out1} ${out2}

i=$((i+1))
chmod -r ${in1}

print_title "${RB}☒ infile" "${GB}☑ command" "${GB}☑ command" "${GB}☑ outfile" \
			"INFILE NO READ PERMISSION\n" "$i"
compare ${in1} "ls" "wc" ${out1} ${out2}

chmod +r ${in1}

chmod -w ${out1}
chmod -w ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${GB}☑ command" "${GB}☑ command" "${RB}☒ outfile" \
			"OUTFILE NO WRITE PERMISSION\n" "$i"
compare ${in1} "ls" "wc" ${out1} ${out2}

chmod +w ${out1}
chmod +w ${out2}

i=$((i+1))
chmod -x ${bin1}

print_title "${GB}☑ infile" "${RB}☒ command" "${GB}☑ command" "${GB}☑ outfile" \
			"NO EXEC PERMISSION CMD1\n" "$i"
compare ${in1} ./${bin1} "wc" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${GB}☑ command" "${RB}☒ command" "${GB}☑ outfile" \
			"NO EXEC PERMISSION CMD2\n" "$i"
compare ${in1} "wc" ./${bin1} ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${RB}☒ command" "${GB}☑ command" "${GB}☑ outfile" \
			"CMD1 IS FOLDER, VALID CMD2\n" "$i"
compare ${in1} "./libft/" "ls" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${GB}☑ command" "${RB}☒ command" "${GB}☑ outfile" \
			"VALID CMD1, CMD2 IS FOLDER\n" "$i"
compare ${in1} "ls" "./libft/" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${RB}☒ command" "${GB}☑ command" "${GB}☑ outfile" \
			"INFILE OK, INVALID CMD1\n" "$i"
compare ${in1} "xxx" "wc" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${RB}☒ command" "${GB}☑ command" "${GB}☑ outfile" \
			"INFILE OK, INVALID CMD1 (PATH)\n" "$i"
compare ${in1} "/xxx/xxx" "wc" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${GB}☑ command" "${RB}☒ command" "${GB}☑ outfile" \
			"INFILE OK, VALID CMD1, INVALID CMD2\n" "$i"
compare ${in1} "ls" "xxx" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${GB}☑ command" "${RB}☒ command" "${GB}☑ outfile" \
			"INFILE OK, VALID CMD1, INVALID CMD2 (PATH)\n" "$i"
compare ${in1} "ls" "/xxx/xxx" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${RB}☒ command" "${RB}☒ command" "${GB}☑ outfile" \
			"INVALID CMD1, INVALID CMD2 (PATH)\n" "$i"
compare ${in1} "xxx" "/xxx/xxx" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${RB}☒ command" "${GB}☑ command" "${GB}☑ outfile" \
			"NULL STRING CMD1" "$i"
run_pipex ${in1} "" "wc" ${out1}
run_shell ${in1} "''" "wc" ${out2}
show_diff ${out1} ${out2}
print_terminator

i=$((i+1))
print_title "${GB}☑ infile" "${GB}☑ command" "${RB}☒ command" "${GB}☑ outfile" \
			"EMPTY CMD2\n" "$i"
run_pipex ${in1} "ls" "     " ${out1}
run_shell ${in1} "ls" "'     '" ${out2}
show_diff ${out1} ${out2}
print_terminator

i=$((i+1))
print_title "${GB}☑ infile" "${RB}☒ command" "${RB}☒ command" "${GB}☑ outfile" \
			"NULL STRING CMD1, EMPTY CMD2\n" "$i"
run_pipex ${in1} "" "     " ${out1}
run_shell ${in1} "''" "'     '" ${out2}
show_diff ${out1} ${out2}
print_terminator

i=$((i+1))
print_title "${GB}☑ infile" "${RB}☒ command" "${GB}☑ command" "${GB}☑ outfile" \
			"BAD ARGS CMD1, VALID CMD2\n" "$i"
compare ${in1} "ls -?" "grep c" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${RB}☒ command" "${RB}☒ command" "${GB}☑ outfile" \
			"BAD ARGS CMD1, BAD ARGS CMD2\n" "$i"
compare ${in1} "ls -?" "wc -9001" ${out1} ${out2}

i=$((i+1))
old_PATH=$PATH
unset PATH

print_title "${GB}☑ infile" "${RB}☒ command" "${RB}☒ command" "${GB}☑ outfile" \
			"PATH ENVP DOES NOT EXIST\n" "$i"
compare ${in1} "ls" "wc" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${GB}☑ command" "${RB}☒ command" "${GB}☑ outfile" \
			"NO PATH ENVP, CMD1 (PATH)\n" "$i"
compare ${in1} "/bin/ls" "wc" ${out1} ${out2}

i=$((i+1))
print_title "${GB}☑ infile" "${GB}☑ command" "${GB}☑ command" "${GB}☑ outfile" \
			"NO PATH ENVP, CMD1 (PATH), CMD2 (PATH)\n" "$i"
compare ${in1} "/bin/ls" "/bin/cat" ${out1} ${out2}

export PATH="$old_PATH"

printf "${GB}\nALL TESTS FINISHED!\n${RC}"
rm ${in1} ${out1} ${out2} ${bin1}
