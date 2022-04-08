# Create Highly Available Oracle Forms and Reports clusters on Azure(WIP)

This document guides you to create high vailable Oracle Forms and Reports clusters on Azure VMs step by step, including:
- Create Oracle Forms and Reports clusters with 2 replicas.
- Create load balancing with Azure Application Gateway
- Scale up with new Forms and Reports replicas
- Create Highly Available Adminitration Server
- Troubleshooting

## Contents

* [Prerequisites](#prerequisites)
* [Provision Azure WebLogic Virtual Machine](#provision-azure-weblogic-virtual-machine)
* [Create Oracle Database](#create-oracle-database)
* [Create Windows VM and set up XServer](#create-windows-vm-and-set-up-xserver)
* [Install Oracle Fusion Middleware Infrastructure](#install-oracle-fusion-middleware-infrastructure)
* [Install Oracle Froms and Reports](#install-oracle-froms-and-reports)
* [Clone machine for managed servers](#clone-machine-for-managed-servers)
* [Create schemas using RCU](#create-schemas-using-rcu)
* [Configure Forms and Reports with a new domain](#configure-forms-and-reports-in-the-existing-domain)
  * [Create domain for admin server](#create-domain-on-adminvm)
  * [Create domain for managed servers](#create-domain-on-managed-machine)
  * [Create and start Reports components](#create-and-start-reports-components)
  * [Start Forms and Reports](#start-forms-and-reports-managed-servers)
* [Add Forms and Reports replicas](#apply-jrf-to-managed-server)
  * [Create a new machine for new replicas](#create-a-new-machine-for-new-replicas)
  * [Create and start components](#create-forms-and-reports-components)
  * [Apply domain on the new machine](#apply-domain-on-the-new-machine)
  * [Start new replicas](#start-servers)
* [Create Load Balancing with Azure Application Gateway](#configure-private-application-gateway)
  * [Create Application Gateway](#create-application-gateway)
  * [Configure Backend Pool](#configure-backend-pool)
* [Create High Available Adminitration Server]()
* [Troubleshoot](#troubleshoot)

## Prerequisites

An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/dotnet).

## Provision Azure WebLogic Virtual Machine

Azure provides a serie of Oracle WebLogic base images, it'll save your effor for Oracle tools installation.
This document will setup Oracle Forms and Reports based on the Azure WebLogic base image, follow the steps to provison a machine with JDK and WebLogic installed:

- Open [Azure portal](https://portal.azure.com/) from your browser.
- Search `WebLogic 12.2.1.4.0 Base Image and JDK8 on OL7.6`, you will find the WebLogic offers, select **WebLogic 12.2.1.4.0 Base Image and JDK8 on OL7.6**, and click **Create** button.
- Input values in the **Basics** blade:
  - Subscription: select your subscription.
  - Resource group: click **Create new**, input a name.
  - Virtual machine name: `adminVM`
  - Region: East US.
  - Image: WebLogic Server 12.2.1.4.0 and JDK8 on Oracle Linux 7.6 - Gen1.
  - Size: select a size with more than 8GiB RAM, e.g. Standard B4ms.
  - Authentication type: Password
  - Username: `weblogic`
  - Password: `Secret123456`
- Networking: you are able to bring your own VNET. If not, keep default settings.
- Keep other blads as default. Click **Review + create**.

It will take 10min for the offer completed. After the deployment finishes, you will have a machine with JDK and WLS installed. Then you are able to install and configure Forms and Reports on the top of the machine.

## Create Oracle Database

You are required to have to database to confiugre the JRF domain for Forms and Reports.This document will use Oracle Database.
Follow this [document](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/oracle/oracle-database-quick-create) to create an Oracle database

If you are following the document to create Oracle database, write down the credentials to create domain schema, username and password should be: `sys/OraPasswd1`

## Create Windows VM and set up XServer

Though you have Oracle WebLogic instance running now, to create Oracle Forms and Reports, you still need to install Oracle Forms and Reports.
To simplify the interface, let's provison a Windows machine and leverage XServer to install required tools with graphical user interface.

Follow the steps to provision Windows VM and set up XServer.

- open the resource group.
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

## Install Oracle Fusion Middleware Infrastructure

Download Oracle Fusion Middleware Infrastructure installer from https://download.oracle.com/otn/nt/middleware/12c/122140/fmw_12.2.1.4.0_infrastructure_Disk1_1of1.zip

Unzip the file and copy `fmw_12.2.1.4.0_infrastructure.jar` to **adminVM**.
Make sure `fmw_12.2.1.4.0_infrastructure.jar` is copied to /u01/oracle/fmw_12.2.1.4.0_infrastructure.jar, owner of the file is `oracle`, you can set the ownership with command `chown oracle:oracle /u01/oracle/fmw_12.2.1.4.0_infrastructure.jar`.

Now let's use the XServer to install Oracle Fusion Middleware Infrastructure on **adminVM**.

Steps to install Oracle Fusion Middleware Infrastructure on adminVM:

- RDP to windowsXServer.
- Click XLaunch from the desktop.
  - Multiple windows, Display number: `-1`, click Next.
  - Select "Start no client"
  - Check Clipboard and Primary Selection, Native opengl, Disable access control. Click Next.
  - Click Finish.

- Open CMD
- SSH to adminVM with command `ssh weblogic@adminVM`
- Use root user: `sudo su`
- Install dependencies
  ```
  # dependencies for XServer access
  sudo yum install -y libXtst
  sudu yum install -y libSM
  sudo yum install -y libXrender
  # dependencies for Forms and Reports
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
- Disable firewall. If you want to keep the firewall, you must open ports for Reports and Forms.
  ```
  sudo systemctl stop firewalld
  sudo systemctl disable firewalld
  ```
- Create directory for user data
  ```
  mkdir /u02
  chown oracle:oracle /u02
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
    - Inventory Directory: `/u01/oracle/oraInventory`
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

Following the steps to install Oracle Forms and Reports:
- Download wget.sh from https://www.oracle.com/middleware/technologies/forms/downloads.html#
  - Oracle Fusion Middleware 12c (12.2.1.4.0) Forms and Reports for Linux x86-64 for (Linux x86-64)
  - Oracle Fusion Middleware 12c (12.2.1.4.0) Forms and Reports for Linux x86-64 for (Linux x86-64)
- Copy the wget.sh to `/u01/oracle/wget.sh`
- Use the windowsXServer ssh to adminVM: `ssh weblogic@adminVM`.
- Use `oracle` user
- Set env variable: `export DISPLAY=<yourWindowsVMVNetInternalIpAddress>:0.0`, e.g. `export DISPLAY=10.0.0.8:0.0`
- Edit wget.sh, replace `--ask-password` with `--password <your-sso-password>`
- Run the script, it will download the installer.
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
    - JDK Home: `/u01/app/jdk/jdk1.8.0_291`
  - Step 6: you may get dependencies error, you must install the conrresponding package and run `./fmw_12.2.1.4.0_fr_linux64.bin` again.
    - Error like "Checking for compat-libcap1-1.10;Not found", then run `sudo yum install compat-libcap1` to install the `compat-libcap1` package.
  - The installation should be completed without errors.

Now you have Forms and Reports installed in the adminVM. Let's clone the machine for managed servers.

## Clone machine for managed servers

You have Oracle Forms and Reports installed in the adminVM, we can clone adminVM for managed servers.

Follow the steps to clone adminVM and create two VMs for Forms and Reports replicas.

Create the a snapshot from adminVM OS disk. If you have snapshot of adminVM, skip the following two steps:
- Open Azure portal, stop adminVM.
- Create a snapshot from OS disk.


Create VMs for Forms and Reports replicas based on the snapshot:
1. Create a disk from the snapshot.
2. Create a VM with your expected name, e.g. `mspVM1` on the disk.
3. ssh to the machine, use `root` user and change the hostname.
    - Set hostname with `hostnamectl set-hostname hostname`. For example, set hostname mspVM1 with command `hostnamectl set-hostname mspVM1`
4. Repeat step1-3 for `mspVM2` or other new machine, make sure setting correct hostname.

For the initial setup, make sure you have three machine ready to configure Forms and Reports: **adminVM**, **mspVM1**, **mspVM2**, and move on with next section.

For new replicas, make sure you have the new machine ready, and continue from [Create Forms and Reports components](#create-forms-and-reports-components).

## Create schemas using RCU

You are required to create the schemas for the WebLogic domain.  
The following steps leverage XServer and RCU to create schemas on the Oracle database created previously.

- Use the windowsXServer.
- SSH to adminVM
- Use `oracle` user
- Set env variable: `export DISPLAY=<yourWindowsVMVNetInternalIpAddress>:0.0`, e.g. `export DISPLAY=10.0.0.8:0.0`
- `bash /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/bin/rcu`
- Step2: Create Repository -> System Load and Product Load
- Step3: Input the connection information of Oracle database.
- Step4: please note down the prefix, whith will be used in the following configuration, this document uses `DEV0402`.
  - STB
  - OPSS
  - IAU
  - IAU_APPEND
  - IAU_VIEWER
  - MDS
  - WLS
- Step5: Use same passwords for all schemas. Value: `Secret123456`
  - Note: you must use the same password of WebLogic admin account.
- The schema should be completed without error.

## Configure Forms and Reports with a new domain

### Create domain on adminVM

Now, the machine and database are ready, let's move on to create a new domain for Forms and Reports.

- Use the windowsXServer.
- SSH to adminVM
- Use `oracle` user
- Set env variable: `export DISPLAY=<yourWindowsVMVNetInternalIpAddress>:0.0`, e.g. `export DISPLAY=10.0.0.8:0.0`
- `bash  /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin/config.sh`
- Page1:
  - Create a new domain
  - Location: `/02/domains/wlsd`
- Page2: 
  - FADS
  - Oracle Forms
  - Oracle Reports Application
  - Oracle Enterprise Manager
  - Oracle Reports Tools
  - Oracle Reports Server
  - Oracle Reports Bridge
  - Oracle WSM Policy Manager
  - Oracle JRF
  - ORacle WebLogic Coherence Cluster Extension
- Page3: Applciation Location
  - Location: `/u02/applications/wlsd`
- Page4: Administrator account
  - Name: `weblogic`
  - Password: `Secret123456`, **make sure the value is the same with schema password**.
- Page5: Domain mode and JDK
  - Domain mode: production
  - JDK: keep default
- Page6: 
  - RCU Data
  - Host Name: the host name of database
  - DBMS/Service: your dbms
  - Schema Owner is `<the-rcu-schema-prefix>_STB`, this sample uses `DEV0402_STB`
  - Schema Password: `Secret123456`
- Page9: Advanced Configuration
  - Administration Server
  - Node Manager
  - Topology
  - System Components
  - Deployment and Services
- Page10: Administration Server
  - Server Name: `admin`
  - Listen Address: private ip of adminVM
  - Listen Port: 7001
  - Server Groups: WSMPM-MAN-SVR
- Page11: Node Manager
  - Node Manager credentials
    - Username: `weblogic`
    - Password: `Secret123456`
- Page12: Managed Servers, add the following servers
  - WLS_FORMS1
    - Listen address: private IP of mspVM1
    - Port: 9001
    - Server Groups: FORMS_MAN_SVR
  - WLS_REPORTS1
    - Listen address: private IP of mspVM1
    - Port: 9002
    - Server Groups: REPORTS_APP_SVR
  - WLS_FORMS2
    - Listen address: private IP of mspVM2
    - Port: 9001
    - Server Groups: FORMS_MAN_SVR
  - WLS_REPORTS2
    - Listen address: private IP of mspVM2
    - Port: 9002
    - Server Groups: REPORTS_APP_SVR
- Page13: CLusters
  - Keep default
- Page14: Server Templates
  - Keep default
- Page15: Dynamic Clusters
  - Keep default
- Page16: Assign Servers to Clusters
  - cluster_forms
    - WLS_FORMS1
    - WLS_FORMS2
  - cluster_reports
    - WLS_REPORTS1
    - WLS_REPORTS2
- Page17: Coherence Cluster
  - Keep default
- Page18: Machines
  - adminVM, `<private-ip-of-adminVM>`, 5556
  - mspVM1, `<private-ip-of-mspVM1>`, 5556
  - mspVM2, `<private-ip-of-mspVM2>`, 5556
- Page19: Assign Servers to machine
  - adminVM
    - admin
  - mspVM1
    - WLS_FORMS1
    - WLS_REPORTS1
  - mspVM2
    - WLS_FORMS2
    - WLS_REPORTS2
- Page20: virtual targets
  - Keep default
- Page21: Partitions
  - Keep default
- Page22: System Components
  - forms1, FORMS, 3600, 0
  - forms2, FORMS, 3600, 0
- Page22: Assign System Component
  - mspVM1
    - SystemComonent
      - forms1
  - mspVM2
    - SystemComonent
      - forms2
- Page20: Deployments Targeting
  - AdminServer
    - admin
      - Keep Default
  - Cluster
    - cluster_forms
      - AppDeployment
        - DMS Application#12.2.1.1.0
        - coherence-transaction-rar
        - reportsapp#12.2.1
        - state-management-provider-menory...
        - wsm-pm
      - Liraries
        - UIX (11,12.2.1.3.0)
        - adf.oracle.businesseditor (1.0,12.2.1.3.0)
        - adf.oracle.domain (1.0,12.2.1.3.0)
        - adf.oracle.domain.groovy (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp.antlr-runtime (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp.apache.httpclient (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp.apache.httpclient-cache (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp.apache.httpcore (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp.apache.httpmime (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp.apache.velocity (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp.batik-bundle (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp.guava (1.0,12.2.1.3.0)
        - adf.oracle.domain.webapp.xml-apis-ext (1.0,12.2.1.3.0)
        - jsf (2.0,1.0.0.0_2-2-8)
        - jstl (1.2,1.2.0.1)
        - odl.clickhistory (1.0,12.2.1)
        - odl.clickhistory.webapp (1.0,12.2.1)
        - ohw-rcf (5,12.2.1.3.0)
        - ohw-uix (5,12.2.1.3.0)
        - oracle.adf.dconfigbeans (1.0,12.2.1.3.0)
        - oracle.adf.desktopintegration (1.0,12.2.1.3.0)
        - oracle.adf.desktopintegration.model (1.0,12.2.1.3.0)
        - oracle.adf.management (1.0,12.2.1.3.0)
        - oracle.bi.adf.model.slib (1.0,12.2.1.3.0)
        - oracle.bi.adf.view.slib (1.0,12.2.1.3.0)
        - oracle.bi.adf.webcenter.slib (1.0,12.2.1.3.0)
        - oracle.bi.composer (11.1.1,0.1)
        - oracle.bi.jbips (11.1.1,0.1)
        - oracle.dconfig-infra (2.0,12.2.1)
        - oracle.formsapp.dependencieslib (12.2.1,12.2.1)
        - oracle.jrf.system.filter
        - oracle.jsp.next (12.2.1,12.2.1)
        - oracle.pwdgen (2.0,12.2.1)
        - oracle.sdp.client (2.0,12.2.1.3.0)
        - oracle.sdp.messaging (2.0,12.2.1.3.0)
        - oracle.wsm.idmrest.sharedlib (1.0,12.2.1.3)
        - oracle.wsm.seedpolicies (2.0,12.2.1.3)
        - orai18n-adf (11,11.1.1.1.0)
        - owasp.esapi (2.0,12.2.1)
      - clusters_reports
        - AppDeployment
          - DMS Application#12.2.1.1.0
          - coherence-transaction-rar
          - reports#12.2.1
          - state-management-provider-menory...
          - wsm-pm
        - Liraries
          - UIX (11,12.2.1.3.0)
          - adf.oracle.businesseditor (1.0,12.2.1.3.0)
          - adf.oracle.domain (1.0,12.2.1.3.0)
          - adf.oracle.domain.groovy (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp.antlr-runtime (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp.apache.httpclient (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp.apache.httpclient-cache (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp.apache.httpcore (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp.apache.httpmime (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp.apache.velocity (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp.batik-bundle (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp.guava (1.0,12.2.1.3.0)
          - adf.oracle.domain.webapp.xml-apis-ext (1.0,12.2.1.3.0)
          - jsf (2.0,1.0.0.0_2-2-8)
          - jstl (1.2,1.2.0.1)
          - odl.clickhistory (1.0,12.2.1)
          - odl.clickhistory.webapp (1.0,12.2.1)
          - ohw-rcf (5,12.2.1.3.0)
          - ohw-uix (5,12.2.1.3.0)
          - oracle.adf.dconfigbeans (1.0,12.2.1.3.0)
          - oracle.adf.desktopintegration (1.0,12.2.1.3.0)
          - oracle.adf.desktopintegration.model (1.0,12.2.1.3.0)
          - oracle.adf.management (1.0,12.2.1.3.0)
          - oracle.bi.adf.model.slib (1.0,12.2.1.3.0)
          - oracle.bi.adf.view.slib (1.0,12.2.1.3.0)
          - oracle.bi.adf.webcenter.slib (1.0,12.2.1.3.0)
          - oracle.bi.composer (11.1.1,0.1)
          - oracle.bi.jbips (11.1.1,0.1)
          - oracle.dconfig-infra (2.0,12.2.1)
          - oracle.jrf.system.filter
          - oracle.jsp.next (12.2.1,12.2.1)
          - oracle.pwdgen (2.0,12.2.1)
          - oracle.reports.applib (12.2.1,12.2.1)
          - oracle.sdp.client (2.0,12.2.1.3.0)
          - oracle.sdp.messaging (2.0,12.2.1.3.0)
          - oracle.wsm.idmrest.sharedlib (1.0,12.2.1.3)
          - oracle.wsm.seedpolicies (2.0,12.2.1.3)
          - orai18n-adf (11,11.1.1.1.0)
          - owasp.esapi (2.0,12.2.1)
- Page21: Services Targeting
  - AdminServer
    - admin
      - JDBCSystemResource
        - LocalSvcTblDataSource
        - WLSSchemaDataSource
        - mds-owsm
        - opss-audit-DBDS
        - opss-audit-viewDS
        - opss-data-source
      - ShutdownClass
        - DMSShutDown
      - StartupClass
        - AWT Applciation Context Startup Class
        - DMS-Startup
        - JRF Startup Class
        - ODL-Startup
        - WSM Startup Class
        - Web Services Startup Class
      - WLDFSystemResource
        - Module-FMDFW
  - Cluster
    - cluster_forms
      - JDBCSystemResource
        - opss-audit-DBDS
        - opss-audit-viewDS
        - opss-data-source
      - ShutdownClass
        - DMSShutDown
      - StartupClass
        - AWT Applciation Context Startup Class
        - DMS-Startup
        - JRF Startup Class
        - ODL-Startup
        - WSM Startup Class
        - Web Services Startup Class
      - WLDFSystemResource
        - Module-FMDFW
    - cluster_reports
      - JDBCSystemResource
        - opss-audit-DBDS
        - opss-audit-viewDS
        - opss-data-source
      - ShutdownClass
        - DMSShutDown
      - StartupClass
        - AWT Applciation Context Startup Class
        - DMS-Startup
        - JRF Startup Class
        - ODL-Startup
        - WSM Startup Class
        - Web Services Startup Class
      - WLDFSystemResource
        - Module-FMDFW
- The process should be completed withour error.
- Pack the domain and copy the domain configuration to managed machines.
  ```shell
  rm /tmp/cluster.jar -f
  cd /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin
  bash pack.sh -domain=/u02/domains/wlsd -managed=true -template=/tmp/cluster.jar -template_name="ofrwlsd"
  ```
  ```
  scp /tmp/cluster.jar weblogic@mspVM1:/tmp/cluster.jar

  scp /tmp/cluster.jar weblogic@mspVM2:/tmp/cluster.jar
  ```
- Exit `oracle` user: `exit`
- Use root user: `sudo su`
- Create service for node manager and admin server
  - Create service for admin server   
    Let's create the credentials for weblogic account.
    ```shell
    mkdir -p /u02/domains/wlsd/servers/admin/security
    cat <<EOF >/u02/domains/wlsd/servers/admin/security/boot.properties
    username=weblogic
    password=Secret123456
    EOF
    ```
    ```shell
    cat <<EOF >/etc/systemd/system/wls_admin.service
    [Unit]
    Description=WebLogic Adminserver service
    After=network-online.target
    Wants=network-online.target
    
    [Service]
    Type=simple
    WorkingDirectory="/u02/domains/wlsd"
    ExecStart="/u02/domains/wlsd/startWebLogic.sh"
    ExecStop="/u02/domains/wlsd/bin/customStopWebLogic.sh"
    User=oracle
    Group=oracle
    KillMode=process
    LimitNOFILE=65535
    Restart=always
    RestartSec=3
    
    [Install]
    WantedBy=multi-user.target
    EOF
    ```
  - Create service for node manager
    ```bash
    cat <<EOF >/etc/systemd/system/wls_nodemanager.service
    [Unit]
    Description=WebLogic nodemanager service
    After=network-online.target
    Wants=network-online.target
    [Service]
    Type=simple
    # Note that the following three parameters should be changed to the correct paths
    # on your own system
    WorkingDirectory="/u02/domains/wlsd"
    ExecStart="/u02/domains/wlsd/bin/startNodeManager.sh"
    ExecStop="/u02/domains/wlsd/bin/stopNodeManager.sh"
    User=oracle
    Group=oracle
    KillMode=process
    LimitNOFILE=65535
    Restart=always
    RestartSec=3
    [Install]
    WantedBy=multi-user.target
    EOF
    ```
- Start node manager and admin server, it takes about 10 min for admin server up.
  ```
  sudo systemctl enable wls_nodemanager
  sudo systemctl enable wls_admin
  sudo systemctl daemon-reload
  sudo systemctl start wls_nodemanager
  sudo systemctl start wls_admin
  ```

Now you are able to access admin console with `http://adminvm-ip:7001/console`, and Enterprise Manager with `http://adminvm-ip:7001/em`.

### Create domain on managed machine

Now, you have Forms and Reports configured in adminVM, let's apply the domain on mspVM1 and mspVM2. 

You can also follow the steps to apply domain on a new machine for new replicas.   

Configure domain on managed machine:
1. SSH to mspVM1 with command `ssh weblogic@mspVM1`
2. Use `root` user to set the ownership of domain package
  ```
  sudo su
  chown oracle:oracle /tmp/cluster.jar
  ```
2. Use `oracle` user, `sudo su - oracle`
3. Unpack the domain
  ```
  cd /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin
  bash unpack.sh -domain=/u02/domains/wlsd -template=/tmp/cluster.jar 
  ```
4. Make sure the node manager listen address is correct in `/u02/domains/wlsd/nodemanager/nodemanager.properties`
5. Exit oracle user with command `exit`
6. Use root user: `sudo su`
7. Create service for node manager
  ```shell
  cat <<EOF >/etc/systemd/system/wls_nodemanager.service
  [Unit]
  Description=WebLogic nodemanager service
  After=network-online.target
  Wants=network-online.target
  [Service]
  Type=simple
  # Note that the following three parameters should be changed to the correct paths
  # on your own system
  WorkingDirectory="/u02/domains/wlsd"
  ExecStart="/u02/domains/wlsd/bin/startNodeManager.sh"
  ExecStop="/u02/domains/wlsd/bin/stopNodeManager.sh"
  User=oracle
  Group=oracle
  KillMode=process
  LimitNOFILE=65535
  Restart=always
  RestartSec=3
  [Install]
  WantedBy=multi-user.target
  EOF
  ```
8. Start node manager
  ```
  sudo systemctl enable wls_nodemanager
  sudo systemctl daemon-reload
  sudo systemctl start wls_nodemanager
  ```

For initial setup, apply step 1-8 to mspVM2, and continue from [Create and start Reports components](#create-and-start-reports-components). 
For new replicas, apply step 1-8 to your new machines, and continue from [Start new replicas](#start-servers).

### Create and start Reports components
Now, you have node manager running on adminVM, mspVM1, mspVM2, and admin server up in adminVM.   
To successfully start Reports server, you must create and start the Reports components.

Let's create the ReportsToolsComponent using WLST.

- SSH to adminVM: `ssh weblogic@adminvm`
- Use `oracle` user: `sudo su - oracle`
- Use WLST to create Reports tools instance.
  ```
  cd /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin
  ./wlst.sh

  # connect admin server, replace adminvm-ip with the real value.
  connect("weblogic","Secret123456", "adminvm-ip:7001")

  createReportsToolsInstance(instanceName='reptools1', machine='mspVM1')
  createReportsToolsInstance(instanceName='reptools2', machine='mspVM2')

  # exit WLST
  exit()
  ```
  Those commands should be finished without error. You have to resolve error before moving on.
- Start Reports tools.
  ```
  cd /u02/domains/wlsd/bin
  # the commands require you to input password of node manager.
  ./startComponent.sh reptools1
  ./startComponent.sh reptools2
  ```
  The Reports tools should start successfully.

### Start Forms and Reports managed servers

Now, you have Reports tools components created and running, you are able to start the managed server and start the Reprots In-process server.

- Login admin console: http://adminvm-ip:7001/console
- Select Environment -> Servers -> Control
- Start WLS_FORMS1, WLS_FORMS2, WLS_REPORTS1 and WLS_REPORTS2.
- The servers should be running.

Now you are able to start Reports in process server from browser.
- Start reports server on mspVM1 with the URL
  - `http://<mspVM1-ip>:9002/reports/rwservlet/startserver`
  - You will get output `1|0` from the browser if the server is up.
- Start reports server on mspVM2 with the URL
  - `http://<mspVM2-ip>:9002/reports/rwservlet/startserver`
  - You will get output `1|0` from the browser if the server is up.

## Add Forms and Reports replicas

You are able to add Forms and Reports replicas by cloning machine and starting the corresponding components.

### Create a new machine for new replicas

Clone adminVM following [Clone machine for managed servers](#clone-machine-for-managed-servers), let's name the new machine with `mspVM3`.

### Create managed servers and Forms component

This is an example to start Forms and Reports on mspVM3, replace the machine name and component name with yours.

Firstly, you are required to create and start replated components. This document will leverage WLST offline mode to update the existing domain with new machine, new managed servers and new component, which requires restart on admin server to cause changes working.

Use WLST to add new replicas:
- SSH to adminVM and switch to root user
- Stop admin server: 
  ```
  sudo systemctl stop wls_admin
  kill -9 `ps -ef | grep 'Dweblogic.Name=admin' | grep -v grep | awk '{print $2}'`
  ```
- Switch to `oracle` user: `sudo su - oracle`
- Prepare Python script to create machine, managed servers and Forms component, modify the the value of Shell variables.
  ```shell
  # Modify the value of variables with yours.
  # Keep the index value the same with Azure Virtual Machine index
  index=3
  # Private IP address of the new machine
  vmIP="10.0.0.8"
  # Machine name
  vmName="mspVM${index}"
  # New Forms managed server name
  formsSvrName="WLS_FORMS${index}"
  # New Forms system component name
  formsSysCompName="forms${index}"
  # New Reports managed server name
  reportsSvrName="WLS_REPORTS${index}"
  cat <<EOF >create-forms3.py
  import sys, traceback
  vmIp="${vmIP}"
  vmName="${vmName}"
  formsSvrName="${formsSvrName}"
  formsSysCompName="${formsSysCompName}"
  reportsSvrName="${reportsSvrName}"
  formsSvrGrp=["FORMS-MAN-SVR"]
  reportsSvrGrp=["REPORTS-APP-SERVERS"]

  readDomain('/u02/domains/wlsd')
  print('\nCreate Machine ')
  cd('/')
  create(vmName,'Machine')
  cd('Machine/'+vmName)
  create(vmName,'NodeManager')
  cd('NodeManager/'+vmName)
  set('ListenAddress',vmIp)
  print('\nCreate ' + formsSvrName)
  cd('/')
  create(formsSvrName, 'Server')
  cd('/Servers/'+formsSvrName)
  set('ListenAddress',vmIp)
  set('ListenPort',int('9001'))
  set('Machine',vmName)
  cd('/')
  assign('Server',formsSvrName,'Cluster','cluster_forms')
  cd('/')
  setServerGroups(formsSvrName, formsSvrGrp)
  print('\nCreate '+ reportsSvrName)
  cd('/')
  create(reportsSvrName, 'Server')
  cd('/Servers/'+ reportsSvrName)
  set('ListenAddress',vmIp)
  set('ListenPort',int('9002'))
  set('Machine',vmName)
  cd('/')
  assign('Server',reportsSvrName,'Cluster','cluster_reports')
  cd('/')
  setServerGroups(reportsSvrName, reportsSvrGrp)
  print('\nCreate FORMS SystemComponent '+formsSysCompName)
  cd('/')
  create(formsSysCompName, 'SystemComponent')
  cd('/SystemComponent/'+formsSysCompName)
  cmo.setComponentType('FORMS')
  set('Machine', vmName)
  updateDomain()
  closeDomain()
  EOF
  ```
- Run the script with WLST offline mode, the script should be completed without errors.
  ```
  /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin/wlst.sh create-forms3.py
  ```
- Restart the domain and admin server to cause changes happen. It takes about 10 min for the admin server up.
  ```
  sudo systemctl start wls_admin
  ```
  Access http://adminvm-ip:7001/console from browser to make sure the admin server is up.

### Apply domain on the new machine

Now, you have finished updating the domain. Let's pack the domain and apply the domain to new machine.

- Pack the domain on adminVM:
  - SSH to adminVM: `ssh weblogic@adminVM`
  - Use oracle user: `sudo su - oracle`
  - Pack the domain
    ```shell
    rm /tmp/cluster.jar -f
    cd /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin
    bash pack.sh -domain=/u02/domains/wlsd -managed=true -template=/tmp/cluster.jar -template_name="ofrwlsd"
    ```
- Copy the domain package to mspVM3: `scp /tmp/cluster.jar weblogic@mspVM3:/tmp/cluster.jar`
- Create domain on mspVM3 and start node manager following [Create domain for managed servers](#create-domain-on-managed-machine)

### Create and start Reports tools

To enable Reports in process server, you are required to create and start Reports Tools Component. Follow the steps to enable Reports Tools component for new Reports replicas.

- SSH to adminVM: `ssh weblogic@adminVM`
- Use oracle user: `sudo su - oracle`
- Prepare Python script to create Reports component, please modify value of `adminVMIP`, `wlsUsername`, `wlsPassword` and `index`.
  ```shell
  # Private IP of adminVM
  adminVMIP=10.0.0.4
  # Username of WebLogic admin account
  wlsUsername="weblogic"
  # Password of WebLogic admin account
  wlsPassword="Secret123456"
  # Keep the index value the same with Azure Virtual Machine index
  index=3

  repToolsName="reptools${index}"
  repToolsTargetMachine="mspVM${index}"
  cat <<EOF >create-reportstools.py
  connect("${wlsUsername}","${wlsPassword}", "${adminVMIP}:7001")
  createReportsToolsInstance(instanceName="${repToolsName}", machine="${repToolsTargetMachine}")
  EOF
  ```
- Run the script using WLST online mode, the script should be completed without errors.
  ```
  /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin/wlst.sh create-reportstools.py
  ```
- Start Reports system components on mspVM3, the commands should be completed without errors.
  ```shell
  cd /u01/domains/wlsd/bin
  # the command will ask for node manager password
  ./startComponent.sh reptools2
  ```

### Start servers

Forms and Reports system components on mspVM3 are ready, node manager is up on mspVM3. Let's start the managed server from console portal.

- Login admin console: http://adminvm-ip:7001/console
- Select Environment -> Servers -> Control
- Start WLS_FORMS3, WLS_REPORTS3.
- The servers should be running.

Let's start Reports in process server from browser.
- Start reports server on mspVM3 with the URL
  - `http://<mspVM3-ip>:9002/reports/rwservlet/startserver`
  - You will get output `1|0` from the browser if the server is up.

If you have setup Applcation Gateway for load balancing, add the private IP of your new machine to backend pool. then the Applicatin Gateway is able to managed the traffic to the new replicas.

## Configure Private Application Gateway

### Create Application Gateway
- Expand the portal menu and select Create a resource.
- Select Networking and then select Application Gateway in the Featured list.
- Enter myAppGateway for the name of the application gateway and select your resource group.
- Select Region
- For Tier, select Standard.
- Under Configure virtual network
  - Select your vnet
  - Select your subnet
- Select Next : Frontends.
- For Frontend IP address type, select Private.
- Select Next:Backends.
- Select Add a backend pool.
- For Name, type appGatewayBackendPool.
- For Add backend pool without targets, select Yes. You'll add the targets later.
- Select Add.
- Select Next:Configuration.
- Under Routing rules, select Add a routing rule.
- For Rule name, type Rule-01.
- For Listener name, type Listener-01.
- For Frontend IP, select Private.
- Accept the remaining defaults and select the Backend targets tab.
- For Target type, select Backend pool, and then select appGatewayBackendPool.
- For HTTP setting, select Add new.
- For HTTP setting name, type http-setting-01.
- For Backend protocol, select HTTP.
- For Backend port, type 9001
- Accept the remaining defaults, and select Add.
- On the Add a routing rule page, select Add.
- Select Next: Tags.
- Select Next: Review + create.

Wait for the resources completed.

### Configure Backend Pool

- Go to Azure Portal, open the Applciation Gateway instance.
- Select Settings -> Backend pools - appGatewayBackendPool
  Add IP address of managed servers.
  - Item1
    - Type: IP address or FQDN
    - Target: private IP of mspVM1
  - Item2
    - Type: IP address or FQDN
    - Target: private IP of mspVM2
  - Item3
    - Type: IP address or FQDN
    - Target: private IP of mspVM3

Then you should be able to access Forms application using private IP of application gateway.
- http://app-gateway-ip/forms/frmservlet

Application Gateway has enabled monitoring the backend health:
  - Go to the application gateway from Azure Portal
  - Select Monitoring -> Backend health
  - The status of Servers should be Healthy.

## Troubleshoot
1. EM is slow    
    Enable caching of FMw Discovery data.
    - Login EM
    - Select WebLogic domain -> System MBean Browser -> Application Defined MBeans -> emoms.props -> Server.admin -> Application.em -> Properties -> emoms-prop
    - Click Operations
    - Select setProperty
    - Set the following properties
      1. oracle.sysman.emas.discovery.wls.FMW_DISCOVERY_USE_CACHED_RESULTS=true
      2. oracle.sysman.emas.discovery.wls.FMW_DISCOVERY_MAX_CACHE_AGE=7200000
      3. oracle.sysman.emas.discovery.wls.FMW_DISCOVERY_MAX_WAIT_TIME=10000
    - Select WebLogic domain -> Refresh WebLogic domain.
