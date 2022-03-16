# Migrate to HA clusters

## Contents

* [Prepare machines]()
* [Set up configuration]()
* [Configure HTTP Servers]()
* [Validate]()


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



