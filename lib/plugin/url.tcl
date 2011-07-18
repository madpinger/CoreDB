#!
##############################################################################################
# lib/plugin/url.tcl
##############################################################################################

dputs "Loading lib/plugin/url.tcl"

CoreDB::add::Command [list "$$" "pub_url" 1];

# import the global user agent config from CoreDB
# add error check for unresolved host, like http://local/

set url(limit) 1 ;# move to CoreDB sometime
::http::register https 443 ::tls::socket

proc pub_url {nick host hand channel text {redirect 0}} {
    global CoreDB
    #temp exclude list. Until I add a setting,list for it.
    set url_user_exclude [list "belkar" "overseer"]
    if {[info exist url_user_exclude]} {
	foreach exclude $url_user_exclude {
	    if {[string tolower $exclude] == [string tolower $nick]} {
		#putlog "plugin:pub_url:exclude event, record event for $nick not added"
		return 1
	    }
	}
    }
    #end temp user exclude list
    set urlcount 0
    set haswarned 0
    foreach word [split $text] {
	set haserror 0
	# add domain suffix validation ?,  optimize to be more efficient at parsing. it just works for now
	if {[regexp {^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)?$} $word] && \
		![regexp -nocase {^www.*} $word]} {
	    set word "http://www.$word"
	} elseif {[regexp -nocase {^www.*} $word] && \
		[regexp {^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)?$} $word]} {
	    set word "http://$word"
	}
        if {[regexp {^(f|ht)tp(s|)://} $word] && \
            ![regexp {://([^/:]*:([^/]*@|\d+(/|$))|.*/\.)} $word]} {
	    #url cache check here !
            set uuid [uuid::uuid generate]
            set ctime [clock seconds]
	    set cached [list "0" "0" "0"]
            if {![CoreDB exists {SELECT 1 FROM urls WHERE uri=$word}]} {
                CoreDB eval {INSERT INTO urls VALUES ($uuid, $word, $channel, $nick, $ctime, $ctime, "None")}
            } else {
	        set cached [CoreDB eval { SELECT nick,created,modified FROM urls WHERE uri=$word and channel = $channel; }]
		if {[catch { CoreDB eval {
		    UPDATE urls SET modified = $ctime WHERE uri = $word and channel = $channel;
		    UPDATE urls SET nick = $nick WHERE uri = $word and channel = $channel;
		}} errmsg]} { putlog "plugin:pub_url:Update record for: $word failed. :$errmsg"}
		#putmsg #madscript "$cached"
	    }
            #http section
            if {[info exists word] && [string length $word]} {
	    set http [::http::config -useragent "Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.11) Gecko/20101013 Firefox/3.6.11" \
              -urlencoding "utf-8" -accept "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"]
                catch {set tok [::http::geturl $word -timeout 50000 -headers "Accept-Language en"]} errmsg
		set newdata "" ; set charenc 0; set title ""
		if {[info exists tok]} {
		    incr urlcount ;# only count urls we actually fetch info for, otherwise there is no msg sent to channel anyway.
		    switch [::http::ncode $tok] {
			"301" {
			    if {$redirect != 1} {
				upvar #0 $tok state
				foreach {name value} $state(meta) {
				    if {[regexp -nocase ^location$ $name]} {
					# Handle URL redirects
					pub_url $nick $host $hand $channel $value 1;#call ourself again !
					set haserror 1
				    }
				}
			    }
			    set haserror 1
			    ::http::cleanup $tok
			    unset tok
			}
			"418" {
			    putmsg $channel "$nick, Did you know that $word is a short stout teapot ?"
			    ::http::cleanup $tok
			    unset tok
			    set haserror 1
			}
			"200" {
			    if {[info exists $errmsg] && [string match -nocase "*couldn't open socket*" $errmsg]} {
				putlog "plugin:pub_url:$errmsg"
				set haserror 1
			    }
			    if { [::http::status $tok] == "timeout" } {
				putlog "plugin:pub_url:timeout:$word"
				set haserror 1
			    }
			    set data [::http::data $tok]
			    ::http::cleanup $tok
			    unset tok
			    foreach line [split $data \n] {
				if {[regexp -nocase {<meta.*charset.(.*?)".*>} $line match charset]} {
				    # logic for encoding convertfrom
				    set charenc $charset
				}
				append newdata " [string trim $line]"
			    }
			    if {![regexp -nocase {<title>(.*?)</title>} $newdata match title]} {
				return 1
			    }
			}
		    }
		}
	    } else { set title ""; set haserror 1; }
            #output section
            if {[string length $title] && $haserror != 1} {
                if {[CoreDB_urlTitle] == 1} {
		    set charenc [convertCharSet $charenc]
		    if {$charenc != 0 && $charenc != "unicode" && [lsearch -exact [encoding names] $charenc]} {
			set title [convertHE [string trim $title] $charenc]
		    } else {
			set title [convertHE [string trim $title]]
		    }
                    #add channel flag check
		    if {[lindex $cached 0] != 0} {
			putmsg $channel "[CoreDB_logo]URL Title: $title : Last spammed by [lindex $cached 0] [duration [expr [unixtime] - [lindex $cached 2]]] ago."
		    } else {
			putmsg $channel "[CoreDB_logo]URL Title: $title"
		    }
                }
            }
	}
	if {$urlcount > $::url(limit)} { break }
	#repeat
    }
}

dputs "Loaded lib/plugin/url.tcl"
