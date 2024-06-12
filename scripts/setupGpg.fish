#!/usr/bin/env fish

set -l test_file (mktemp)
set -l passphrase (mktemp)
set -x GPG_TTY (tty)

gpgconf --kill gpg-agent
and gpg2 --homedir=~/.gnupg --no-permission-warning --import ~/.gnupg/secring.gpg
and gpg2 --no-default-keyring --keyring ~/.gnupg/pubring.kbx --export -a | gpg2 --import
and begin
  cd /tmp/
  and echo "this is a test" > $test_file
  and rm -f $passphrase
  and touch $passphrase
  and chmod 600 $passphrase
  and echo "$ARANGO_SIGN_PASSWD" >> $passphrase
  and gpg2 \
	--homedir=~/.gnupg \
        --no-permission-warning \
        --armor \
	--detach-sign \
	--sign \
	--batch \
	--pinentry-mode=loopback \
	--digest-algo SHA512 \
	--passphrase-file=$passphrase \
	--yes \
	-u "$KEYNAME" \
	-o Release.gpg \
	"$test_file"
end
and echo "testing signed was successful"
and rm -f $test_file $passphrase
or begin rm -f $test_file $passphrase ; exit 1 ; end
