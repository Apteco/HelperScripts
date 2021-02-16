
# Setup

* Execute `s3backup__00__create_settings.ps1` to create the basic settings
* Execute `s3backup__01__setup_backup_folders.ps1` to add the folders to backup

# Setup in Profitbricks/IONOS

* Create a user in Profitbricks
* Create a group (if not exists) that has only access to object storage
* Copy the canonical user id from the group
* Grant access to a bucket with that canonical user id


# Licenses and References

## 7-Zip License

This script uses the 7zip command line to zip and encrypt files before it gets uploaded.

7-Zip Extra files are under the GNU LGPL license.

Read the files ./lib/7z1900-extra/License.txt or http://www.7-zip.org/ for more information about license and source code.



# Troubleshooting

## Certificate problems

* If you see an error like this one<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/108084666-c5ae8c00-7074-11eb-8deb-5e1225911347.png)<br/><br/> then have a look if you have used dots in your bucket name. Because the bucketname ist used as a subdomain there are no bucketnames with dots covered by the ssl certificate
