# pipex-error-tester

Small tester for 42 pipex error handling based on script created by librity. 

https://github.com/librity/ft_pipex/blob/master/scripts/compare.sh

Designed just for mandatory part but same principles should apply for bonus part.

Compares against bash. Shows both outputs and exit codes as well as outfile diff.

Currently does not test if child process is signaled for example by segfault.

Tests:

- No infile
- No infile read permission
- No outfile write permission
- Invalid commands
- Invalid commands (w path)
- Invalid command arguments
- Null string command
- Empty command
- Command is a directory
- No permission to execute command
- No PATH environmental variable
