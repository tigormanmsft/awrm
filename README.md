# awrm
This package consists of a Linux bash script to extract VM sizing information from an AWR Miner dump, to generate an Oracle SQL*Plus script to insert the information into an Oracle database, then run another Oracle SQL*Plus script to calculate estimates for Azure compute and storage.

Processing consists of three steps...

1. Running the "cr_awrm.sh" script to extract VM sizing information from the AWR Miner dump files, named "awr-hist-*.out" in the present working directory.  Standard output emitted from the script comprises a generated Oracle SQL*Plus script.
2. Running the generated SQL*Plus script in an Oracle database to create and populate tables with AWR Miner sizing information
3. Running the "q_awrm.sql" script in the database to aggregate the AWR Miner information to calculate estimates of CPU, RAM, and I/O for new Azure VMs and storage

# Command-line options
The "cr_awrm.sh" script takes no command-line parameters, but it may take several minutes to process each AWR Miner file, so it might make sense to submit the command into background and run it unattended.

The "cr_awrm.sh" script must reside in the same directory as the AWR Miner dump files (named "awr-hist-*.out").

To execute in background...
       $ nohup ./cr_awrm.sh > cr_awrm.sql 2> cr_awrm.err &
       
...where the above command will execute the bash script "cr_awrm.sh" to survive and ignore shell "hang up" interrupts, meaning that you can log out from the shell once the script is submitted, and the script will continue running in background.  All standard output will be collected in a file named "cr_awrm.sql" and any error messages to standard error will be collect in a file named "cr_awrm.err".

If the script completes successfully, then the "cr_awrm.err" file will have only 1 line of 22 characters saying "nohup: ignoring input".

If the script completes successfully, then please run the generated script spooled to the file "cr_awrm.sql" using the Oracle SQL*Plus program, as follows...

       $ sqlplus username/password @cr_awrm

All output from the SQL*Plus script will be spooled to a file named "cr_awrm.lst", in which no lines starting with the phrase "ORA-" should reside upon completion.

Once data has been loaded, then running the SQL*Plus script named "q_awrm.sql" will calculate estimates...

       $ sqlplus username/password @q_awrm

Output from the query will be spooled to a file named "q_awrm.txt", a sample of which is included in this repository.
