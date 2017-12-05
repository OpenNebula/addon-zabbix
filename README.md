# OpenNebula Zabbix Template

Zabbix template for monitoring OpenNebula cloud.

## Description

Template includes preconfigured parameters, graphics and triggers for complex monitoring OpenNebula cloud.

## Development

To contribute bug patches or new features, you can use the github Pull Request model. It is assumed that code and documentation are contributed under the Apache License 2.0. 

More info:
* [How to Contribute](http://opennebula.org/addons/contribute/)
* Support: [OpenNebula user forum](https://forum.opennebula.org/c/support)
* Development: [OpenNebula developers forum](https://forum.opennebula.org/c/development)
* Issues Tracking: [Github issues](https://github.com/kvaps/opennebula-addon-zabbix/issues)

## Author

* [kvaps](mailto:kvapss@gmail.com)

## Compatibility

This add-on is compatible with OpenNebula 4.6+

## Requirements

### OpenNebula Front-end Server

* Installed `xmlstarlet` package.
* Installed and configured `zabbix-agent`.

## Limitations

Common values of all resources is gathering by default.
Discovery resources is not supported for now, but you can specify it manually.

## Installation

For install or update agent script on OpenNebula server execute:

```
curl -o /etc/zabbix/zabbix_agentd.d/opennebula_zabbix.conf https://raw.githubusercontent.com/kvaps/opennebula-addon-zabbix/master/opennebula_zabbix.conf
curl --create-dirs -o /usr/libexec/zabbix-extensions/scripts/one.sh https://raw.githubusercontent.com/kvaps/opennebula-addon-zabbix/master/one.sh
chmod +x /usr/libexec/zabbix-extensions/scripts/one.sh
systemctl restart zabbix-agent
```
Also the authentification file is required, you can use oneadmin account here:
```
mkdir -p /var/lib/zabbix/.one/
cp /var/lib/one/.one/one_auth /var/lib/zabbix/.one/one_auth
chown -R zabbix:zabbix /var/lib/zabbix
```

You can check agent configuration. Just run this command on Zabbix server:
```
zabbix_get -s <your_server> -k one.collect[host]
```
* If you see `0` - everything is fine.
* If you see `1` - something wrong. Please check: User `zabbix` should have opportunity for run `onehost`/`onevm` commands.

Download and improt zabbix template:

 * **[zbx_template_opennebula.xml](https://github.com/kvaps/opennebula-addon-zabbix/raw/master/zbx_template_opennebula.xml)**

## Configuration
### Configuring Zabbix-Server

By default items configured for generalized information of resources.
If you want to set target to specific datastores you should update items in zabbix interface.

**For example:**

Go to the Templates --> Template OpenNebula --> Items

If you want to monitor specufuc datastore insted all, replace items like:
    	
```
one.datastore.free_space --> one.datastore.free_space[101]
one.datastore.pfree_space --> one.datastore.pfree_space[101]
one.datastore.total_space --> one.datastore.total_space[101]
one.datastore.used_space --> one.datastore.used_space[101]
one.datastore.pused_space --> one.datastore.pused_space[101]
```

  *where `101` - datastore id*

If you want to monitor specufuc network for free leases insted all, replace items like:
    	
```
one.vnet.free_leases --> one.vnet.free_leases[23]
one.vnet.pfree_leases --> one.vnet.pfree_leases[23]
one.vnet.total_leases --> one.vnet.total_leases[23]
one.vnet.used_leases --> one.vnet.used_leases[23]
one.vnet.pused_leases --> one.vnet.pused_leases[23]
```

  *where `23` - network id*

If you want monitor multiple individual resources you need to create more items and separated triggers.
You can also use `avg` parameter if you want have average data from all resources instead common.

## Usage 

You need to attach template to your OpenNebula host in Zabbix server.
After that you will have custom metrics and graphics.

## Tuning & Extending

You can create custom items and triggers, open `one.sh` file, for check which parameters is supported.

## Optimizations

Agent script already use caching when retrieves information from oned daemon.
No specufic configuration is needed.
