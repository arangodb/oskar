#!/bin/bash

if test -z "$PUID";  then
  echo "ERROR: please run docker with '-e PUID=(id -u)'"
  exit 1
fi

if test -z "$PGID";  then
  echo "ERROR: please run docker with '-e PGID=(id -g)'"
  exit 1
fi

if test -z "$PHOME";  then
  echo "ERROR: please run docker with '-e PHOME=\$HOME'"
  exit 1
fi

if test ! -d "$PHOME";  then
  echo "ERROR: please run docker with '-v \$HOME:\$HOME'"
  exit 1
fi

if test -z "$PDOCKER";  then
  echo "ERROR: please run docker with '-e PDOCKER=(getent group docker | cut -d: -f3)'"
  exit 1
fi

if test -z "$SSH_AUTH_SOCK";  then
  echo "ERROR: please run docker with '-e SSH_AUTH_SOCK=\$SSH_AUTH_SOCK'"
  exit 1
fi

if test ! -S "$SSH_AUTH_SOCK";  then
  echo "ERROR: please run docker with '-v \$SSH_AUTH_SOCK:\$SSH_AUTH_SOCK'"
  exit 1
fi

if test ! -S "/var/run/docker.sock";  then
  echo "ERROR: please run docker with '-v /var/run/docker.sock:/var/run/docker.sock'"
  exit 1
fi


echo "================================================================================"
echo "AUTH: $SSH_AUTH_SOCK"
echo "PDOCKER: $PDOCKER"
echo "PGID: $PGID"
echo "PHOME: $PHOME"
echo "PPWD: $PPWD"
echo "PUID: $PUID"
echo "================================================================================"

echo "jenkins:x:$PUID:$PGID:Jenkins User:$PHOME:/bin/bash" >> /etc/passwd
echo "jenkins:x:11111:0:99999:7:::" >> /etc/shadow
echo "jenkins:x:$PGID:" >> /etc/group

sed -i -e "s/^docker:x:\(.*\):/docker:x:$PDOCKER:jenkins/" /etc/group

cd $PPWD
HOME=$PHOME

su jenkins fish -c $*
