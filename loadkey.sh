#!/bin/bash
# Load ssh key for bash command

### Create ssh environment
SSH_ENV="$HOME/.ssh/environment"

### binary
SSH_AGENT=`which ssh-agent`
SSH_ADD=`which ssh-add`
RM=`which rm`
KILL=`which kill`
BASH=`which bash`

### Initialize colours text
GREEN="\\033[1;32m"
YELLOW="\\033[1;33m"
RED="\\033[1;31m"
NORMAL="\\033[0;39m"

### FUNCTION start_agent
function start_agent {
     $SSH_AGENT | sed 's/^echo/#echo/' > "${SSH_ENV}"
     echo -e "$NORMAL""Initialise new SSH agent [""$GREEN""OK""$NORMAL""]"
     chmod 600 "${SSH_ENV}"
     . "${SSH_ENV}" > /dev/null
     echo -e "$NORMAL""Load SSH Key $KEY"
     $SSH_ADD $KEY;
     RETVAL=$?
     [ $RETVAL -eq 0 ] && MSG="$GREEN""OK""$NORMAL"
     [ $RETVAL -ne 0 ] && MSG="$RED""Fail""$NORMAL"
     echo -e "$NORMAL""SSH Key $KEY loading [$MSG]"
     $BASH -i
}

### Retrieve value
while getopts ":k:" opt; do
  case $opt in
    k)
      KEY=$OPTARG >&2
      break
      ;;
    *)
      KEY="" >&2
      ;;
  esac
done


### Execute SSH agent
if [ -f "${SSH_ENV}" ]; then
     . "${SSH_ENV}" > /dev/null
     ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null && {
         $RM ${SSH_ENV}
         $KILL ${SSH_AGENT_PID}
     }
fi

## Execute Function
start_agent