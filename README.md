# awrm
This package consists of a Linux bash script to extract VM sizing information from an AWR Miner dump, to generate an Oracle SQL*Plus script to insert the information into an Oracle database, then run another Oracle SQL*Plus script to calculate estimates for Azure compute and storage.

Processing consists of three steps...

1. Running the "awrm_gen.sh" script to extract VM sizing information from the AWR Miner dump files, named "awr-hist-*.out" in the present working directory.  Standard output emitted from the script comprises a generated Oracle SQL*Plus script.
2. Running the generated SQL*Plus script in an Oracle database to create and populate tables with AWR Miner sizing information
3. Running the "awrm_rpt.sql" script in the database to aggregate the AWR Miner information to calculate estimates of CPU, RAM, and I/O for new Azure VMs and storage

# Command-line options
The "awrm_gen.sh" script takes no command-line parameters, but it may take several minutes to process each AWR Miner file, so it might make sense to submit the command into background and run it unattended.

The "awrm_gen.sh" script must reside in the same directory as the AWR Miner dump files (named "awr-hist-*.out").

To execute in background...
       $ nohup ./awrm_gen.sh > awrm_gen.sql 2> awrm_gen.err &
       
...where the above command will execute the bash script "awrm_gen.sh" to survive and ignore shell "hang up" interrupts, meaning that you can log out from the shell once the script is submitted, and the script will continue running in background.  All standard output will be collected in a file named "awrm_gen.sql" and any error messages to standard error will be collect in a file named "awrm_gen.err".

If the script completes successfully, then the "awrm_gen.err" file will have only 1 line of 22 characters saying "nohup: ignoring input".

If the script completes successfully, then please run the generated script spooled to the file "awrm_gen.sql" using the Oracle SQL*Plus program, as follows...

       $ sqlplus username/password @awrm_gen

All output from the SQL*Plus script will be spooled to a file named "awrm_gen.lst", in which no lines starting with the phrase "ORA-" should reside upon completion.

Once data has been loaded, then running the SQL*Plus script named "awrm_rpt.sql" will calculate estimates...

       $ sqlplus username/password @awrm_rpt

Output from the query will be spooled to a file named "awrm_rpt.txt", a sample of which is included in this repository.
