#!/usr/bin/env fish
source jenkins/helper/jenkins.fish

if test (count $argv) -lt 1
  echo usage: (status current-filename) "<destination>"
  exit 1
end

if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

umask 000

function copySnippet
  set DST $argv[1]
  set IN $argv[2]
  set PATTERN $argv[3]
  and for p in (string split " " (eval "echo $WS_SNIPPETS/$IN"))
        set f (basename $p)
        echo $f
        echo $p
        if test -z "$PATTERN"
          cp -av $p $DST/$f
        else
          cp -av $p $DST/(echo "$f" | sed $PATTERN)
        end
      end
end

cleanPrepareLockUpdateClear
and cleanWorkspace
and switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion

and set -xg SRC $argv[1]/stage1/$RELEASE_TAG
and set -xg DST $argv[1]/stage2/$ARANGODB_PACKAGES

and set -g SP_PACKAGES $DST
and if test "$ARANGODB_VERSION_MAJOR" -eq 3
      if test "$ARANGODB_VERSION_MINOR" -le 11; or begin; test "$ARANGODB_VERSION_MINOR" -eq 12; and test "$ARANGODB_VERSION_PATCH" -lt 5; end
        set -g SP_SNIPPETS_CO $DST/snippets/Community
      else
        echo "Set SP_SNIPPETS_CO to $DST/snippets/Community only for source snippet (3.12.5+ case)!"
        set -g SP_SNIPPETS_CO $DST/snippets/Community
      end
    end
and set -g SP_SNIPPETS_EN $DST/snippets/Enterprise
and set -g SP_SOURCE $DST/source
and set -g WS_PACKAGES $SRC/release/packages
and set -g WS_SNIPPETS $SRC/release/snippets
and set -g WS_SOURCE $SRC/release/source

and echo "checking snippets source directory '$WS_SNIPPETS'"
and test -d $WS_SNIPPETS
and echo "creating destination directory '$DST'"
and mkdir -p $DST
and if test "$ARANGODB_VERSION_MAJOR" -eq 3
      if test "$ARANGODB_VERSION_MINOR" -le 11; or begin; test "$ARANGODB_VERSION_MINOR" -eq 12; and test "$ARANGODB_VERSION_PATCH" -lt 5; end
        echo "creating community snippets destination directory '$SP_SNIPPETS_CO'"
        and mkdir -p $SP_SNIPPETS_CO
      else
        echo "creating community snippets destination directory (only for source snippet!) '$SP_SNIPPETS_CO'"
        and mkdir -p $SP_SNIPPETS_CO
      end
    end
and echo "creating enterprise snippets destination directory '$SP_SNIPPETS_EN'"
and mkdir -p $SP_SNIPPETS_EN

and echo "========== COPYING SNIPPETS =========="
and if test "$ARANGODB_VERSION_MAJOR" -eq 3
      if test "$ARANGODB_VERSION_MINOR" -le 11; or begin; test "$ARANGODB_VERSION_MINOR" -eq 12; and test "$ARANGODB_VERSION_PATCH" -lt 5; end
        copySnippet "$SP_SNIPPETS_CO" "download-arangodb3-debian*.html" 's/arangodb3-debian/debian/'
        and copySnippet "$SP_SNIPPETS_CO" "download-arangodb3-debian*.html" 's/arangodb3-debian/ubuntu/'
        and copySnippet "$SP_SNIPPETS_CO" "download-arangodb3-rpm*.html" 's/arangodb3-rpm/centos/'
        and copySnippet "$SP_SNIPPETS_CO" "download-arangodb3-rpm*.html" 's/arangodb3-rpm/fedora/'
        and copySnippet "$SP_SNIPPETS_CO" "download-arangodb3-suse*.html" 's/arangodb3-suse/opensuse/'
        and copySnippet "$SP_SNIPPETS_CO" "download-arangodb3-rpm*.html" 's/arangodb3-rpm/redhat/'
        and copySnippet "$SP_SNIPPETS_CO" "download-arangodb3-suse*.html" 's/arangodb3-suse/sle/'
        and copySnippet "$SP_SNIPPETS_CO" "download-arangodb3-linux*.html" 's/arangodb3-linux/linux-general/'
        and copySnippet "$SP_SNIPPETS_CO" "download-docker-community.html" 's/docker-community/docker/'
        and copySnippet "$SP_SNIPPETS_CO" "download-k8s-community.html" 's/k8s-community/k8s/'
      end
    end
and if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 11
      copySnippet "$SP_SNIPPETS_CO" "download-arangodb3-macosx*.html" 's/arangodb3-macosx/macosx/'
      copySnippet "$SP_SNIPPETS_CO" "download-windows*-community.html" 's/windows.*-community/windows/'
    end
and copySnippet "$SP_SNIPPETS_CO" "download-source.html"
and if test "$ARANGODB_VERSION_MAJOR" -eq 3
      if test "$ARANGODB_VERSION_MINOR" -le 11; or begin; test "$ARANGODB_VERSION_MINOR" -eq 12; and test "$ARANGODB_VERSION_PATCH" -lt 5; end
        cp $WS_SNIPPETS/meta-*-community*.json $SP_SNIPPETS_CO
      end
    end
and cp $WS_SNIPPETS/meta-source.json $SP_SNIPPETS_CO

and copySnippet "$SP_SNIPPETS_EN" "download-arangodb3e-debian*.html" 's/arangodb3e-debian/debian/'
and copySnippet "$SP_SNIPPETS_EN" "download-arangodb3e-debian*.html" 's/arangodb3e-debian/ubuntu/'
and copySnippet "$SP_SNIPPETS_EN" "download-arangodb3e-rpm*.html" 's/arangodb3e-rpm/centos/'
and copySnippet "$SP_SNIPPETS_EN" "download-arangodb3e-rpm*.html" 's/arangodb3e-rpm/fedora/'
and copySnippet "$SP_SNIPPETS_EN" "download-arangodb3e-suse*.html" 's/arangodb3e-suse/opensuse/'
and copySnippet "$SP_SNIPPETS_EN" "download-arangodb3e-rpm*.html" 's/arangodb3e-rpm/redhat/'
and copySnippet "$SP_SNIPPETS_EN" "download-arangodb3e-suse*.html" 's/arangodb3e-suse/sle/'
and copySnippet "$SP_SNIPPETS_EN" "download-arangodb3e-linux*.html" 's/arangodb3e-linux/linux-general/'
and if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -le 11
      copySnippet "$SP_SNIPPETS_EN" "download-arangodb3e-macosx*.html" 's/arangodb3e-macosx/macosx/'
      and copySnippet "$SP_SNIPPETS_EN" "download-windows*-enterprise.html" 's/windows.*-enterprise/windows/'
    end
and copySnippet "$SP_SNIPPETS_EN" "download-docker-enterprise.html" 's/docker-enterprise/docker/'
and copySnippet "$SP_SNIPPETS_EN" "download-k8s-enterprise.html" 's/k8s-enterprise/k8s/'
and if test "$ARANGODB_VERSION_MAJOR" -eq 3
      if test "$ARANGODB_VERSION_MINOR" -ge 12; or begin; test "$ARANGODB_VERSION_MINOR" -eq 11; and test "$ARANGODB_VERSION_PATCH" -ge 10; end
        copySnippet "$SP_SNIPPETS_EN" "download-objectfiles-enterprise*.html" 's/objectfiles-enterprise/objectfiles/'
      end
    end
and cp $WS_SNIPPETS/meta-*-enterprise*.json $SP_SNIPPETS_EN

if test "$ARANGODB_VERSION_MAJOR" -eq 3
  set -l snippets_filter 'meta-*json'
  and if test "$ARANGODB_VERSION_MINOR" -le 11; or begin; test "$ARANGODB_VERSION_MINOR" -eq 12; and test "$ARANGODB_VERSION_PATCH" -lt 5; end
        echo "========== CREATE META-DATA COMMUNITY =========="
      else
        echo "========== CREATE META-DATA COMMUNITY (SOURCE SNIPPET ONLY!) =========="
        set snippets_filter 'meta-source.json'
      end
  and begin
        echo "{"
        for file in (ls -1 $SP_SNIPPETS_CO/$snippets_filter | sort)
          set key (echo $file | sed -e 's:.*/meta-\(.*\).json:\1:')
          echo \"$key\":
          cat $file
          echo ","
        end
        echo \"serial\": \"(date +%s)\" "}"
      end | jq . > $SP_SNIPPETS_CO/meta.json
end

and echo "========== CREATE META-DATA ENTERPRISE =========="
and begin
      echo "{"
      for file in (ls -1 $SP_SNIPPETS_EN/meta-*json | sort)
        set key (echo $file | sed -e 's:.*/meta-\(.*\).json:\1:')
        echo \"$key\":
        cat $file
        echo ","
      end
      echo \"serial\": \"(date +%s)\" "}"
    end | jq . > $SP_SNIPPETS_EN/meta.json

set -l s $status
cd "$HOME/$NODE_NAME/$OSKAR" ; unlockDirectory
exit $s
