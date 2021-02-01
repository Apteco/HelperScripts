Here do you find whole packaged scripts for specific use cases:

Name|Description
-|-
CDC-in-sqlite|Downloads climate data from the OpenData portal of the DWD in Offenbach, unzips everything and loads it into a sqlite database which then can be used in FastStats Designer. Those are around 5m rows (>= 500 weather stations measurements per day for the last 500 days).
cleverreach|Collection of scripts that can be used with Cleverreach like the deactivation of all receivers in a specific group. There will be more scripts in the future.
csv-to-sqlite|This script is looking for a specific directory and load all text files in a sqlite database. If that database or the tables in it or the columns in a table do not exist, they will be created automatically. Existing tables will be appended with the new data.
filewaiter|This Script watches a specific folder and is waiting for 1 or multiple files to arrive. If this happens, a countdown will be started automatically. If another files arrives before the countdown is finished, the countdown will be reset. If the countdown is finally finished, it triggers another script (like importing the data into a database and then trigger a build).<br/>After the scripts have been finished it gets back to the waiting mode until a new file will arrive.<br/><br/>With this approach we can make sure that a build runs even if some files are not arriving due to technical problems.
filewatcher|Create an automatic "Watchdog" to do something with files if they are getting created/deleted/changed etc. on a specific directory. This example is looking at a folder and looking for new files, waiting until the file has finally arrived and move it then to another place.
geocoding|Automatic geocoding against Bing Maps API to batch geocode addresses (200k per call). This needs a Bing Maps Enterprise license.
hash_column_in_csv|Hash a column in a csv file so it can be anonymised or pseudonomised.
housekeeping|For a SQLServer if you want to remove log entries and shrink the databases automatically.
newsystem|If you have a global user database then this script helps you to add the first user `administrator` for that system to the global user database. Afterwards you can login with that user and add more users from the global user inventory. Just download the whole folder `newsystem`, open the `new_admin_for_new_system.ps1` to change some settings (normally only the sqlserver instance) in `$settings` and then you are good to go to execute that script. It then asks you for the new systemname and the administrator entries will be created.
orbit-api|Collection of examples on how to use the Orbit API like executing queries, export data and uploading data
