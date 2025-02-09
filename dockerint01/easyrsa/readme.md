# Docker Container for EasyRSA

An Alpine based image that provides an EasyRSA Certificate Authority.

## Usage

This does not run as a spawned background task. The container is merely a repository for the EasyRSA program. This makes it transportable in that you will be able to have a pki store uniquely for any other usage rather than a single pki store per host.

You can then use this on a container by container need for deploying certificates.

Modify the `vars` file to suit your environment. The only change made here is to fix the location of the pki store to `/easyrsa/pki` so it matches the mount point.

**There is one point of note - you cannot use `easyrsa init-pki`.**

Because the `pki` store is mounted you cannot use the argument `init-pki`, `easyrsa init-pki` needs the ability to remove the `pki` folder using `rm -rf` and recreate it. It cannot do this with a mounted `pki` folder. If you need to reset your pki, just provide the host with an empty `./pki` folder, or delete it and continue the process of `build-ca`.

The delivery of `easyrsa` is carried out using a `wget` of version 3.0.8. This is then placed into `/usr/local/bin` just to have it included in the PATH.

### First Run Setup

```shell
sudo docker compose build
mkdir -p pki/{private,reqs} && cp ./vars.template ./pki/vars
sudo docker compose run --rm easyrsa easyrsa build-ca
```

### Generate a cert:

```shell
CERT=test.internal
mkdir pki/$CERT
sudo docker compose run --rm easyrsa easyrsa gen-req $CERT
sudo docker compose run --rm easyrsa easyrsa sign-req server $CERT
sudo cp ./pki/issued/$CERT.crt ./pki/private/$CERT.key ./pki/$CERT
sudo docker compose run --rm easyrsa openssl ec -in /easyrsa/pki/$CERT/$CERT.key -out /easyrsa/pki/$CERT/$CERT_decrypted.key
```

### Example:
```shell
sudo docker compose build
mkdir -p pki/{private,reqs}
mv vars.template ./pki/vars
CERT=test.internal
sudo docker compose run --rm easyrsa easyrsa gen-req $CERT

    Using Easy-RSA 'vars' configuration:
    * /easyrsa/pki/vars
    ...
    Enter PEM pass phrase:
    Verifying - Enter PEM pass phrase:
    ...
    Common Name (eg: your user, host, or server name) [test.internal]:
    ...
    Private-Key and Public-Certificate-Request files created.
    Your files are:
    * req: /easyrsa/pki/reqs/test2.internal.req
    * key: /easyrsa/pki/private/test2.internal.key

sudo docker compose run --rm easyrsa easyrsa sign-req server $CERT
    Using Easy-RSA 'vars' configuration:
    * /easyrsa/pki/vars
    ...
    Request subject, to be signed as a server certificate for '10950' days:
    subject=
        commonName = test.internal
    Type the word 'yes' to continue, or any other input to abort.
    Confirm request details: yes
    ...
    Notice
    ------
    Certificate created at:
    * /easyrsa/pki/issued/test.internal.crt
```

### Guide

https://github.com/OpenVPN/easy-rsa/blob/master/README.quickstart.md

### My original EasyRSA Notes:
```shell
https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-a-certificate-authority-on-ubuntu-22-04

#EXAMPLE:
cert=wildcard.lan
~/easy-rsa/easyrsa gen-req $CERT
~/easy-rsa/easyrsa --days=10950 sign-req server $CERT
mkdir ~/$CERT && cp ~/easy-rsa/pki/issued/$CERT.crt ~/easy-rsa/pki/private/$CERT.key  ~/$CERT
openssl rsa -in ~/$CERT/$CERT.key -out $CERT_decrypted.key
scp -r ~/$CERT/ user@nas:/certs/
```