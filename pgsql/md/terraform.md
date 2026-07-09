Correct way to shrink an LVM disk (theoretical, not practical for cloud)
The only safe procedure (not supported in Terraform):

Create new smaller disk
pvcreate on new disk
vgextend old VG with new PV
pvmove all data from old disk → new disk
vgreduce to remove old PV
Destroy old large disk

Terraform shrink does NONE of this — it just truncates the block device.
