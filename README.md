# Install Oracle Forms and Reports on the top of WebLogic dynamic cluster

## Contents

* [Prerequisites]()
* [Provision Azure WebLogic dynamic cluster offer]()
* [Create Windows VM and set up XServer]()
* [Create Oracle Database]()
* [Install Oracle Fusion Middleware Infrastructure]()
* [Install Oracle Froms and Reports]()
* [Create schemas using RCU]()
* [Configure Forms and Reports in the existing domain]()
* [Verify]()

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
  - Upload the certificate in resource/certs/mykeystore.jks
  - Password: `mypassword`
  - Type of the certifcate: `JKS`

- Keep other blads as default. Click **Review + create**.

It will take half an hour for the offer completed.

Scale out the server and leave the machine to install Forms and Reports.
- Login admin console.
- Lock & edit
- Select **Environment** -> **Clusters** -> **cluster1** -> **Control** -> **Scaling**
- **Desired Number of Running Servers:** 1
- Click OK
- Activate
- Select **Environment** -> **Clusters** -> **cluster1** -> **Control** -> **Start/Stop**
- Force stop all the servers.

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

- SSH to **adminVM**, **mspVM1**, **mspVM2** and **ohsVM**, open ports for XServer by running the following commands:

  ```
  sudo firewall-cmd --zone=public --add-port=6000/tcp
  sudo firewall-cmd --runtime-to-permanent
  sudo systemctl restart firewalld
  ```

## Create Oracle Database

Follow this [document](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/oracle/oracle-database-quick-create) to create an Oracle database


## Install Oracle Fusion Middleware Infrastructure

Download Oracle Fusion Middleware Infrastructure installer from https://download.oracle.com/otn/nt/middleware/12c/122140/fmw_12.2.1.4.0_infrastructure_Disk1_1of1.zip

Unzip the file and copy `fmw_12.2.1.4.0_infrastructure.jar` to **adminVM**, **mspVM1**, **mspVM2** and **ohsVM**.
Make sure `fmw_12.2.1.4.0_infrastructure.jar` is copied to /u01/oracle/fmw_12.2.1.4.0_infrastructure.jar, owner of the file is `oracle`.

Now let's use the XServer to install Oracle Fusion Middleware Infrastructure in the *adminVM**, **mspVM1**, **mspVM2** and **ohsVM**.

Steps to install Oracle Fusion Middleware Infrastructure in adminVM:

- RDP to windowsXServer.
- Click XLaunch from the desktop.
  - Multiple windows, Display number: `-1`, click Next.
  - Select "Start no client"
  - Check Clipboard and Primary Selection, Native opengl, Disable access control. Click Next.
  - Click Finish.

- Open CMD
- SSH to adminVM with command `ssh weblogic@adminVM`
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


Steps to install Oracle Fusion Middleware Infrastructure in managedServerVM:
- Use the windowsXServer.
- Open CMD
- SSH to mspVM1 with command `ssh weblogic@mspVM1`
- Stop WebLogic process
    ```
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

Install Oracle Fusion Middleware Infrastructure to all the managed server VMs following the above steps.

## Install Oracle Froms and Reports

- Download wget.sh from https://www.oracle.com/middleware/technologies/forms/downloads.html#
  - Oracle Fusion Middleware 12c (12.2.1.4.0) Forms and Reports for Linux x86-64 for (Linux x86-64)
  - Oracle Fusion Middleware 12c (12.2.1.4.0) Forms and Reports for Linux x86-64 for (Linux x86-64)
- Copy the wget.sh to `/u01/oracle/wget.sh`
- Use the windowsXServer.
- Use `oracle` user
- Set env variable: `export DISPLAY=<yourWindowsVMVNetInternalIpAddress>:0.0`, e.g. `export DISPLAY=10.0.0.8:0.0`
- Edit the script, replace `--ask-password` with `--password <your-sso-password>`
- Run the script in the admin machine and managed machines
  - `bash wget.sh`
- Unzip the zip files: ` unzip "*.zip"`, you will get `fmw_12.2.1.4.0_fr_linux64.bin` and `fmw_12.2.1.4.0_fr_linux64-2.zip`
- Remove the zip files to save space
  ```
   rm V983392-01_1of2.zip
   rm V983392-01_2of2.zip
  ```
- Install Forms: `./fmw_12.2.1.4.0_fr_linux64.bin`
  - The installation Dialog show prompts, if no, set `export PS1="\$`, run `./fmw_12.2.1.4.0_fr_linux64.bin` again.
  - Inventory Directory: `/u01/oracle/oraInventory`
  - Operating System Group: `oracle`
  - Step 3:
    - Oracle Home: `/u01/app/wls/install/oracle/middleware/oracle_home`
  - Step 4:
    - Forms and Reports Deployment
  - Step 5:
    - JDK Home: /u01/app/jdk/jdk1.8.0_291
  - Step 6: if there are error of operation system packages, install the conrresponding package and run `./fmw_12.2.1.4.0_fr_linux64.bin` again.
    - Error like "Checking for compat-libcap1-1.10;Not found", then run `sudo yum install compat-libcap1`
        ```
        sudo yum install compat-libcap1
        sudo yum install compat-libstdc++-33
        sudo yum install libstdc++-devel
        sudo yum install gcc
        sudo yum install gcc-c++
        sudo yum install ksh
        sudo yum install glibc-devel
        sudo yum install libaio-devel
        sudo yum install motif
        ```


 

