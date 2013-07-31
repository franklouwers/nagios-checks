#!/bin/bash
# bash script to check various components in an HP/H3C S5xxx switches

# Original by:
# lajo@kb.dk / 20120724

# Modified by:
# Frank Louwers frank@openminds.be / 20130731


# small rant:
# this script is exactly why I hate bash programming. You start with a 10 line script (which is fine in bash)
# but you end up adding complexity. And they you curse: why didn't I write this in perl/ruby/python/... in the first place?

# TODO: rewrite in perl/ruby/python/...

CHECKPSU=1
CHECKIRF=1

if [ $# -lt 2 -o $# -gt 4 ]; then
	echo "Usage: $0 host community [stackmembers [PSUs]]"
	echo "   Stackmembers: will check if there are N active stack/irf members."
	echo "                 If you omit this parameter or set it to 0, we won't check stack/irf"
	echo "   PSUS:         will check if there are N PSUs."
	echo "                 If you omit this parameter, we won't check power supplies"
	exit 1
fi

if [ $# -lt 4 ]; then
	CHECKPSU=0
fi

if [ $# -lt 3 ]; then
	CHECKIRF=0
fi

HOST=$1
COMMUNITY=$2
NUMIRFMEMBERS=$3
NUMPSUS=$4

if [ "x$NUMIRFMEMBERS" == "x0" ]; then
	CHECKIRF=0
fi


statustext[1]="Not Supported"
statustext[3]="POST Failure"
statustext[11]="PoE Error"
statustext[22]="Stack Port Blocked"
statustext[23]="Stack Port Failed"
statustext[31]="SFP Recieve Error"
statustext[32]="SFP Send Error"
statustext[33]="SFP Send and Receive Error"
statustext[41]="Fan Error"
statustext[51]="Power Supply Error"
statustext[61]="RPS Error"
statustext[71]="Module Faulty"
statustext[81]="Sensor Error"
statustext[91]="Hardware Faulty"

# Make the array separate on newlines only.
IFS='
'
component=( $( snmpwalk -v2c -OEqv -c $COMMUNITY $HOST .1.3.6.1.2.1.47.1.1.1.1.2 2>/dev/null) )
if [ $? -ne 0 ]; then
  echo "UNKNOWN: SNMP timeout"
  exit 3
fi
status=( $( snmpwalk -v2c -OEqv -c $COMMUNITY $HOST .1.3.6.1.4.1.25506.2.6.1.1.1.1.19 2>/dev/null) )
if [ $? -ne 0 ]; then
  echo "UNKNOWN: SNMP timeout"
  exit 3
fi

errors=0
psus=0
msg=''

for (( i = 0 ; i < ${#component[@]} ; i++ )) do
  # Don't check for "OK" and "SFP Receive Error". The latter triggers an inserted
  # SFP without link which may be a typical situation for many.
  if [ ${status[$i]} -ne 2 ]; then
    # Strip out quotes from the component description
    s=${component[$i]}
    msg="${msg}${s//\"}: ${statustext[${status[$i]}]} - "
    errors=1
  fi
  if [[ ${component[$i]} =~ "Power Supply Unit" ]]; then
    ((psus++))
  fi
  if [[ ${component[$i]} =~ "PSU" ]]; then
    ((psus++))
  fi
done


if [ $CHECKIRF -eq 1 ]; then
	## Extra check: we need $IRFMEMBERS members in the irf stack
	status=( $( snmpwalk -v2c -OEqv -c $COMMUNITY $HOST .1.3.6.1.4.1.25506.2.91.1.2.0  2>/dev/null) )
	if [ $? -ne 0 ]; then
	  echo "UNKNOWN: SNMP timeout"
	  exit 3
	fi

	if [ $status -ne $NUMIRFMEMBERS ]; then
	   msg="${msg}IRF members: $status != $NUMIRFMEMBERS - "
	   errors=1
	fi
fi
 

## Extra check: we need $PSUS power supplies
if [ $CHECKPSU -eq 1 ]; then
	if [ $psus -ne $NUMPSUS ]; then
	  msg="${msg}PSUs: $psus != $NUMPSUS - "
	  errors=1
	fi
fi


if [ $errors -gt 0 ]; then
  msg=`echo $msg | sed 's/- $//'`
  echo "CRITICAL: $msg"
  exit 2
else
  echo "OK: All components OK"
fi
