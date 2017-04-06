#db
cat > /tmp/raid10 <<EOF
[vdisk0]
controllerid=0
raid=1
readpolicy=ara
writepolicy=wt
stripesize=64
cachepolicy=e
adisk=0:0:1,0:1:1
[vdisk1]
controllerid=1
raid=10
readpolicy=ara
writepolicy=wt
stripesize=64
cachepolicy=e
adisk=0:2:1,0:3:1,0:4:1,0:5:1
[vdisk2]
controllerid=2
raid=10
readpolicy=ara
writepolicy=wt
stripesize=64
cachepolicy=e
adisk=0:6:1,0:7:1,0:8:1,0:9:1
EOF

#other
cat > /tmp/raid1 <<EOF
[vdisk0]
controllerid=0
raid=1
readpolicy=ara
writepolicy=wt
stripesize=64
cachepolicy=e
adisk=0:0:1,0:1:1
[vdisk1]
controllerid=1
raid=1
readpolicy=ara
writepolicy=wt
stripesize=64
cachepolicy=e
adisk=0:2:1,0:3:1
[vdisk2]
controllerid=2
raid=1
readpolicy=ara
writepolicy=wt
stripesize=64
cachepolicy=e
adisk=0:4:1,0:5:1
[vdisk3]
controllerid=3
raid=1
readpolicy=ara
writepolicy=wt
stripesize=64
cachepolicy=e
adisk=0:6:1,0:7:1
EOF

#hadoop/storage hba卡不用raid

echo "…………. rst all disks …………."
raidcfg -ctrl -c=1 -ac=rst
echo "………. disks for raid10  ………."
raidcfg -i=/tmp/raid10
echo "…………… fast init ……………"
raidcfg -vd -c=1 -vd=0 -ac=fi
shutdown