# Install Oracle Forms and Reports on the top of WebLogic dynamic cluster

## Contents

* [Prerequisites](#prerequisites)
* [Provision Azure WebLogic dynamic cluster offer](#provision-azure-weblogic-dynamic-cluster-offer)
* [Create Windows VM and set up XServer](#create-windows-vm-and-set-up-xserver)
* [Create Oracle Database](#create-oracle-database)
* [Install Oracle Fusion Middleware Infrastructure](#install-oracle-fusion-middleware-infrastructure)
* [Install Oracle Froms and Reports](#install-oracle-froms-and-reports)
* [Create schemas using RCU](#create-schemas-using-rcu)
* [Configure Forms and Reports in the existing domain](#configure-forms-and-reports-in-the-existing-domain)
* [Verify](#validation)

## Prerequisites

An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/dotnet).

## Provision Azure WebLogic dynamic cluster offer

- Open [Azure portal](https://portal.azure.com/) from your browser.
- Search `weblogic`, you will find the WebLogic offers, select **Oracle WebLogic Server Dynamic Cluster**, and click **Create** button.
- Input values in the **Basics** blade:
  - Subscription: select your subscription.
  - Resource group: click **Create new**, input a name.
  - Region: East US.
  - Oracle WebLogic Image: WebLogic Server 12.2.1.4.0 and JDK8 on Oracle Linux 7.6.
  - Virtual machine size: select a size with more than 8GiB RAM, e.g. Standard B4ms.
  - Username for admin account of VMs: `weblogic`
  - Password: `Secret123456`
  - Username for WebLogic Administrator: `weblogic`
  - Password for WebLogic Administrator： `Secret123456`
  - Initial Dynamic Cluster Size: 2
- Input values in the **Oracle HTTP Server Load Balancer** blade:
  - Connect to Oracle HTTP Server? Yes
  - Oracle HTTP Server image: OHS 12.2.1.4.0 and JDK8 on Oracle Linux 7.6
  - Oracle HTTP Server Domain name: `ohsStandaloneDomain`
  - Oracle HTTP Server Component name: `ohs_component`
  - Oracle HTTP Server NodeManager username: `weblogic`
  - Oracle HTTP Server NodeManager Password: `Secret123456`
  - Oracle HTTP Server HTTP port: `7777`
  - Oracle HTTP Server HTTPS port: `4444`
  - Oracle Vault Password： `Secret123456`
  - How would you like to provide required configuration： Upload exiting KeyStores
  - Upload your certificate for the OHS server
  - Password: int put the certifcate password
  - Type of the certifcate: `JKS`

- Keep other blads as default. Click **Review + create**.

It will take half an hour for the offer completed.

## Create Windows VM and set up XServer

After the offer is completed, open the resource group.

- Click **Create** button to create a Windows machine.
- Select **Compute**, Select **Virtual machine**.
- Virtual machine name: windowsXServer
- Image: Windows 10 Pro
- Size: Stardard_D2s_v3
- Username: `weblogic`
- Password: `Secret123456`
- Check Licensing.
- Click **Review + create**.

Edit the security to allow access from your terminal.

- Open the resource group that your are working on.
- Select resource `wls-nsg`
- Select **Settings** -> **Inbound security rules**
- Click add
  - Source: Any
  - Destination port ranges: 3389,22
  - Priority: 330
  - Name: Allow_RDP_SSH
  - Click **Save**

After the Windows server is completed, RDP to the server.

- Install the XServer from https://sourceforge.net/projects/vcxsrv/.
- Disable the firewall to allow communication from WebLogic VMs.
  - Turn off Windows Defender Firewall

Configure WebLogic VM:

- SSH to **adminVM** open ports for XServer by running the following commands:

  ```
  sudo firewall-cmd --zone=public --add-port=6000/tcp
  sudo firewall-cmd --runtime-to-permanent
  sudo systemctl restart firewalld
  ```

## Create Oracle Database

Follow this [document](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/oracle/oracle-database-quick-create) to create an Oracle database

If you follow the document to create Oracle database, write down the credentials to create Forms schema, username and password should be: `sys/OraPasswd1`


## Install Oracle Fusion Middleware Infrastructure

Download Oracle Fusion Middleware Infrastructure installer from https://download.oracle.com/otn/nt/middleware/12c/122140/fmw_12.2.1.4.0_infrastructure_Disk1_1of1.zip

Unzip the file and copy `fmw_12.2.1.4.0_infrastructure.jar` to **adminVM**.
Make sure `fmw_12.2.1.4.0_infrastructure.jar` is copied to /u01/oracle/fmw_12.2.1.4.0_infrastructure.jar, owner of the file is `oracle`.

Now let's use the XServer to install Oracle Fusion Middleware Infrastructure in the *adminVM**.

Steps to install Oracle Fusion Middleware Infrastructure in adminVM:

- RDP to windowsXServer.
- Click XLaunch from the desktop.
  - Multiple windows, Display number: `-1`, click Next.
  - Select "Start no client"
  - Check Clipboard and Primary Selection, Native opengl, Disable access control. Click Next.
  - Click Finish.

- Open CMD
- SSH to adminVM with command `ssh weblogic@adminVM`
- Install depedency: if you are using RHEL, you must install `libXtst`
  ```
  sudo yum install -y libXtst
  sudu yum install -y libSM
  sudo yum install -y libXrender
  ```
- Stop WebLogic process
    ```
    sudo systemctl stop wls_admin
    sudo systemctl stop wls_nodemanager
    ```
- Use `oracle` user: `sudo su - oracle`
- Get the private IP address of widnowsXServer, e.g. `10.0.0.8`
- Set env variable: `export DISPLAY=<yourWindowsVMVNetInternalIpAddress>:0.0`, e.g. `export DISPLAY=10.0.0.8:0.0`
- Set Java env: 
    ```
    oracleHome=/u01/app/wls/install/oracle/middleware/oracle_home
    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh
    ```
- Install fmw_12.2.1.4.0_infrastructure.jar
  - Launch the installer
    ```
    java -jar fmw_12.2.1.4.0_infrastructure.jar
    ```
  - Continue? Y
  - Page1
    - Inventory Directory: `u01/oracle/oraInventory`
    - Operating System Group: `oracle`
  - Step 3
    - Oracle Home: `/u01/app/wls/install/oracle/middleware/oracle_home`
  - Step 4
    - Select "Function Middleware infrastructure"
  - Installation summary
    - picture resources\images\screenshot-ofm-installation-summary.png
  - The process should be completed without errors.
  - Remove the installation file to save space: `rm fmw_12.2.1.4.0_infrastructure.jar`

## Install Oracle Froms and Reports

- Download wget.sh from https://www.oracle.com/middleware/technologies/forms/downloads.html#
  - Oracle Fusion Middleware 12c (12.2.1.4.0) Forms and Reports for Linux x86-64 for (Linux x86-64)
  - Oracle Fusion Middleware 12c (12.2.1.4.0) Forms and Reports for Linux x86-64 for (Linux x86-64)
- Copy the wget.sh to `/u01/oracle/wget.sh`
- Use the windowsXServer ssh to adminVM: `ssh weblogic@adminVM`.
- Install denpendencies:
  ```
  # you must install the following packages in Oracle Linux 7.6.
  sudo yum install -y compat-libcap1
  sudo yum install -y compat-libstdc++-33
  sudo yum install -y libstdc++-devel
  sudo yum install -y gcc
  sudo yum install -y gcc-c++
  sudo yum install -y ksh
  sudo yum install -y glibc-devel
  sudo yum install -y libaio-devel
  sudo yum install -y motif
  ```
- Use `oracle` user
- Set env variable: `export DISPLAY=<yourWindowsVMVNetInternalIpAddress>:0.0`, e.g. `export DISPLAY=10.0.0.8:0.0`
- Edit the script, replace `--ask-password` with `--password <your-sso-password>`
- Run the script
  - `bash wget.sh`
  - input your SSO account name.
- Unzip the zip files: ` unzip "*.zip"`, you will get `fmw_12.2.1.4.0_fr_linux64.bin` and `fmw_12.2.1.4.0_fr_linux64-2.zip`
- Remove the zip files to save space
  ```
   rm V983392-01_1of2.zip
   rm V983392-01_2of2.zip
  ```
- Install Forms: `./fmw_12.2.1.4.0_fr_linux64.bin`
  - The installation dialog should prompt up, if no, set `export PS1="\$"`, run `./fmw_12.2.1.4.0_fr_linux64.bin` again.
  - Inventory Directory: `/u01/oracle/oraInventory`
  - Operating System Group: `oracle`
  - Step 3:
    - Oracle Home: `/u01/app/wls/install/oracle/middleware/oracle_home`
  - Step 4:
    - Forms and Reports Deployment
  - Step 5:
    - JDK Home: /u01/app/jdk/jdk1.8.0_291
  - Step 6: if there is error of operation system packages, install the conrresponding package and run `./fmw_12.2.1.4.0_fr_linux64.bin` again.
    - Error like "Checking for compat-libcap1-1.10;Not found", then run `sudo yum install compat-libcap1` to install the `compat-libcap1` package.
  - The installation should be completed without errors.

## Create schemas using RCU

- Use the windowsXServer.
- SSH to adminVM
- Use `oracle` user
- Set env variable: `export DISPLAY=<yourWindowsVMVNetInternalIpAddress>:0.0`, e.g. `export DISPLAY=10.0.0.8:0.0`
- `bash /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/bin/rcu`
- Step2: Create Repository -> System Load and Product Load
- Step3: Input the connection information of Oracle database.
- Step4: please note down the prefix, whith will be used in the following configuration.
  - STB
  - OPSS
  - IAU
  - IAU_APPEND
  - IAU_VIEWER
  - MDS
  - WLS
- Step5: Use same passwords for all schemas. Value: `Secret123456`
- The schema should be completed without error.

## Configure Forms and Reports in the existing domain

- Use the windowsXServer.
- SSH to adminVM
- Use `oracle` user
- Set env variable: `export DISPLAY=<yourWindowsVMVNetInternalIpAddress>:0.0`, e.g. `export DISPLAY=10.0.0.8:0.0`
- `bash  /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin/config.sh`
- Page1:
  - Update an existing domain
  - location: /01/domains/wlsd
- Page2: 
  - FADS
  - Oracle Forms
  - Oracle Reports Application
  - Oracle Enterprise Manager
  - Oracle Reports Tools
  - Oracle WSM Policy Manager
  - Oracle JRF
  - ORacle WebLogic Coherence Cluster Extension
- Page3:
  - Application location: /u01/domains/applications
- Page4: 
  - RCU Data
  - Host Name: the host name of database
  - DBMS/Service: your dbms
  - Schema Owner: `<the-rcu-schema-prefix>_STB`
  - Schema Password: `Secret123456`
- Page7:
  - Topology
  - System Components
  - Deployment and Services
- Page14: Machines
  - Remove AdminServerMachine
- Page15: Assign Servers to Machine
  - adminVM
    - WLS_FORMS
    - WLS_REPORTS
- Page19: Assign System Component
  - adminVM
    - SystemComonent
      - forms
- Page20: Deployments Targeting
  - AdminServer
    - admin
      - DMS Application#12.2.1.1.0
      - coherence-transaction-rar
      - em
      - fads#1.0
      - fads-ui#1.0
      - opss-rest
      - state-management-provider-menory...
      - wlsm-pm
- The process should be completed withour error.
- Exit `oracle` user
- Start node manager: `sudo systemctl start wls_nodemanager`
- Start weblogic: `sudo systemctl start wls_admin`
- Open ports for Forms and Reports
  ```
  sudo firewall-cmd --zone=public --add-port=9001/tcp
  sudo firewall-cmd --zone=public --add-port=9002/tcp
  sudo firewall-cmd --runtime-to-permanent
  sudo systemctl restart firewalld
  ```

Start Forms and Reports server from admin console.
- Open WebLogic Admin Console from browser, and login
- Select Environment -> Servers -> Control
- Start WLS_FORMS and WLS_REPORTS
- The two servers should be running.

Edit the security to allow access to Forms and Reports:
- Open the resource group that your are working on.
- Select resource wls-nsg
- Select Settings -> Inbound security rules
- Click add
- Source: Any
- Destination：IP Address
- Destination IP addresses/CIDR ranges: IP address of adminVM
- Destination port ranges: 9001,9002
- Priority: 340
- Name: Allow_FORMS_REPORTS
- Click Save

## Validation

- Admin console: `http://<adminvm-ip>:7001/console`
- em: `http://<adminvm-ip>:7001/em`
- forms: `http://<adminvm-ip>:9001/forms/frmservlet`
  - Please use JRE 32 bit + IE to access Forms.
- reports: `http://<adminvm-ip>:9002/reports/rwservlet`




 

