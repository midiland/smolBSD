.if defined(MINIMIZE) && ${MINIMIZE} == y
IMGSIZE=100
ADDPKGS=pkgin pkg_tarup pkg_install sqlite3 rsync curl
.endif
