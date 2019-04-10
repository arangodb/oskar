#!/usr/bin/env fish

set -l passphrase (mktemp)
set -x GPG_TTY (tty)

source /scripts/setupGpg.fish
and rm -f $passphrase
and touch $passphrase
and chmod 600 $passphrase
and echo "$ARANGO_SIGN_PASSWD" >> $passphrase
and for i in (seq 1 (count $argv))
  set -l file $argv[$i]
  set -l sign $argv[$i]"".asc

  if /usr/bin/test -s "$sign" -a "$sign" -nt "$file"
    echo "using existing signature $sign"
  else
    echo "signing file $file"
    and gpg2 \
      --homedir=~/.gnupg \
      --armor \
      --detach-sign \
      --sign \
      --batch \
      --pinentry-mode=loopback \
      --digest-algo SHA512 \
      --passphrase-file=$passphrase \
      --yes \
      -u "$KEYNAME" \
      -o $sign \
      "$file"
    or exit 1
  end      
end
