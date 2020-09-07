This Script watches a specific folder and is waiting for 1 or multiple files to arrive. If this happens, a countdown will be started automatically. If another files arrives before the countdown is finished, the countdown will be reset. If the countdown is finally finished, it triggers another script (like importing the data into a database and then trigger a build).
After the scripts have been finished it gets back to the waiting mode until a new file will arrive.

With this approach we can make sure that a build runs even if some files are not arriving due to technical problems.

