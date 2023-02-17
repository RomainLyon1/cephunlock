Cephunlock
============

Cephunlock is a bash script to unlock all your nova vms and cinder volumes after
a power outage. This script is able to manage different AZ and different
cinder volume type. Thus, it's able to manage, nova VM, nova vm with
attached volumes, "cinder VM" (+ attached) and standalone cinder volumes.

Very easy to use, just extact your UUID from an openstack command into a file.
Then just pass it as an argument, it makes very easy to apply it
to a specific scope.



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

The script check sif the `config.json` exists and the syntax
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
