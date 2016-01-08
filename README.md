# VMAX-Graphite

###Simplify the ability to push VMAX statistics to Graphite and other targets

To install dependancies run:
```bash
$ bundle install
```

**Rename settings.json.example to settings.json and make appropriate changes**

You can add multiple VMAX's to a Unisphere
```json
"symmetrix": [
	{ "sid": "00019xxxxx1" },
	{ "sid": "00019xxxxx2" }
]
```
You can have multiple Unisphere Objects
```json
{
	"ip": "x.x.x.x",
	"user": "smc",
	"password": "smc",
	"port": 8443,
	"version": 8,
	"symmetrix": [
		{ "sid": "00019xxxxx1" }
	]
}
```
Hosted Graphite? Need to add a prefix to the payload? Replace false with your UID.
```json
"graphite": {
	"enabled": true,
	"prefix": false,
	"host": "hostname",
	"port": "2003"
}
```
Toggle collection of component metrics by setting enabled to true or false
```json
"monitor": [
	{
		"scope": "Array",
		"enabled": false
	},
	{
		"scope": "FEDirector",
		"enabled": true,
		"children": [
			{
				"scope": "FEDirectorByPort",
				"enabled": true
			}
		]
	}
```
ToDo:
- Set monitor scope options to be Unisphere 7, unisphere 8 or both
- Native outut to Splunk

**Unisphere 8 Scope options:**

- Array
- BEDirector
- BeEmulation
- BePort
- Board
- CachePartition
- Core
- DSEPool
- DataFormat
- DatabaseByPool
- Database
- DeviceGroup
- DiskGroup
- Disk
- DiskTechPool
- EDSDirector
- EDSEmulation
- ExternalDiskGroup
- ExternalDisk
- FASTPolicy
- FEDirectorByPort
- FEDirector
- FICONEmulation
- FeEmulation
- FePort
- IMDirector
- IMEmulation
- PortGroup
- RDFA
- RDFDirector
- RDFEmulation
- RDFPort
- RDFS
- SRP
- SnapPool
- StorageGroupByTier
- StorageGroup
- StorageTier
- ThinPool
- ThinTier
- TierByStorageGroup
