# 4.0 formaat
vcl 4.0;

#Varnish Mods Importeren
import directors;
import std;
#whitelist van aanvragers
/*
#hello-app whitelist
acl whitelist1 {
	"172.16.1.39";
	"192.168.10.1";
	"192.168.0.193";
	"localhost";
	"127.0.0.1";
}
#postcode whitelist
acl whitelist2 {
	"172.16.1.40";
	"192.168.0.198";
	"localhost";
	"127.0.0.1";
}
#admin whitelist
acl whitelist3 {
	"172.16.1.41";
	"localhost";
	"127.0.0.1";
}
#Hack whitelist
acl whitelist4 {
	"192.168.0.198";
} */
#De backend servers

#helloapp
backend ws1 {
    .host = "192.168.10.21";
    .port ="5000";
}
#helloapp
backend ws2 {
    .host = "192.168.10.22";
    .port ="5000";
}
#helloapp-backup
backend ws3 {
    .host = "192.168.10.23";
    .port ="5000";
}
#index
backend ws4 {
    .host = "192.168.10.24";
    .port ="80";
}
#Admin website
backend ws5 {
    .host = "192.168.10.25";
    .port ="80";
}

sub vcl_init {
	    # roundrobin backand een en twee koppelen
	    new rrd = directors.round_robin();
	    rrd.add_backend(ws1);
	    rrd.add_backend(ws2);
	

	    # saintmode clusteren voor fallback
	    new fb = directors.fallback() ;
	    fb.add_backend(rrd.backend()) ;
	    fb.add_backend(ws3) ;
}

#Filters op aanvragen
sub vcl_recv
{

	#kleine hack toevoegen om de website pagina te laten werken zonder curl
	if ((!req.http.token) && (req.http.X-Real-IP == "192.168.0.198")) {
		set req.http.token="5555";
	}
	
	#Is er wel een token?
	if (!req.http.token){
		return (synth (403, "Onbevoegd zonder token"));
	}

	if ((req.http.token == "1234") ||(req.http.token == "1235")){
		set req.http.group="SalesL";
	}

	if (req.http.token == "5555"){
		set req.http.group="SalesZ";
	} 

	if (req.http.token == "9999"){
		set req.http.group="Admin";	
	}

	#SalesL groep
	if (req.http.group=="SalesL")  {
		
		if (req.url ~ "^/salesl.php?"){
			set req.backend_hint =ws4;
	                return (hash);
		}
		# Index.php
		if (req.url ~ "^/index.php?"){
			set req.backend_hint =ws4;
	                return (hash);
		}
	        #hallo python
	        if (req.url ~ "^/hello" || req.url ~ "^/sleep"){
	                set req.backend_hint = rrd.backend();
	                return (hash);
		}
		#plaatjes mogen door
		if (req.url ~ "\.(jpg|jpeg|css|js)$"){
			return (hash) ;
		}
		else {
			return (synth (403, "Verkeerde token, Alleen SalesL"));
		}
	}

	#SalesZ groep
	if (req.http.group=="SalesZ") {
		if ((req.url ~ "^/salesz.php?$") &&  (req.http.X-Real-IP == "192.168.0.198") ){
			set req.backend_hint =ws1;
			set req.http.test="real-ip-meegegeven";
			return (hash);
		}
		if (req.url ~ "^/index.php?$"){
			set req.backend_hint =ws4;                        
			return (hash) ;
		}
		if (req.url ~ "^/salesz.php?$"){
			set req.backend_hint =ws5;
	                return (hash) ;	
		}		
		if (req.url ~ "^/admin?$"){
			set req.backend_hint =ws5;
	                return (pass) ;
		}
		if (req.url ~ "^/testers/?$"){
			set req.backend_hint =ws5;
	                return (hash) ;				
		}		
		if (req.url ~ "/test/[a-zA-Z]$"){
			set req.backend_hint =ws5;
	                return (hash) ;				
		}		
		if (req.url ~ "^/postcode/[1-9][0-9]{3}[A-Z]{2}$"){
			set req.backend_hint =ws5;
	                return (hash) ;				
		}
		if (req.url ~ "^/salesL/?$"){
			set req.backend_hint =ws5;
	                return (hash) ;				
		}		
	        #hallo python
	        if (req.url ~ "^/hello" || req.url ~ "^/sleep"){
	                set req.backend_hint = fb.backend();
	                return (hash);
		}
		#plaatjes mogen door
		if  (req.url ~ "\.(jpg|jpeg|css|js)$") {
			set req.backend_hint =ws5;
			return (hash) ;
		}
		else {
			return (synth (403, "Verkeerde token, Alleen SalesZ"));
		}
	}
	#admin Group
	if (req.http.group=="Admin") {
		if (req.url ~ "^/admin"){
			set req.backend_hint =ws5;
	                return (hash);
		}
		# Index.php
		if (req.url ~ "^/index.php"){
			return (hash) ;
		}

	        #hallo python
	        if (req.url ~ "^/hello" || req.url ~ "^/sleep"){
	                set req.backend_hint = ws1;
	                return (hash);
		}
		#plaatjes mogen door
		if (req.url ~ "\.(jpg|jpeg|css|js)$"){
			return (hash) ;
		}
		else {
			return (synth (403, "Verkeerde token, Alleen SalesL"));
		}
	}
	else {
		return (synth (403, "Geen groep, verkeerde server of valse token"));
	}
}
sub vcl_synth {
	if (resp.status == 750) {
		set resp.http.location = resp.reason;
		set resp.status = 301;
		return(deliver);
	}

}

sub vcl_backend_response {

# --------------------------------------

       # [salesL/]
    if (bereq.url ~ "^/salesL/?$" ) {
        set beresp.ttl = 20s;
	set beresp.grace = 10m;
     	set beresp.keep = 10m;
     }
     
       # [salesZ/aAa]
    if (bereq.url ~ "^/salesZ/[a-zA-Z]+" ) {
        set beresp.ttl = 20s;
	set beresp.grace = 1m;
     	set beresp.keep = 10m;
     }
       # [testers]
    if (bereq.url ~ "^testers/?$" ) {
        set beresp.ttl = 5s;
	set beresp.grace = 5s;
     	set beresp.keep = 5s;
     }
       # [test/a-z_A-Z]
    if (bereq.url ~ "^/test/[a-zA-Z]$" ) {
        set beresp.ttl = 1m;
	set beresp.grace = 10m;
     	set beresp.keep = 10m;
     }
       # [postcode/000AA]
    if (bereq.url ~ "^/postcode/[1-9][0-9]{3}[A-Z]{2}$" ) {
        set beresp.ttl = 10s;
	set beresp.grace = 2m;
     	set beresp.keep = 8m;
     }
       # [Postcode/0000AAB]
    if (bereq.url ~ "^/postcode/[1-9][0-9]{3}[A-Z]{2}$/\D+$" ) {
        set beresp.ttl = 10s;
	set beresp.grace = 2m;
     	set beresp.keep = 8m;
     }



# --------------------------------------
# extra
    #Algemene Regelt cache in het geval de pagina niet gevonden is (error 404).
    if (beresp.status == 404) {
       set beresp.ttl = 10s; }


    # Hoofdpagina
    if (bereq.url ~ "^/?$" || bereq.url ~ "^/index.php$" ) {
        set beresp.ttl = 10s;
	set beresp.grace = 2m;
     	set beresp.keep = 8m;
     } 
  
    # plaatjes van indexpage.
    if (bereq.url ~ "hoofdpagina.jpg$")  {
	set beresp.ttl = 1h; }
        #plaatjes van welkom.
    if (bereq.url !~ "hoofdpagina.jpg$" && bereq.url ~ "\.jpg$")  {
	set beresp.ttl = 1w; }   



}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object her
	   set resp.http.X-Cache-Hits = obj.hits;
 
}
