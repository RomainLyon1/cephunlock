Cephunlock
============

Cephunlock is a bash script to unlock all your nova vms and cinder volumes after
a power outage. This script is able to manage different AZ and different
cinder volume type. Thus, it's able to manage, nova VM, nova vm with
attached volumes, "cinder VM" (+ attached) and standalone cinder volumes.

Very easy to use, just extact your UUID from an openstack command into a file.
Then just pass it as an argument, it makes very easy to apply it
to a specific scope.



Output example
-------------

```bash
bash unlock.sh github
[INF] Checking VM type of 98718bbf-4111-49c0-92c3-1670ba91cc42
[INF] This server booted on Nova disk
[CMD] rbd -p nova-vms lock list 98718bbf-4111-49c0-92c3-1670ba91cc42_disk
[INF] Disk 98718bbf-4111-49c0-92c3-1670ba91cc42_disk has no lock to remove
[INF] Checking if this nova vm use some cinder volumes
[INF] Unlocking 3f43a6ce-3123-4238-aaf8-52a92773ae81
[INF] remove_lock cinder-volumes volume-3f43a6ce-3123-4238-aaf8-52a92773ae81
[CMD] rbd -p cinder-volumes lock list volume-3f43a6ce-3123-4238-aaf8-52a92773ae81
[INF] Disk volume-3f43a6ce-3123-4238-aaf8-52a92773ae81 has no lock to remove
[INF] Checking VM type of 581e0dc7-fc9c-4477-85b4-cf0c7176b7a0
[INF] This server booted on Cinder volume
[INF] Unlocking 5fa83f67-06fe-4105-8847-087152475c29
[INF] remove_lock cinder-volumes volume-5fa83f67-06fe-4105-8847-087152475c29
[CMD] rbd -p cinder-volumes lock list volume-5fa83f67-06fe-4105-8847-087152475c29
[INF] Disk volume-5fa83f67-06fe-4105-8847-087152475c29 has no lock to remove
[INF] Checking VM type of 35b66329-85f4-4009-a5ef-4b60f47531a0
[INF] This server booted on Nova disk
[CMD] rbd -p nova-vms lock list 35b66329-85f4-4009-a5ef-4b60f47531a0_disk
[INF] Disk 35b66329-85f4-4009-a5ef-4b60f47531a0_disk has no lock to remove
[INF] Checking if this nova vm use some cinder volumes
[INF] Server 35b66329-85f4-4009-a5ef-4b60f47531a0 has no attached volumes
```



Requirement
-------------

Your machine will need to fill these requirements to execute the script:

- an admin access to your ceph cluster: rbd command will be used
- an admin access to your openstack: nova and cinder commands will problably run through many projects.
- you need to install jq where the script is executed


Configuration
-------------

This script can manage different AZ and different cinder volume type. Thank to a config
file in JSON. Currently, there is no way to generate it through a wizard so you have to
write yourself.

You will find below a way to generate an easy one,
just fill variables before executing it:

```bash
AZ=nova
NOVAPOOL=nova-vms
TYPE=__DEFAULT__
CINDERPOOL=cinder-volumes

cat >config.json <<EOF
{
  "nova": {
    "$AZ": "$NOVAPOOL"
  },
  "cinder": {
    "$TYPE": "$CINDERPOOL"
  }
}
EOF

```

If you have several AZ or several cinder volume type:

```bash
{
  "nova": {
    "az1": "ceph-pool-name",
    "az2": "ceph-pool-name"
  },
  "cinder": {
    "typessd": "ceph-pool-ssd",
    "typehdd": "ceph-pool-hdd"
  }
}

```

The script checks if the `config.json` exists and the syntax
before executing anything.

Usage
-------------

Advice: I stop all involved instances before using my script

Once all requirements have been met and your `config.json` have been generated
you need to extact all instances UUID or volumes UUID. You will find
below some examples:

```bash
# unlock all instances
openstack server --all-projects -f value -c ID > vms
bash cephunlock.sh vms

# unlock  all instances from specific hypervisor
openstack server --all-projects -f value -c ID --host hypervisorname > vms
bash cephunlock.sh vms

# unlock all volumes
openstack volume list --all-projects -f value -c ID > volumes
bash cephunlock.sh volumes
```

Maybe only one thing to update
-------------
Line 108 you will find how the block device is named in your Ceph pool.
You could need to update the script to match the value in your cinder.conf (volume_name_template).
The script uses the default value.


Author Information
------
Romain CHANU
Université Claude Bernard Lyon1
