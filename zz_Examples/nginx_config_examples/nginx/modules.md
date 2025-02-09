To use the authentication modules in Nginx, you'll need to follow these general steps:

**1. Enable the module**

You'll need to enable the module you want to use by uncommenting the corresponding line in the Nginx configuration file (usually `nginx.conf` or `default.conf`).

For example, to enable the `ngx_http_auth_basic_module`, you'll need to uncomment this line:
```nginx
load_module /usr/lib/nginx/modules/ngx_http_auth_basic_module.so;
```
**2. Create a password file**

You'll need to create a password file that contains the usernames and passwords for the users who will be authenticating.

For example, you can use the `htpasswd` command to create a password file:
```bash
htpasswd -c /path/to/passwd admin
```
This will create a password file at `/path/to/passwd` with the username `admin`.

**3. Configure the module**

You'll need to configure the module by adding directives to the Nginx configuration file.

Here are some examples:

**ngx_http_auth_basic_module**

```nginx
http {
    ...
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
In this example, we're using the `auth_basic` directive to enable basic authentication, and the `auth_basic_user_file` directive to specify the password file.

**ngx_http_auth_ldap_module**

```nginx
http {
    ...
    upstream ldap {
        server ldap://ldap.example.com:389;
        ldap_auth_url "ou=people,dc=example,dc=com";
        ldap_auth_user_attr "uid";
        ldap_auth_group_attr "cn";
        ldap_bind_dn "cn=admin,dc=example,dc=com";
        ldap_bind_dn_password "password";
    }

    server {
        listen 8080;

        location / {
            auth_ldap "Outbound Proxy";
            auth_ldap_conf ldap;
            proxy_pass $scheme://$host$request_uri;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```
In this example, we're using the `auth_ldap` directive to enable LDAP authentication, and the `auth_ldap_conf` directive to specify the LDAP configuration.

**Common directives**

Here are some common directives that can be used with both modules:

* `auth_delay`: specifies the delay in seconds before retrying failed authentication attempts.
* `auth_retries`: specifies the number of retries allowed for failed authentication attempts.

For example:
```nginx
http {
    ...
    server {
        listen 8080;

        location / {
            auth_basic "Outbound Proxy";
            auth_basic_user_file /path/to/passwd;
            auth_delay 3;
            auth_retries 3;
            proxy_pass $scheme://$host$request_uri;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```
I hope that helps!