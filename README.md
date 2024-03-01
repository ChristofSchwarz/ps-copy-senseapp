# ps-copy-senseapp
Copy a Sense App from one Windows Server to another with all private and community content kept.

## Steps to prepare the app migration
1) Setup a virtual proxy for both, the source and the target Qlik Sense Windows environment
   - The virtual proxy needs to be of type Header Authentication or JWT
   - Dont forget to link the new virtual proxy to a proxy service
   - and dont forget to whitelist the external hostname by which you will call the server
2) update `_config.json` file.
   - The `env` section make an entry for each environment (can be source or target or more).
   - Each env must have the following settings:
```
{
"env_name": {
   "server_url": "https://my.server.com"
   "vproxy": "proxyprefix"
   "auth_header": { "headerfield" : "headervalue" },
   "default_stream": "Everyone",
   "default_owner": { "userDirectory": "Domain", "userId": "christof.schwarz" }
   }
}
```
   - `vproxy` is the prefix of the Virtual Proxy to use
   - `auth_header` is taken into the http header of the QRS API calls. Within auth_header specify
     the name of the header field that was configured in the virtual proxy setting.
   - Give the user in the QMC of source and target sufficient rights, "ContentAdmin" is recommended
3) Call `.\testAccess.ps1 -env {{environment}}` script
   - This will use _config.json and make a connection to the environment specified
   - it makes the QRS API call /qrs/apps/count and reports on the screen, how many apps the configured
     user is able to see.
   - If this counter is 0 it indicates, that the given user hasn't enough rights (give "ContentAdmin"
     rights)

## Export apps
Call the script with 2 arguments
```
.\exportApp.ps1 -env {{environment}} -appId {{appId}}
```

- `env` specify one of the environments configured in `_config.json` under `env`
- `appId` is the app-GUID of the app (the .qvf and .json file of that appId must be present in the
  current folder
  
### What exportApp.ps1 does
- It will export the app as .qvf file using argument `exportScope=all` which will make sure that the app
  export contains also private and community objects (sheets/stories/bookmarks)
- It will also export a .json file with a list of private and community objects found in the app,
  and the owner names, which will be needed by .\importApp.ps1 script

## Import apps
Call the script with 2 or 3 arguments (the 3rd is optional) 
```
.\importApp.ps1 -env {{environment}} -appId {{appId}} [-delFiles [Y/N]]
``` 

- `env` specify one of the environments configured in `_config.json` under `env`
- `appId` is the app-GUID of the app (the .qvf and .json file of that appId must be present in the
  current folder
- `delFiles` (optional) put `Y` or `N` where Y stands for deleting the app's .qvf and .json
  files after a successful upload (usually you don't need the .qvf and .json files anymore). If errors
  were found, that argument is ignored and the .qvf and .json files will remain
### What importApp.ps1 does 
- it will upload the .qvf app to the target server and
- will try to publish it to the same stream as on the source server (if a stream under the same name
  exists, if not, the parameter `default_stream` in the environment setting in `_config.json` is used)
- will try to set the app owner to the same name (userId and userDirectory) as on the source server
  (if that user doesn't exist, the parameter `default_owner` in the environment setting in `_config.json` is used)
- will go through the list of community and privat objects according to the .json file (immediately after import, such
  content appear as base objects, and this is fixed by this script) and try to set the same owner as on the source
  server (again, if the original owner doesn't exist, it will take the default_owner)
- it will fill two log files in .csv format, one for app-level infos/warnings/errors and one for object-level
- name of log files can be set in _config.json, attributes `appLog` and `objLog`


 
     
    
