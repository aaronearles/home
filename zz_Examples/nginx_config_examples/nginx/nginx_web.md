Below is a basic example of an `nginx.conf` configuration that serves a web page over HTTPS. It includes a redirect from HTTP to HTTPS. This setup assumes you have two server blocks: one listening on port 80 (HTTP) that redirects all requests to HTTPS, and another block that serves your content securely over HTTPS on port 443.

Please ensure you have an SSL/TLS certificate (e.g., SSL certificates from Let's Encrypt) ready for this setup. If you don't already have a certificate, you'll need to obtain one. The paths to the `ssl_certificate` and `ssl_certificate_key` files should be adjusted to match the locations of your SSL/TLS certificate and key.

```
see ./nginx_web.conf
```


Critical parts of this configuration:

Redirect block (HTTP): The first `server` block listens on port 80 and redirects (`return 301`) all incoming requests to HTTPS, maintaining the request URI. Replace `yourdomain.com` with your actual domain name or IP address.

HTTPS Server Block: The second `server` block is where you configure the HTTPS server. It listens on port 443 and specifies the paths to your SSL/TLS `certificate.crt` and `privatekey.key`.

Server Configuration: Adjust the `root` path to point to the directory where your web page files are located. The `index` directive tells Nginx which file to load by default. The `location` blocks provide additional customization, such as controlling how different types of files are handled.

Remember to replace placeholders (`yourdomain.com`, `/path/to/ssl/certificate.crt`, `/path/to/ssl/privatekey.key`, and `/var/www/html`) with the actual details for your setup.

After editing your `nginx.conf` file, it's a good practice to check the configuration for syntax errors by running `nginx -t` before reloading Nginx with `sudo nginx -s reload` or `sudo service nginx reload` (depending on your system configuration).