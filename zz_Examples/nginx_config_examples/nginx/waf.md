Here is an example of a basic WAF (Web Application Firewall) configuration in Nginx:
```
http {
   ...
    include /path/to/nginx-waf-config.conf;
   ...
    server {
        listen 80;
        server_name example.com;
        location / {
           ...
            include /path/to/nginx-waf-rules.conf;
           ...
        }
    }
}
```
In this example, the `include` directive is used to include two external configuration files:

* `/path/to/nginx-waf-config.conf`: This file contains the global WAF configuration, such as the WAF mode (e.g., on or off), the logging configuration, and the whitelist/blacklist rules.
* `/path/to/nginx-waf-rules.conf`: This file contains the WAF rules specific to the `/` location, such as the rules to block certain types of traffic or the rules to limit the rate of requests from a particular IP address.

Here is an example of what the `/path/to/nginx-waf-config.conf` file might contain:
```
waf_mode on;
waf_log_format "$remote_addr - $remote_user - $host - $status - $request";
waf_log_path /path/to/waf.log;

# Whitelist rules
waf_whitelist_address 192.168.1.100;
waf_whitelist_address 192.168.1.101;

# Blacklist rules
waf_blacklist_address 198.100.1.100;
waf_blacklist_address 198.100.1.101;
```
And here is an example of what the `/path/to/nginx-waf-rules.conf` file might contain:
```
# Rate limiting rule
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
limit_conn conn_limit 10;
limit_rate 100;

# Blocking rule for GET requests
if ($request_method = GET) {
    # Block requests containing a particular string
    if ($request_uri ~* "some_string") {
        return 403;
    }
}

# Whitelist rule for a particular IP address
if ($remote_addr = 192.168.1.100) {
    break;
}

# Blacklist rule for a particular User-Agent string
if ($http_user_agent ~* "Bad Bot") {
    return 403;
}
```

This is just a basic example to illustrate how WAF configuration can be done in Nginx. The specific configuration will depend on your use case and requirements.