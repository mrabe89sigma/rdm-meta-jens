# Copyright (C) 2015 Shanghai Zhixing Information Technology Co.Ltd

require recipes-bsp/u-boot/u-boot-curie.inc

LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = "file://Licenses/gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263"

SRCBRANCH = "curie_v2014.04_3.14.28_1.0.0_ga"
REV = "af097c3f6874e6b9149548ea357590c15319a6c6"

SRCREPO = "rehsack"

SRC_URI += "file://bootsettings.patch \
	   "
