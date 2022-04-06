# Create High Vailable Oracle Forms and Reports clusters on Azure (WIP)

This document guides you to create high vailable Oracle Forms and Reports clusters on Azure VMs, including:
- Create Oracle Forms and Reports clusters with 2 replicas.
- Create load balancing with Azure Application Gateway
- Scale up with new Forms and Reports replicas
- Create High Available Adminitration Server
- Troubleshooting

## Contents

* [Prerequisites](#prerequisites)
* [Provision Azure WebLogic admin offer](#provision-azure-weblogic-admin-offer)
* [Create Oracle Database](#create-oracle-database)
* [Create Windows VM and set up XServer](#create-windows-vm-and-set-up-xserver)
* [Install Oracle Fusion Middleware Infrastructure](#install-oracle-fusion-middleware-infrastructure)
* [Install Oracle Froms and Reports](#install-oracle-froms-and-reports)
* [Clone machine for managed servers]()
* [Create schemas using RCU](#create-schemas-using-rcu)
* [Configure Forms and Reports with a new domain](#configure-forms-and-reports-in-the-existing-domain)
* [Create Load Balancing with Azure Application Gateway](#create-ohs-machine-and-join-the-domain)
* [Scale up with new Forms and Reports replicas](#apply-jrf-to-managed-server)
* [Create High Available Adminitration Server]()
* [Troubleshooting]()

## Prerequisites

An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/dotnet).

## Provision Azure WebLogic Virtual Machine

Azure provides a serie of Oracle WebLogic base image, it'll save your effor for Oracle tools installation.
This document will setup Oracle Forms and Reports based on the Azure WebLogic base image, follow the steps to provison a machine with WebLogic installed:

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

If you are following the document to create Oracle database, write down the credentials to create Forms schema, username and password should be: `sys/OraPasswd1`

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
- Open Port
  ```
  # for XServer
  sudo firewall-cmd --zone=public --add-port=6000/tcp
  # for admin server
  sudo firewall-cmd --zone=public --add-port=7001/tcp
  sudo firewall-cmd --zone=public --add-port=7002/tcp
  # for node manager
  sudo firewall-cmd --zone=public --add-port=5556/tcp
  # for forms and reports
  sudo firewall-cmd --zone=public --add-port=9001/tcp
  sudo firewall-cmd --zone=public --add-port=9002/tcp
  # for clusters
  sudo firewall-cmd --zone=public --add-port=7100/tcp
  sudo firewall-cmd --zone=public --add-port=8100/tcp
  sudo firewall-cmd --zone=public --add-port=7574/tcp
  sudo firewall-cmd --runtime-to-permanent
  sudo systemctl restart firewalld
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

Create the a snapshot from adminVM OS disk:
- Open Azure portal, stop adminVM.
- Create a snapshot from OS disk.


Create VMs for Forms and Reports replicas based on the snapshot:
1. Create a disk from the snapshot.
2. Create a VM with name `mspVM1` on the disk.
3. ssh to the machine, use `root` user.
    - Set hostname: `hostnamectl set-hostname mspVM1`
4. Repeat step1-3 for `mspVM2`, make sure setting hostname with `mspVM2`.

Now, you have three machine ready to configure Forms and Reports: **adminVM**, **mspVM1**, **mspVM2**.

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
- Page19: Assign Servers to Machine
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
- Apply step 1-8 to msspVM2.

## Create and start Reports components
Now, you have node manager running on adminVM, mspVM1, mspVM2, and admin server up in adminVM.   
To successfully start Reports server, you must create and start the Reports components.

Let's create the ReportsToolsComponent using WLST.

- SSH to adminVM: `ssh weblogic@adminvm`
- Use `oracle` user: `sudo su - oracle`
- Use WLST to create Reports tools instance.
  ```
  cd /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin
  ./wlst.sh

  # connect admin server
  connect("weblogic","Secret123456", "adminvn-ip:7001")

  createReportsToolsInstance(instanceName='reptools1', machine='mspVM1')
  createReportsToolsInstance(instanceName='reptools2', machine='mspVM2')

  # exit WLST
  exit()
  ```
  Those commands should be finished without error. You have to resolve error before moving on.
- Start Reports tools.
  ```
  cd /u02/domains/wlsd/bin
  ./startComponent.sh reptools1
  ./startComponent.sh reptools2
  ```
  The Reports tools shoud start successfully.

## Start Forms and Reports managed servers

Now, you have Reports tools components created and running, you are able to start the managed server and start the Reprots In-process server.

- Login admin console: http://adminvm-ip:7001/console
- 










## Validation

- Admin console: `http://<adminvm-ip>:7001/console`
- em: `http://<adminvm-ip>:7001/em`
- forms: `http://<adminvm-ip>:9001/forms/frmservlet` and `http://<ohs-ip>:7777/forms/frmservlet`
  - Please use JRE 32 bit + IE to access Forms.
- reports: `http://<adminvm-ip>:9002/reports/rwservlet` and `http://<ohs-ip>:7777/reports/rwservlet`
- Validate WLS cluster, if you have an application deployed to WLS cluster, you will be able to access the app via `http://<ohs-ip>:7777/<app-path>`
  ```
  curl http://<ohs-ip>:7777/weblogic/ready
  ```

