#!
# CoreDB/local/settings.tcl
# default settings and structure list for sqlite3 CoreDB.

dputs "Loading local/settings.tcl"

#Extended settings.

#############################
#Set chan Flag permissions  #
#############################
#Move to lists and add API, switch for eggdrop compat.
set  utilsflag m
set  reportingflag n
set  testingflag m

########################
#Set chan Flags        #
########################
#Move to lists and add API, switch for eggdrop compat.
setudef flag radio
setudef flag staff
setudef flag development
setudef flag drone

#### ARRAYS ####
array set userit {};

#### LISTS ####
set CoreDB_settings_fields [list "uuid" "keyword" "value" "created" "modified"]

#Default values to populate db on first run.
array set CoreDB_settings_defaults {
    trigger       			"~"
    version              	"Development version"
    logo                    "\[CoreDB\]:"
    logprefix               "\[CoreDB\]:"
    debugprefix             "\[Debug\]:"
    debug                   "1"
    urltitle                "1"
    agent                   "Mozila"
    plugin               	"1"
    nickservmask            "NickServ"
    chanservmask            "ChanServ"
    nickpass                ""
    initservpassneeded      "1"
    topictmp                ""
}

# IAL fields
# set CoreDB_IAL_fields [list "uuid" "ntu" "nta" "nttrig" "nttc" "ntgc" "ntts" "ntflag"]

dputs "Loaded local/settings.tcl"
