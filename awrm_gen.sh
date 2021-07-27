#!/bin/bash
#================================================================================
# Name:	awrm_gen.sh
# Type:	bash script
# Date:	07-July 2021
# From: Customer Architecture & Engineering (CAE) - Microsoft
#
# Copyright and license:
#
#       Licensed under the Apache License, Version 2.0 (the "License"); you may
#       not use this file except in compliance with the License.
#
#       You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#       Unless required by applicable law or agreed to in writing, software
#       distributed under the License is distributed on an "AS IS" basis,
#       WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
#       See the License for the specific language governing permissions and
#       limitations under the License.
#
#       Copyright (c) 2021 by Microsoft.  All rights reserved.
#
# Ownership and responsibility:
#
#       This script is offered without warranty by Microsoft Customer Engineering.
#       Anyone using this script accepts full responsibility for use, effect,
#       and maintenance.  Please do not contact Microsoft support unless there
#       is a problem with a supported Azure component used in this script,
#       such as an "az" command.
#
# Description:
#
#	Script to extract data for VM sizing from an AWR Miner v5.0.8 dump into
#	Oracle database tables and rows for analysis.
#
# Command-line Parameters:
#
#	(none)
#
# Expected output:
#
#
#
# Usage notes:
#
#
# Modifications:
#	TGorman	07jul21	v1.0	written
#================================================================================
#
#--------------------------------------------------------------------------------
#--------------------------------------------------------------------------------
_sqlFile=./awrm_gen.sql
_csvFile=./awrm_gen.csv
#
#--------------------------------------------------------------------------------
# First, spool the DDL code to the SQL*Plus script to drop and recreate the
# AWR_MINER_xxxx tables...
#--------------------------------------------------------------------------------
cat << __EOF1__ > ${_sqlFile}
whenever oserror exit failure rollback
set echo on feedback on timing on
spool awrm_gen
drop table awr_miner_info purge;
drop table awr_miner_disk purge;
drop table awr_miner_mem purge;
drop table awr_miner_load purge;
drop table awr_miner_parm purge;
drop table awr_miner_metrics purge;

whenever sqlerror exit failure rollback
create table awr_miner_info
(
	db_name		varchar2(32)	not null,
	db_hosts	varchar2(64)	not null,
	nbr_instances	number(2)	not null,
	nbr_vcpus	number(4)	not null,
	nbr_cores	number(4)	not null,
	phys_mem	number		not null,
	platform	varchar2(32)	not null,
	db_version	varchar2(32)	not null,
	run_module	varchar2(32)	not null,
	awr_miner_vers	varchar2(32)	not null
);
create table awr_miner_disk
(
	db_name		varchar2(32)	not null,
	gib		number		not null,
	max_gib		number		not null
);
create table awr_miner_mem
(
	db_name		varchar2(32)	not null,
	inst_id		number(2)	not null,
	gib		number		not null
);
create table awr_miner_load
(
	db_name		varchar2(32)	not null,
	inst_id		number(2)	not null,
	snap		number(10)	not null,
	load_avg	number		not null
);
create table awr_miner_parm
(
	db_name		varchar2(32)	not null,
	name		varchar2(32)	not null,
	value		varchar2(32)	not null
);
create table awr_miner_metrics
(
	db_name		varchar2(32)	not null,
	inst_id		number(2)	not null,
	dur_mins	number		    null,
	snap		number(10)	not null,
	aas		number		not null,
	aas_sd		number		not null,
	aas_max		number		not null,
	db_time		number		not null,
	db_time_sd	number		not null,
	read_mbps	number		not null,
	read_mbps_max	number		not null,
	read_iops	number		not null,
	read_iops_max	number		not null,
	write_mbps	number		not null,
	write_mbps_max	number		not null,
	write_iops	number		not null,
	write_iops_max	number		not null,
	redo_mbps	number		not null
);

__EOF1__
#
for _f in $(ls -1 ./awr-hist-*.out)
do
	#
	echo "" >> ${_sqlFile}
	echo "REM " >> ${_sqlFile}
	echo "REM processing AWR Miner dump file \"${_f}\"..." >> ${_sqlFile}
	echo "REM " >> ${_sqlFile}
	#
	declare -a _sections=(	"OS-INFORMATION" "PATCH-HISTORY" "MODULE" "SNAP-HISTORY" "MEMORY" "MEMORY-SGA-ADVICE" "MEMORY-PGA-ADVICE"
				"SIZE-ON-DISK" "OSSTAT" "MAIN-METRICS" "DATABASE-PARAMETERS" "AVERAGE-ACTIVE-SESSIONS" "IO-WAIT-HISTOGRAM"
				"IO-OBJECT-TYPE" "IOSTAT-BY-FUNCTION" "TOP-N-TIMED-EVENTS" "SYSSTAT")
	_currentSection=""
	_maxSzOnDiskGiB=0.0
	_prevSecs[0]=0; _prevSecs[1]=0; _prevSecs[2]=0; _prevSecs[3]=0; _prevSecs[4]=0; 
	_prevSecs[5]=0; _prevSecs[6]=0; _prevSecs[7]=0; _prevSecs[8]=0
	_tmpFile=/tmp/.awrm_gen_$$.txt
	#
	sed -e '/^[[:space:]]*$/d' -e '/^----*/d' -e '/^Elapsed: /d' -e '/^#/d' ${_f} > ${_tmpFile}
	while read _Line
	do
		#
		if [[ "${_Line}" =~ ^~~BEGIN-.*$ ]]
		then
			if [[ "${_currentSection}" = "" ]]
			then
				for _s in "${_sections[@]}"
				do
					if [[ "${_Line}" = "~~BEGIN-${_s}~~" ]]
					then
						_currentSection=${_s}
						typeset -i _l=0
						break
					fi
				done
			fi
		else
			if [[ ${_Line} =~ ^~~END-.*$ ]]
			then
				_currentSection=""
			fi
		fi
		#
		if (( ${_l} > 1 ))
		then
			case "${_currentSection}" in
				"OS-INFORMATION")	case "`echo ${_Line} | awk '{print $1}'`" in
								"NUM_CPUS")		_numCpus="`echo ${_Line} | awk '{print $2}'`" ;;
								"NUM_CPU_CORES")	_numCpuCores="`echo ${_Line} | awk '{print $2}'`" ;;
								"PHYSICAL_MEMORY_GB")	_physMemGiB="`echo ${_Line} | awk '{print $2}'`" ;;
								"PLATFORM_NAME")	_platformName="`echo ${_Line} | awk '{print $2}'`" ;;
								"VERSION")		_dbVersion="`echo ${_Line} | awk '{print $2}'`" ;;
								"DB_NAME")		_dbName="`echo ${_Line} | awk '{print $2}'`" ;;
								"INSTANCES")		_dbNumInstances="`echo ${_Line} | awk '{print $2}'`" ;;
								"HOSTS")		_dbHosts="`echo ${_Line} | awk '{print $2}'`" ;;
								"MODULE")		_runModule="`echo ${_Line} | awk '{print $2}'`" ;;
								"AWR_MINER_VER")	_awrMinerVersion="`echo ${_Line} | awk '{print $2}'`" ;;
								*) ;;
							esac
							;;
				"MEMORY")		typeset -i _inst=`echo ${_Line} | awk '{print $2}'`
							echo "insert into awr_miner_mem values ('${_dbName}',${_inst},`echo ${_Line} | awk '{printf("%.02f\n",($3+$4))}'`);" >> ${_sqlFile}
							;;
				"SIZE-ON-DISK")		_szOnDiskGiB=`echo ${_Line} | awk '{printf("%.02f\n",$2)}'`
							if [[ "`echo ${_szOnDiskGiB} ${_maxSzOnDiskGiB} | awk '{if($1>$2){print "GT"}}'`" = "GT" ]]
							then
								_maxSzOnDiskGiB=${_szOnDiskGiB}
							fi
							;;
				"OSSTAT")		typeset -i _inst=`echo ${_Line} | awk '{print $2}'`
							echo "insert into awr_miner_load values ('${_dbName}',${_inst},`echo ${_Line} | awk '{printf("%d,%.02f\n",$1,$3)}'`);" >> ${_sqlFile}
							;;
				"MAIN-METRICS")		typeset -i _inst=`echo ${_Line} | awk '{print $5}'`
							_endDtTm=`echo ${_Line} | awk '{print $3" "$4}'`
							typeset -i _secs=`date --date="20${_endDtTm}" '+%s'`
							if (( ${_prevSecs[${_inst}]} > 0 ))
							then
								_x=`echo ${_secs} ${_prevSecs[${_inst}]} | awk '{printf("%.02f\n",($1-$2)/60)}'`
							else
								_x="null"
							fi
							_prevSecs[${_inst}]=${_secs}
							_str="${_x},`echo ${_Line} | awk '{printf("%d,%.02f,%.02f,%.02f,%.02f,%.02f,%.02f,%.02f,%.02f,%.02f,%.02f,%.02f,%.02f,%.02f,%.02f\n",$1,$15,$16,$17,$18,$19,$28,$29,$30,$31,$34,$35,$36,$37,$40)}'`"
							echo "insert into awr_miner_metrics values ('${_dbName}',${_inst},${_str});" >> ${_sqlFile}
							;;
				"DATABASE-PARAMETERS")	_p=`echo ${_Line} | awk '{print $1}'`
							if [ ${_p} == "db_block_size" ] ||
							   [ ${_p} == "db_cache_size" ] ||
							   [ ${_p} == "db_keep_cache_size" ] ||
							   [ ${_p} == "db_recycle_cache_size" ] ||
							   [ ${_p} == "filesystemio_options" ] ||
							   [ ${_p} == "inmemory_size" ] ||
							   [ ${_p} == "java_pool_size" ] ||
							   [ ${_p} == "large_pool_size" ] ||
							   [ ${_p} == "log_buffer" ] ||
							   [ ${_p} == "memory_target" ] ||
							   [ ${_p} == "parallel_max_servers" ] ||
							   [ ${_p} == "pga_aggregate_target" ] ||
							   [ ${_p} == "processes" ] ||
							   [ ${_p} == "sga_target" ] ||
							   [ ${_p} == "shared_pool_reserved_size" ] ||
							   [ ${_p} == "shared_pool_size" ] ||
							   [ ${_p} == "streams_pool_size" ]
							then
								_v=`echo ${_Line} | awk '{print $2}'`
								echo "insert into awr_miner_parm values ('${_dbName}','${_p}','${_v}');" >> ${_sqlFile}
							fi
							;;
				"AVERAGE-ACTIVE-SESSIONS")	break
							;;
			esac
		fi
		#
		typeset -i _l=${_l}+1
		#
	done < ${_tmpFile}
	rm -f ${_tmpFile}
	#
	echo "insert into awr_miner_info values ('${_dbName}','${_dbHosts}',${_dbNumInstances},${_numCpus},${_numCpuCores},${_physMemGiB},'${_platformName}','${_dbVersion}','${_runModule}','${_awrMinerVersion}');" >> ${_sqlFile}
	echo "insert into awr_miner_disk values ('${_dbName}',${_szOnDiskGiB},${_maxSzOnDiskGiB});" >> ${_sqlFile}
	echo "commit;" >> ${_sqlFile}
	#
done
#
#--------------------------------------------------------------------------------
# ...finally, recreate the three largest tables as compressed...
#--------------------------------------------------------------------------------
cat << __EOF2__ >> ${_sqlFile}

create table xtmpx compress as select * from awr_miner_mem;
drop table awr_miner_mem purge;
rename xtmpx to awr_miner_mem;

create table xtmpx compress as select * from awr_miner_load;
drop table awr_miner_load purge;
rename xtmpx to awr_miner_load;

create table xtmpx compress as select * from awr_miner_metrics;
drop table awr_miner_metrics purge;
rename xtmpx to awr_miner_metrics;

exit success commit
__EOF2__
