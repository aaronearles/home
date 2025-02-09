**Forward Proxy Configuration in Nginx**
=====================================

### Basic Configuration

Here is an example of a basic forward proxy configuration in Nginx:
```nginx
http {
    ...
    upstream backend {
        server localhost:8080;
    }

    server {
        listen 80;
        server_name example.com;

        # Forward proxy configuration
        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Allow proxying of HTTPS requests
        location / {
            proxy_pass https://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```
This configuration sets up a forward proxy that listens on port 80 and forwards requests to a backend server running on localhost at port 8080.

### Breakdown of the Configuration

* `upstream backend { server localhost:8080; }`: This defines an upstream server group named "backend" that points to a single server running on localhost at port 8080.
* `location / { ... }`: This defines a location block that handles all requests to the forward proxy.
* `proxy_pass http://backend;`: This directive specifies that requests should be proxied to the "backend" upstream server group.
* `proxy_set_header Host $host;`: This sets the `Host` header of the proxied request to the value of the `Host` header of the original request.
* `proxy_set_header X-Real-IP $remote_addr;`: This sets the `X-Real-IP` header of the proxied request to the IP address of the client making the request.

### Enabling HTTPS Proxying

To allow proxying of HTTPS requests, you'll need to add additional configuration. Here's an updated example:
```nginx
http {
    ...
    upstream backend {
        server localhost:8080;
    }

    server {
        listen 80;
        server_name example.com;

        # Forward proxy configuration
        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Allow proxying of HTTPS requests
        location / {
            proxy_pass https://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_ssl_server_name on;
            proxy_ssl_verify off;
            proxy_ssl_verify_depth 3;
        }
    }
}
```
In this updated example, we've added the following directives to the HTTPS proxy configuration:

* `proxy_ssl_server_name on;`: This enables the use of the `ssl_server_name` directive to specify the SSL server name.
* `proxy_ssl_verify off;`: This disables SSL verification for the HTTPS proxy.
* `proxy_ssl_verify_depth 3;`: This sets the SSL verification depth to 3.

**Important Security Considerations**

Please note that forward proxying can be a security risk if not properly configured, as it can allow unauthorized access to your network. You should carefully evaluate the security implications before implementing a forward proxy in your environment.

**Using Variables in `proxy_pass` Directive**

You can use `proxy_pass` with variables, for example:
```nginx
location / {
    set $target "http://backend";
    proxy_pass $target;
}
```
This way you can dynamically set the target of the `proxy_pass` directive based on some logic.

**Using a DNS Resolver**

You can also use the `resolver` directive to specify a DNS resolver for the `proxy_pass` directive.
```nginx
resolver 127.0.0.1:53;
set $target "http://backend.example.com";
proxy_pass $target;
```
This way you can use a DNS resolver to resolve the hostname in the `proxy_pass` directive.

# Alternative
By default, Nginx's `proxy_pass` directive is designed to proxy requests to a specific upstream server or group, not to a wildcard destination.

However, you can achieve a wildcard proxying behavior by using a trick with the `resolver` directive and a variable in the `proxy_pass` directive.

Here's an example configuration:
```nginx
http {
    ...
    resolver 8.8.8.8; # Use Google's public DNS resolver

    server {
        listen 8080;

        location / {
            proxy_pass $scheme://$host$request_uri;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```
In this configuration, we're not defining an `upstream` block or a specific `server` directive for the `proxy_pass` directive. Instead, we're using the `$host` variable, which contains the hostname from the original request.

This tells Nginx to resolve the hostname of the original request using the DNS resolver specified in the `resolver` directive and then forward the request to the resulting IP address.

**Important Note:** This configuration will forward requests to **any** destination, including those that may not be intended to be proxied. Make sure you have proper access controls and security measures in place to prevent potential security issues.

Also, keep in mind that this configuration may not work with all types of requests, such as WebSockets or WebRTC, and may require additional configuration to handle specific cases.

To add authentication and access control to this wildcard proxying configuration, you can use Nginx's built-in authentication modules, such as `ngx_http_auth_basic_module` or `ngx_http_auth_ldap_module`, as mentioned earlier.

For example:
```nginx
http {
    ...
    resolver 8.8.8.8; # Use Google's public DNS resolver

    server {
        listen 8080;

        location / {
            auth_basic "Outbound Proxy";
            auth_basic_user_file /path/to/passwd;
            proxy_pass $scheme://$host$request_uri;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```