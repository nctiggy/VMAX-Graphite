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
**Unisphere 7 Scope options:**

- Array
- FEDirector
- BEDirector
- RDFDirector
- Disk
- DeviceGroup
- StorageGroup
- RDFS
- RDFA
- CachePartition
- DiskGroup
- DSEPool
- SnapPool
- ThinPool
- ThinTier
- StorageTier
- FEDirectorByPort
- FASTPolicy
- TierByStorageGroup
- StorageGroupByTier


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
