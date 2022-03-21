# Migrate to HA clusters

## Contents

* [Prepare machines](#prepare-machines)
* [Set up configuration](#set-up-configuration)
* [Configure HTTP Servers](#configure-http-servers)
* [Validate](#validate)

This document will create high available Oracle Forms and Reports clusters shown in the diagram.

![Oracle Forms and Reports Architecture](ha-forms-reports-architecture.jpg)

## Prepare machines

As we dicussed on 2022-03-16, Swisslog configuration is ready on adminVM, we will create managed servers based on the snapshot of adminVM.

The section will create the following machines:
- Machines for Forms: formsVM1, formsVM2, formsVM3, formsVM4
- Machine for Reports: reportsVM1, reportsVM2, reportsVM3, reportsVM4.

Create the snapshot from adminVM:
- Login to admin console
  - Select wlsd -> Environment -> Servers -> Control, stop WLS_FORMS and WLS_REPORTS
  - Select wlsd -> Environment -> Clusters -> cluster1 -> Control, stop all the servers.
- ssh to adminVM, run the following command to stop the services:
  ```
  # switch to root user
  sudo su -
  # stop admin server
  sudo systemctl stop wls_admin
  # stop node manager
  sudo systemctl stop wls_nodemanager

  # stop the firewall
  sudo systemctl stop firewalld
  ```
- Open Azure portal, stop adminVM.
- Create a snapshot of OS disk.


Create VMs for Forms and Reports based on the snapshot:
- Create a disk on the snapshot of adminVM.
- Create a VM with name `formsVM1` on the disk.
- ssh to the machine, use `root` user.
  - Set hostname: `hostnamectl set-hostname formsvm1`
  - Remove wlsd application folder: `rm /u01/app/wls/install/oracle/middleware/oracle_home/user_projects/applications/wlsd -f -r`
  - Remove wlsd domain folder: `rm /u01/domains/wlsd -f -r`
  - Stop the services
    ```bash
    sudo systemctl stop wls_nodemanager
    sudo systemctl stop wls_admin

    ps -aux | grep "oracle"
    ```

    Kill the WLS process. There should have only one process like:

    ```text
    [root@formsvm3 ~]# ps -aux | grep "oracle"
    root     18756  0.0  0.0 114292  2360 pts/0    S+   09:12   0:00 grep --color=auto oracle
    ```
- Repeat above steps for `formsVM*` and `reportsVM*`.

Create VMs for HTTP Server based on snapshot of **mspVM1**, we got that before.
- Create VM `ohsVM1` if you don't have one
- Create VM `ohsVM2` if you don't have one
- Create VM `ohsVM3`

# Set up configuration

- Use the windowsXServer.
- SSH to adminVM
- Use `oracle` user
- Set env variable: `export DISPLAY=<yourWindowsVMVNetInternalIpAddress>:0.0`, e.g. `export DISPLAY=10.0.0.8:0.0`
- `bash  /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin/config.sh`
- Page1:
  - Update an existing domain
  - location: /01/domains/wlsd
- Page2: no change
- Page3: no change
  - Click "Get RCU Configuration", you should see message "Successfully Done".
- Page4: no change
- Page6:
  - Topology
  - System Components
  - Deployment and Services
- Page7: Managed Servers
  - Delete WLS_FORMS and WLS_REPORTS
  - No managed server listed.
- Page8: Clusters
  - cluster_forms
  - cluster_reports
- Page9: Server Templates
  - Add forms-dynamic-cluster-template
    - Name: forms-dynamic-cluster-template
    - Listen Port: 8001
    - SSL Port: 8100
  - Add reports-dynamic-cluster-template
    - Name: reports-dynamic-cluster-template
    - Listen Port: 9001
    - SSL Port: 8100
  - There should be 4 templates listed: wsm-cache-server-template, wsmpm-server-template, forms-dynamic-cluster-template, reports-dynamic-cluster-template
- Page10: Dynamic Clusters
  - cluster_forms
    - Server Template: forms-dynamic-cluster-template
    - Server Name Prefix: forms
    - Dynamic Cluster Size: 2
    - Machine Name Match Expression: machine-formsVM*
    - Calculated Machine Names: true
    - Calculated Listen Ports: true
  - cluster_reports
    - Server Template: reports-dynamic-cluster-template
    - Server Name Prefix: reports
    - Dynamic Cluster Size: 2
    - Machine Name Match Expression: machine-reportsVM*
    - Calculated Machine Names: true
    - Calculated Listen Ports: true
- Page11: Coherence Cluster
  - defaultCoherenceCluster
- Page12: Machines
  - adminVM
    - Node Manager Listen Address: `<private-ip-of-adminvm>`
    - Node Manager Listen Port: 5556
  - machine-formsVM1
    - Node Manager Listen Address: `<private-ip-of-formsvm1>`
    - Node Manager Listen Port: 5556
  - machine-formsVM2
    - Node Manager Listen Address: `<private-ip-of-formsvm2>`
    - Node Manager Listen Port: 5556
  - machine-formsVM3
    - Node Manager Listen Address: `<private-ip-of-formsvm3>`
    - Node Manager Listen Port: 5556
  - machine-formsVM4
    - Node Manager Listen Address: `<private-ip-of-formsvm4>`
    - Node Manager Listen Port: 5556
  - machine-reportsVM1
    - Node Manager Listen Address: `<private-ip-of-reportsvm1>`
    - Node Manager Listen Port: 5556
  - machine-reportsVM2
    - Node Manager Listen Address: `<private-ip-of-reportsvm2>`
    - Node Manager Listen Port: 5556
  - machine-reportsVM3
    - Node Manager Listen Address: `<private-ip-of-reportsvm3>`
    - Node Manager Listen Port: 5556
  - machine-reportsVM4
    - Node Manager Listen Address: `<private-ip-of-reportsvm4>`
    - Node Manager Listen Port: 5556
  - ohsVM1
    - Node Manager Listen Address: `<private-ip-of-ohsvm1>`
    - Node Manager Listen Port: 5556
  - ohsVM2
    - Node Manager Listen Address: `<private-ip-of-ohsvm2>`
    - Node Manager Listen Port: 5556
  - ohsVM3
    - Node Manager Listen Address: `<private-ip-of-ohsvm1>`
    - Node Manager Listen Port: 5556
- Page13: Assign Servers to Machines
  - adminVM
    - admin
- Page14: Virtual Targets
  - no
- Page15: Partitions
  - no
- Page16:
  - forms1: FORMS, 3600, 0
  - forms2: FORMS, 3600, 0
  - forms3: FORMS, 3600, 0
  - forms4: FORMS, 3600, 0
- Page17: Assign System Component
  - machine-formsVM1
    - SystemComonent
      - forms1
  - machine-formsVM2
    - SystemComonent
      - forms2
  - machine-formsVM3
    - SystemComonent
      - forms3
  - machine-formsVM4
    - SystemComonent
      - forms4
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
      - Libraries: keep default
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
        - fads-dbtools-library
        - fads-sqlcl-library
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
          - fads-dbtools-library
          - fads-sqlcl-library
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
- Page21: Service Targeting
  - Admin Server
    - keep default
  - Cluster
    - cluster_forms
      - JDBSSystemResource
        - opss-audit-DBDS
        - opss-audit-viewDS
        - opss-data-source
    - cluster_reports
      - JDBSSystemResource
        - opss-audit-DBDS
        - opss-audit-viewDS
        - opss-data-source
- The process should be completed withour error.
- Exit oracle user, use `root`
- Pack domain
  ```
  rm /tmp/cluster.jar
  cd /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin
  bash pack.sh -domain=/u01/domains/wlsd -managed=true -template=/tmp/cluster.jar -template_name="ofrwlsd"
  ```
- Copy the cluster.jar to formsVM*, reportsVM* and ohsVM*.
  ```
  sudo scp /tmp/cluster.jar weblogic@mspVM*:/tmp/cluster.jar
  ```

Apply the configuration to managed server.
- SSH to formsVM1. 
- Use `root` user
   ```
   chown oracle:oracle /tmp/cluster.jar
   ```
- Make sure there is not process for WLS and nodemanager, `ps -aux | grep "oracle"`
  ```
  # if there are process then run the command to kill the service.
  # stop admin server
  sudo systemctl stop wls_admin
  # stop node manager
  sudo systemctl stop wls_nodemanager

  kill -9 processid

  rm /u01/domains/wlsd -f -r
  ```
- Disable firewall. 
  ```
  sudo systemctl stop firewalld
  sudo systemctl disable firewalld
  ```
- Disable the wls_admin service
  ```
  systemctl disable wls_admin
  ```
- Use `oracle` user, `sudo su - oracle`
- Unpack the domain
  ```
  cd /u01/app/wls/install/oracle/middleware/oracle_home/oracle_common/common/bin
  bash unpack.sh -domain=/u01/domains/wlsd -template=/tmp/cluster.jar 
  ```
- Make sure the node manager listen address is correct in `/u01/domains/wlsd/nodemanager/nodemanager.properties`
- Exit oracle user
- Start node manager
  ```
  sudo systemctl start wls_nodemanager
  ```
- Apply above steps to `formsVM*`, `reportsVM*` and `ohsVM*`.


Restart the admin server:
- Use `root` user, stop the wls_admin service.
  ```
  sudo systemctl stop wls_admin

  # double check the admin server process
  ps -aux | grep "Dweblogic.Name=admin"

  # please kill the process if there is
  kill -9 <admin-process-id>
  ```
- Start the service again
  ```
  sudo systemctl start wls_admin

  # you can check the status
  sudo systemctl status wls_admin
  ```
You shoud be able to access the admin console once it's ready.


Start Forms and Reports server.
- Login admin console
  - Select wlsd -> Environment -> Clusters -> cluster_reports -> Control, start all the servers.
  - Select wlsd -> Environment -> Clusters -> cluster_forms -> Control, start all the servers.

## Configure HTTP Servers

Now you have the Forms and Reports servers running, let's configure the HTTP Server.

- Login EM portal.
- Select WebLogic Domain -> Administration -> OHS Instances
- Click the lock icon and select Lock & Edit
- Click Create button to create OHS instance.
  - ohs1
    - Name: ohs1
    - Machine name: ohsVM1
  - ohs2
    - Name: ohs2
    - Machine name: ohsVM2
  - ohs3
    - Name: ohs3
    - Machine name: ohsVM3
- Click the lock icon and Activate changes.

Before we start the OHS servers, we have to configure the entries.
- SSH to ohsVM1
- Use `oracle` user
- Edit mod_wl_ohs.conf    
  Input the IP placehoder with real private IP, make sure the ports are correct.  
  Replace `ohs1` with the expected ohs component name.
  ```
  cat <<EOF >/u01/domains/wlsd/config/fmwconfig/components/OHS/instances/ohs1/mod_wl_ohs.conf
  # NOTE : This is a template to configure mod_weblogic.

  LoadModule weblogic_module   "\${PRODUCT_HOME}/modules/mod_wl_ohs.so"

  # This empty block is needed to save mod_wl related configuration from EM to this file when changes are made at the Base Virtual Host Level
  <IfModule weblogic_module>
        WLIOTimeoutSecs 900
        KeepAliveSecs 290
        FileCaching ON
        WLSocketTimeoutSecs 15
        DynamicServerList ON
        WLProxySSL ON
        WebLogicCluster <formsvm1-ip>:8002,<formsvm2-ip>:8003,<formsvm3-ip>:8004,<formsvm4-ip>:8005
  </IfModule>

  <Location /forms/>
        SetHandler weblogic-handler
        DynamicServerList ON
        WLProxySSL ON
        WebLogicCluster <formsvm1-ip>:8002,<formsvm2-ip>:8003,<formsvm3-ip>:8004,<formsvm4-ip>:8005
  </Location>

  <Location /reports/>
        SetHandler weblogic-handler
        DynamicServerList ON
        WLProxySSL ON
        WebLogicCluster <reportsvm1-ip>:9002,<reportsvm2-ip>:9003,<reportsvm3-ip>:9004,<reportsvm4-ip>:9005
  </Location>
  EOF  
  ```
  Replace `ohs1` with the expected ohs component name.
  ```
  COMPONENT_NAME="ohs1"
  mkdir /u01/domains/wlsd/config/fmwconfig/components/OHS/${COMPONENT_NAME}
  cp /u01/domains/wlsd/config/fmwconfig/components/OHS/instances/${COMPONENT_NAME}/mod_wl_ohs.conf /u01/domains/wlsd/config/fmwconfig/components/OHS/${COMPONENT_NAME}/mod_wl_ohs.conf
  ```

- Apply above steps to ohsVM2 and ohsVM3.

Start OHS servers.
- Login EM portal.
- Select WebLogic Domain -> Administration -> OHS Instances
- Click `ohs1` and start.
- Click `ohs2` and start.
- Click `ohs3` and start.

## Validate

Validate the Forms testing application.
- Make sure the application is running in each managed server.
  - Forms
    - `http://<formsvm1-ip>:8002/forms/frmservlet`
    - `http://<formsvm2-ip>:8003/forms/frmservlet`
    - `http://<formsvm3-ip>:8004/forms/frmservlet`
    - `http://<formsvm4-ip>:8005/forms/frmservlet`
  - Reports
    - `http://<reportsvm1-ip>:9002/reports/rwservlet`
    - `http://<reportsvm2-ip>:9003/reports/rwservlet`
    - `http://<reportsvm3-ip>:9004/reports/rwservlet`
    - `http://<reportsvm4-ip>:9005/reports/rwservlet`
- Make sure the OHS server are available, find logs in access.log of each server to check the loadbalancing.
  - `http://ohs1-ip:7777/forms/frmservlet`
  - `http://ohs2-ip:7777/forms/frmservlet`
  - `http://ohs3-ip:7777/forms/frmservlet`

## Troubleshooting
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

