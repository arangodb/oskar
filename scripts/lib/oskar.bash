err(){
    echo "error: $@"
}

ferr(){
    echo "fatal error: $@"
    exit 1
}

ensure_oskar(){
       ensure create_repo "$@" && return
}

ensure(){
	"$@" && return
	ferr "failed to run: $@"
}

setup_gpg(){
    error_info="$(mktemp)"
    test_file="$(mktemp)"
    export KEYNAME=86FEC04D
    export GPG_TTY="$(tty)"

    /usr/bin/gpg-agent --homedir=~/.gnupg --daemon \
        --use-standard-socket --allow-loopback-pinentry 2>"$error_info"
    gpg2 --import -v -v ~/.gnupg/secring.gpg 2>"$error_info" \
        || err "failed to import secret"
    gpg2 --homedir=~/.gnupg --no-default-keyring --keyring ~/.gnupg/pubring.kbx \
        --export -a | gpg2 --import -v -v  2>"$error_info" \
        || err "faild to import public key"

    cd /tmp/
    echo "bla"> "$test_file"
    gpg2 --pinentry-mode=loopback --digest-algo SHA512 \
         --passphrase-fd 0 --yes -abs \
         -u "$KEYNAME" \
         -o Release.gpg "$test_file" <<<"$ARANGO_SIGN_PASSWD" 2>"$error_info"
    (( $? != 0 )) && {
        echo "failed test signing";
        cat "$error_info";
	exit 1;
    }
    rm -fr "$error_info"
}
