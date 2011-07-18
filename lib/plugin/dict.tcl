#!
##############################################################################################
# lib/plugin/dict.tcl
##############################################################################################
# see doc/plugins.txt for changelog, history

dputs "Loading lib/plugin/dict.tcl"
#Add per channel options, and global flags

#           min hr month day year
bind time - "00 01 * * *" defdb_upkeep ;# Run at 1am

CoreDB::add::Command [list "$$" "pub_dict" 1];

#DefDB init.
set DefDB_File "var/definitions.db3"

proc defdb_init {} {
    global DefDB_File
    if {![file exist $DefDB_File]} {
        die "DefDB is not setup Correctly.\
        Run console/db_manager.tcl init_DefDB"
    } else {
        sqlite3 DefDB $DefDB_File
        DefDB timeout 2000
    }
    ##integrity check
    set res [lindex [string tolower [DefDB eval { PRAGMA integrity_check; }]] 0]
    if {$res != "ok"} {
        die "DefDB::init::ERROR::Integrety check failed !\
        Run console/db_manager.tcl repair_DefDB"
        unset res
        return
    } else {
        putlog "DefDB::init::Integrety check passed."
        unset res
    }
    putlog "DefDB::init::Setting PRAGMA values."
    DefDB eval {;
        PRAGMA encoding = "UTF-8";
        PRAGMA foreign_keys = ON;
    };
    set res [DefDB eval { PRAGMA foreign_keys; }]
    if {$res == 0} {
        putlog "DefDB::init::ERROR::Possible serious error, execution halted. PRAGMA \
        foreign_keys is $res"
        unset res; return
    } elseif {$res == 1} {
        putlog "DefDB::init::foreing_keys:$res"
        unset res
    }
putlog "DefDB::init::Finished DefDB init."
}

if {![info exists defbinit]} {
    defdb_init
    set defdbinit 1
}

proc pub_dict {nick host hand channel text} {
    global DefDB
    set word [string tolower [lindex [split $text] 0]]
    #set word [lindex [split $text] 0]
    if {[string match "*\\?" $word]} {
        set word [string trimright $word "?"]
        if {[DefDB exists {SELECT 1 FROM definitions WHERE word=$word}]} {
            set result [DefDB eval {SELECT * FROM definitions WHERE word=$word}]
            #add a when, modified, or w/e type options as well.
            if {[string tolower [lindex [split $text] 1]] == "who"} {
                putmsg $channel "[CoreDB_logo] \002$word\002: Set by: [lindex $result 5]"
            } else {
                putmsg $channel "[CoreDB_logo] \002$word\002: [lindex $result 4]"
            }
        }
    } elseif {$word == "=="} {
        # Maybe, add support for other users to use this later.
        if {![matchattr $nick +n]} { return }
            set newword [string tolower [lindex [split $text] 1]]
            set newdef [join [lrange [split $text] 2 end]]
            if {![DefDB exists {SELECT 1 FROM definitions WHERE word=$newword}]} {
                #UUID char(36), word char(32), created char(10), modified char(10), definition text, nick char(32)
                set uuid [uuid::uuid generate]
                set ctime [unixtime]
                if {[catch [DefDB eval {
                    INSERT INTO definitions VALUES ($uuid, $newword, $ctime, $ctime, $newdef, $nick)
                }] errmsg]} {
                    putmsg $channel "[CoreDB_logo] Error: $errmsg : while adding \002$newword\002 to definitions db."
                } else {
                    putmsg $channel "[CoreDB_logo] Added \002$newword\002: ${newdef}"
                }
            } else {
                putmsg $channel "[CoreDB_logo] I all ready have \002${newword}\002 in my db."
            }
    } elseif {$word == "!delete"} {
        if {![matchattr $nick +n]} { return }
        set word [string tolower [lindex [split $text] 1]]
            if {[string tolower [lindex [split $text] 2]] == "-y"} {
                if {[DefDB exists {SELECT 1 FROM definitions WHERE word=$word}]} {
                    if {[catch [DefDB eval {
                        DELETE FROM definitions WHERE word=$word
                    }] errmsg]} {
                        putmsg $channel "[CoreDB_logo] Error: $errmsg : while deleting \002$word\002 from definitions db."
                    } else {
                        putmsg $channel "[CoreDB_logo] Deleted \002$word\002 from definitions db."
                    }
                } else {
                    putmsg $channel "[CoreDB_logo] I do not have \002$word\002 in my definitions db."
                }
            } else {
                putmsg $channel "[CoreDB_logo] usage: !delete <word> -y"
            }
    } elseif {$word == "!search"} {
        set search [join [lrange [split $text] 1 end]]
        set rid 0
        set output ""
        set res [DefDB eval {SELECT word,definition FROM searchdef WHERE definition MATCH $search LIMIT 2}]
        #add check for no results and notice user on such an event.
        if {![string length $res]} {
            putmsg $channel "[CoreDB_logo] No results for your querry \"$search\""
            return
        }
        foreach result $res {
            incr rid
            append output "$result "
            if {![expr $rid % 2]} {
                putmsg $channel "[CoreDB_logo] \002[lindex [split $output] 0]\002: [join [lrange [split $output] 1 end]]"
                set output ""
            }
        }
    } elseif {$word == "!updatedb"} {
        if {![matchattr $nick +n]} { return }
        putmsg $channel "[CoreDB_logo] Calling updatedb.  This could take a while."
        if {[update_definitions_search]} {
            putmsg $channel "[CoreDB_logo] Definitions search DB updated!"
        } else {
            putmsg $channel "[CoreDB_logo] Error updating Definitions search DB!"
        }
    } elseif {$word == "!websearch"} {
        set search [join [lrange [split $text] 1 end]]
        set res [DefDB eval {SELECT word,definition FROM searchdef WHERE definition MATCH $search}]
        if {![string length $res]} {
            putmsg $channel "[CoreDB_logo] No results for your querry \"$search\""
            return
        }
        set rid 0
        set uuid [uuid::uuid generate]
		# move to CoreDB settings
        set fo [open "/var/www/app/webroot/dict/$uuid.html" "w"]
        puts $fo {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"> \
                <html lang='en'> \
                <head> \
                <title>MADScript Prudentia search!</title> \
                </head> <body><html>}
        puts $fo {<h1>Prudentia definitions search:</h1>}
        puts $fo "<h2><b>Search pattern: \"$search\"</b></h2>"
        #add check for no results and notice user on such an event.
        foreach result $res {
            incr rid
            if {[expr $rid % 2]} {
                puts $fo "<hr />"
                puts $fo "<h3>$result</h3>"
            } else {
                puts $fo "<p>$result</p>"
                puts $fo "<br />"
            }
        }
        puts $fo {</html></body>}
        close $fo
		#Move to CoreDB, url location
        putmsg $channel "[CoreDB_logo] Results are available at /$uuid.html"
    } else {
        return
    }
}

proc update_definitions_search {} {
    global DefDB DefDB_File
    DefDB eval {;
        BEGIN TRANSACTION;
        DROP TABLE IF EXISTS searchdef;
        COMMIT;
    };
    DefDB close;
    defdb_init
    DefDB eval {CREATE VIRTUAL TABLE searchdef USING fts3(word,definition)}
    set rmax [DefDB eval {SELECT MAX(rowid) FROM definitions}]
    set rcount 0
    while {$rmax>$rcount} {
        if {[DefDB exists {SELECT 1 FROM definitions WHERE rowid=$rcount }]} {
            set res [DefDB eval {SELECT * FROM definitions WHERE rowid=$rcount}]
            set word [lindex $res 1]
            set def [lindex $res 4]
            if {![DefDB exists {SELECT 1 FROM searchdef WHERE word=$word }]} {
                DefDB eval {INSERT INTO searchdef VALUES ($word, $def)}
            } else {
                DefDB eval {UPDATE searchdef SET definition = $def WHERE word=$word;}
            }
            incr rcount
        } else {
            incr rcount
        }
    }
    return 1
}

proc defdb_upkeep {minute hour day month year} {
    global DefDB
    set ctime [unixtime];
    DefDB backup var/backup/definitions.db3.$ctime;
    catch {[exec gzip -9v var/backup/definitions.db3.$ctime]} errmsg
    set gzipmsg ""
    foreach line [split $errmsg \n] {append gzipmsg "[string trim $line] "}
    putlog "DefDB:upkeep: $gzipmsg "
    update_definitions_search
}

dputs "Loaded lib/plugin/dict.tcl"
