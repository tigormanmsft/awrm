define V_NTILE=95
set pagesize 200 linesize 200 trimout on trimspool on verify off
col db_name format a7
col db_hosts heading "DB Hosts" format a20
col db_name heading "DB Name" format a8
col nbr_vcpus heading "Provisioned|# vCPUs"
col nbr_cores heading "Provisioned|# cores"
col obsd_load heading "Observed|Load Avg"
col phys_mem heading "Provisioned|Mem (GiB)"
col obsd_vcpus heading "Observed|# vCPUs"
col obsd_mem heading "Observed|Mem (GiB)"
col obsd_read_mbps heading "Observed|Read MBps"
col obsd_write_mbps heading "Observed|Write MBps"
col obsd_redo_mbps heading "Observed|Redo MBps"
col obsd_read_iops heading "Observed|Read IOPS"
col obsd_write_iops heading "Observed|Write IOPS"
clear breaks computes
break on report on db_hosts skip 1
compute max of obsd_load on db_hosts
compute sum of obsd_vcpus on db_hosts
compute sum of obsd_cores on db_hosts
compute sum of obsd_mem on db_hosts
compute sum of obsd_read_mbps on db_hosts
compute sum of obsd_read_iops on db_hosts
compute sum of obsd_redo_mbps on db_hosts
compute sum of obsd_write_mbps on db_hosts
compute sum of obsd_write_iops on db_hosts
compute max of obsd_load on report
compute sum of obsd_vcpus on report
compute sum of obsd_cores on report
compute sum of obsd_mem on report
compute sum of obsd_read_mbps on report
compute sum of obsd_read_iops on report
compute sum of obsd_redo_mbps on report
compute sum of obsd_write_mbps on report
compute sum of obsd_write_iops on report
spool q_awrm.txt
select	i.db_hosts,
	i.db_name,
	i.nbr_vcpus,
	i.nbr_cores,
	i.phys_mem,
	(select	round(max(load_avg),0)
	 from	(select	load_avg,
			ntile(100) over (order by load_avg asc) load_avg_ntile
		 from	awr_miner_load m
		 where	m.db_name = i.db_name)
	 where	load_avg_ntile = &&V_NTILE) obsd_load,
	(select	round(max(calc_aas_sd),0)
	 from	(select	calc_aas_sd,
			ntile(100) over (order by calc_aas_sd asc) calc_aas_sd_ntile
		 from	(select	(m.db_time+m.db_time_sd)/m.dur_mins calc_aas_sd
			 from	awr_miner_metrics m
			 where	m.db_name = i.db_name))
	 where	calc_aas_sd_ntile = &&V_NTILE) obsd_vcpus,
	(select	round(max(gib),0)
	 from	(select	m.gib,
			ntile(100) over (order by m.gib asc) gib_ntile
		 from	awr_miner_mem m
		 where	m.db_name = i.db_name)
	 where	gib_ntile = &&V_NTILE) obsd_mem,
	(select	round(max(read_mbps),0)
	 from	(select	m.read_mbps,
			ntile(100) over (order by m.read_mbps asc) read_mbps_ntile
		 from	awr_miner_metrics m
		 where	m.db_name = i.db_name)
	 where	read_mbps_ntile = &&V_NTILE) obsd_read_mbps,
	(select	round(max(write_mbps),0)
	 from	(select	m.write_mbps,
			ntile(100) over (order by m.write_mbps asc) write_mbps_ntile
		 from	awr_miner_metrics m
		 where	m.db_name = i.db_name)
	 where	write_mbps_ntile = &&V_NTILE) obsd_write_mbps,
	(select	round(max(redo_mbps),0)
	 from	(select	m.redo_mbps,
			ntile(100) over (order by m.redo_mbps asc) redo_mbps_ntile
		 from	awr_miner_metrics m
		 where	m.db_name = i.db_name)
	 where	redo_mbps_ntile = &&V_NTILE) obsd_redo_mbps,
	(select	round(max(read_iops),0)
	 from	(select	m.read_iops,
			ntile(100) over (order by m.read_iops asc) read_iops_ntile
		 from	awr_miner_metrics m
		 where	m.db_name = i.db_name)
	 where	read_iops_ntile = &&V_NTILE) obsd_read_iops,
	(select	round(max(write_iops),0)
	 from	(select	m.write_iops,
			ntile(100) over (order by m.write_iops asc) write_iops_ntile
		 from	awr_miner_metrics m
		 where	m.db_name = i.db_name)
	 where	write_iops_ntile = &&V_NTILE) obsd_write_iops
from	awr_miner_info i
order by db_hosts, db_name;
spool off
clear breaks computes
