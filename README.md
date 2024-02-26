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
  
  
