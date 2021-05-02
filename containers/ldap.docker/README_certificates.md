# How to generate certificates

## Generate a 4096 bit RSA key pair

    openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out ca.key

This generates ASCII PEM format.

## Inspect key files

    openssl pkey -in ca.key -text

## Separate the public key from the private key

    openssl pkey -in ca.key -pubout -out ca.pem

## Inspect a public key file

    openssl pkey -in ca.pem -pubin -noout -text

## Create an X509 certificate for a key pair

    openssl req -new -key ca.key -x509 -days 1095 -out ca.pem

## Inspect an X509 certificate

    openssl x509 -in ca.pem -text -noout

## Create a certificate signing request

    openssl req -new -key server.key -out server.csr

This will prompt for the subject values, alternatively, one can hand
them in directly as in this:

    openssl req -new -key server.key -subj "/C=DE/ST=NRW/L=Cologne/O=ArangoDB GmbH/OU=Clifton/CN=c9.arangodb.biz/emailAddress=max@arangodb.com/" -out server.csr

Note that values are separated by slash `/` characters and there is a
little extra-Wurst for the `emailAddress`.

## Inspect a certificate signing request

    openssl req -in server.csr -text -noout

## Sign a certificate signing request with a CA key and certificate

    openssl x509 -req -days 2000 -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem

Note that for the first time the file ca.key is used to sign, a
file `ca.srl` will be created with a serial number. Subsequent signing
operations can be done exactly like this:

    openssl x509 -req -days 2000 -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem

(the `-CAcreateserial` is not necessary but allowed here) and the serial
number in the `ca.srl` file is incremented and used.

## Inspect the signed certificate

As before for a self-signed certificate

    openssl x509 -in server.pem -text -noout

## Verify a signature on a certificate

    openssl verify 

## Summary for a self-signed infrastructure

CA, server and client key pairs:

    openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out ca.key
    openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out server.key
    openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out client.key

Create the X509 certificate for the CA:

    openssl req -new -key ca.key -x509 -days 1095 -subj "/C=DE/ST=NRW/L=Cologne/O=ArangoDB GmbH/OU=Clifton/CN=Max Neunhoeffer/emailAddress=max@arangodb.com/" -out ca.pem

Create a certificate signing request for the server and client certificates:

    openssl req -new -key server.key -subj "/C=DE/ST=NRW/L=Cologne/O=ArangoDB GmbH/OU=Clifton/CN=c9.arangodb.biz/emailAddress=max@arangodb.com/" -out server.csr
    openssl req -new -key client.key -subj "/C=DE/ST=NRW/L=Cologne/O=ArangoDB GmbH/OU=Clifton/CN=MaxNeunhoeffer/emailAddress=max@arangodb.com/" -out client.csr

Sign the certificate signing requests to get x509 certificates for both:

    openssl x509 -req -days 2000 -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem
    openssl x509 -req -days 2000 -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem

And finally verify the signatures:

    openssl verify -CAfile ca.pem -check_ss_sig ca.pem server.pem client.pem
