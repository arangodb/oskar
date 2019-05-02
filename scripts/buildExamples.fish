#!/usr/bin/env fish
pushd $INNERWORKDIR/ArangoDB
and if test ! -d docs
  git clone ssh://git@github.com/arangodb/docs
end
and begin
  set -l CMAKELIST "CMakeLists.txt"
  set -l AV "set(ARANGODB_VERSION"
  set -l SEDFIX 's/.*"\([0-9a-zA-Z]*\)".*$/\1/'

  set -xg ARANGODB_VERSION (grep "$AV""_MAJOR" $CMAKELIST | sed -e $SEDFIX)"."(grep "$AV""_MINOR" $CMAKELIST | sed -e $SEDFIX)
end
and begin ; rm -rf "Documentation/Books/AQL/*" ; cp docs/$ARANGODB_VERSION/aql/*.md Documentation/Books/AQL/ ; end
and begin ; rm -rf "Documentation/Books/Manual/*" ; cp docs/$ARANGODB_VERSION/*.md Documentation/Books/Manual/ ; end
and begin ; rm -rf "Documentation/Books/HTTP/*" ; cp docs/$ARANGODB_VERSION/http/*.md Documentation/Books/HTTP/ ; end
and begin ; rm -rf "Documentation/Books/Cookbook/*" ; cp docs/$ARANGODB_VERSION/cookbook/*.md Documentation/Books/Cookbook/ ; end
and begin ; rm -rf "Documentation/Books/Drivers/*" ; cp docs/$ARANGODB_VERSION/drivers/*.md Documentation/Books/Drivers/ ; end
and rm -rf js/apps/system/_admin/aardvark/APP/api-docs.json
and rm -rf Documentation/Examples
and mkdir Documentation/Examples
and echo "Generating examples"
and bash -c ./utils/generateExamples.sh
and echo "Generating swagger"
and bash -c ./utils/generateSwagger.sh
and bash -c "cd Documentation/Scripts && python ./codeBlockReader.py"
and rm -rf ../Documentation
and mkdir ../Documentation
and cp -a Documentation/Examples js/apps/system/_admin/aardvark/APP/api-docs.json Documentation/Scripts/allComments.txt ../Documentation
and for i in ../Documentation/Examples/arango*.json; mv $i ../Documentation/(basename $i .json)-options.json; end
or begin echo "FAILED!"; popd; exit 1; end
popd
