#!/bin/sh

# CA, server and client key pairs:

openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out ca.key
openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out server.key
openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:4096 -out client.key

# Create the X509 certificate for the CA:

openssl req -new -key ca.key -x509 -days 1095 -subj "/C=DE/ST=NRW/L=Cologne/O=ArangoDB GmbH/OU=Clifton/CN=MaxNeunhoeffer/emailAddress=max@arangodb.com/" -out ca.pem

# Create a certificate signing request for the server and client certificates:

openssl req -new -key server.key -subj "/C=DE/ST=NRW/L=Cologne/O=ArangoDB GmbH/OU=Clifton/CN=ldap01.arangodb.biz/emailAddress=max@arangodb.com/" -out server.csr
openssl req -new -key client.key -subj "/C=DE/ST=NRW/L=Cologne/O=ArangoDB GmbH/OU=Clifton/CN=ldap01.arangodb.biz/emailAddress=max@arangodb.com/" -out client.csr

# Sign the certificate signing requests to get x509 certificates for both:

openssl x509 -req -days 2000 -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem
openssl x509 -req -days 2000 -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem
rm server.csr client.csr

# And finally verify the signatures:

openssl verify -CAfile ca.pem -check_ss_sig ca.pem server.pem client.pem
