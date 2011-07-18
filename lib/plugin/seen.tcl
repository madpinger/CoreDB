#!
##############################################################################################
# lib/plugin/seen.tcl
##############################################################################################

dputs "Loading lib/plugin/seen.tcl"

CoreDB::add::Command [list "!seen,$$ seen" "pub_seen" 0];

proc pub_seen {nick host hand channel text} {
        set who [string tolower [lindex [split $text] 1]]
        if {[string tolower $nick] == $who} {
            putmsg $channel "$nick, Look in a mirror!"
            return
        } elseif {[onchan $who $channel]} {
            putmsg $channel "$nick must need glasses, [lindex [split $text] 1] is right here !"
            return
        }
        if {[CoreDB exists {SELECT 1 FROM users WHERE nick=$who }]} {
            set uuid [CoreDB eval {SELECT uuid FROM users WHERE  nick=$who}]
        } elseif {[CoreDB exists {SELECT 1 FROM users WHERE handle=$who }]} {
            set uuid [CoreDB eval {SELECT uuid FROM users WHERE  handle=$hand}]
        } else {
            putmsg $channel "[CoreDB_logo] I have not seen [lindex [split $text] 1]."
            return
        }
        if {[matchattr $nick +n]} {
            set lastseen [lindex [CoreDB eval {SELECT MAX(modified) FROM user_stats WHERE  user=$uuid}] 0]
            if {[string length $lastseen]} {
                putmsg $channel "[CoreDB_logo] I last seen [lindex [split $text] 1] [duration [expr [unixtime] -  $lastseen]] ago."
                return
            } else {
                putmsg $channel "[CoreDB_logo] Error, null timestamp."
            }
        } else {
            if {[CoreDBChanStatExists $uuid $channel]} {
                set lastseen [lindex [CoreDB eval {SELECT MAX(modified) FROM user_stats WHERE  user=$uuid AND channel=$channel}] 0]
                if {[string length $lastseen]} {
                    putmsg $channel "[CoreDB_logo] I last seen [lindex [split $text] 1] [duration [expr [unixtime] -  $lastseen]] ago."
                    return
                } else {
                    putmsg $channel "[CoreDB_logo] Error, null timestamp."
                }
            } else {
                putmsg $channel "[CoreDB_logo] I have not seen [lindex [split $text] 1]."
                return
            }
        }
}

dputs "Loaded lib/plugin/seen.tcl"
