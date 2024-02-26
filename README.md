# ps-copy-senseapp
Copy a Sense App from one Windows Server to another with all private and community content kept.

## Steps to prepare the app migration
1) Setup a virtual proxy for both, the source and the target Qlik Sense Windows environment
   - The virtual proxy needs to be of type Header Authentication or JWT
   - Dont forget to link the new virtual proxy to a proxy service
   - and dont forget to whitelist the external hostname by which you will call the server
2) update `_config.json` file.
   - The `auth_header` section under source and target needs to
     match the settings you have provided in the virtual proxy (name of the header field
     in case it was of type "header with Static directory" or "header with Dynamic directory"
     is specified there)
   - Give the user in the QMC of source and target sufficient rights, "ContentAdmin" is recommended
3) Call `.\testAccess.ps1` script
   - This will use _config.json and make a connection to both, source and target servers
   - it makes the QRS API call /qrs/apps/count and reports on the screen, how many apps the configured
     user is able to see.
   - If this counter is 0 it indicates, that the given user hasn't enough rights (give "ContentAdmin"
     rights)

## Export apps
- Call the script `.\exportApp.ps1 {{appId}}` with the app-GUID of the app you like to export
  (mandatory argument)
- It will export the app as .qvf file using argument `exportScope=all` which will make sure that the app
  export contains also private and community objects (sheets/stories/bookmarks)
- It will also export a .json file with a list of private and community objects found in the app,
  and the owner names

## Import apps
- Call the script `.\importApp.ps1 {{appId}} [Y/N]` with the
   - app-GUID of the app you like to import (mandatory argument)
   - `Y` or `N` as an optional 2nd argument, where Y stands for deleting the app's .qvf and .json
     files after a successful upload (usually you don't need those 2 files anymore). If errors were
     found, the 2nd argument is ignored and the .qvf and .json files will remain
- it will upload the .qvf app to the target server and
   - will try to publish it to the same stream as on the source server (if a stream under the same name
     exists)
   - will try to set the app owner to the same name (userId and userDirectory) as on the source server
   - will go through the list of community and privat objects (right after import, they appear as base
     objects, so this is fixed after the upload), and try to set the same owner as on the source server
- it will fill a log file in .csv format
   - name of log file can be set in _config.json
   - a number of fields will be exported, such as the new appId, count of private/community sheets
   - if any error happens, each error will also go into the log file as a new row
 
     
    
