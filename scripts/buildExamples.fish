#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@$ARANGODB_GIT_HOST

set -xg GCOV_PREFIX /work/gcov
set -xg GCOV_PREFIX_STRIP 3

pushd $INNERWORKDIR/ArangoDB
and if test -d docs
  rm -rf docs
end
and if test -n "$ARANGODB_DOCS_BRANCH"
  git clone --progress -b $ARANGODB_DOCS_BRANCH --single-branch ssh://git@$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/docs
else
  git clone --progress ssh://git@$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/docs
end
and begin
  set -l CMAKELIST "CMakeLists.txt"
  set -l AV "set(ARANGODB_VERSION"
  set -l SEDFIX 's/.*"\([0-9a-zA-Z]*\)".*$/\1/'

  set -xg ARANGODB_VERSION (grep "$AV""_MAJOR" $CMAKELIST | sed -e $SEDFIX)"."(grep "$AV""_MINOR" $CMAKELIST | sed -e $SEDFIX)
end
and begin ; set l Documentation/Books/AQL/*; rm -rf $l ; cp docs/$ARANGODB_VERSION/aql/*.md Documentation/Books/AQL/ ; end
and begin ; set l Documentation/Books/Manual/*; rm -rf $l ; cp docs/$ARANGODB_VERSION/*.md Documentation/Books/Manual/ ; end
and begin ; set l Documentation/Books/HTTP/*; rm -rf $l ; cp docs/$ARANGODB_VERSION/http/*.md Documentation/Books/HTTP/ ; end
and begin
  set l Documentation/Books/Cookbook/
  if test -d $l
    set r $l/*; rm -rf $r ; cp docs/$ARANGODB_VERSION/cookbook/*.md $l
  else
    echo "No Cookbook book present!"
  end
end
and begin
  set l Documentation/Books/Drivers
  if test -d $l
    set r $l/*; rm -rf $r ; cp docs/$ARANGODB_VERSION/drivers/*.md $l
  else
    echo "No Drivers book present!"
  end
end
and rm -rf Documentation/Examples
and mkdir Documentation/Examples
and echo "Generating examples"
and bash -c ./utils/generateExamples.sh
and echo "Generating swagger"
and rm -rf js/apps/system/_admin/aardvark/APP/api-docs.json
and bash -c ./utils/generateSwagger.sh
and bash -c "cd Documentation/Scripts && python ./codeBlockReader.py"
and begin
  if test -f ./utils/generateAllMetricsDocumentation.py
    echo "Generating metrics"
    and bash -c "./utils/generateAllMetricsDocumentation.py"
    or begin
      echo "Error during validation of input YAML files for metrics!"
      exit 1
    end
    and rm -f ./Documentation/Metrics/allMetrics.yaml
    and bash -c "./utils/generateAllMetricsDocumentation.py -d"
  end
end
and rm -rf ../Documentation
and mkdir ../Documentation
and cp -a Documentation/Examples js/apps/system/_admin/aardvark/APP/api-docs.json Documentation/Scripts/allComments.txt ../Documentation
and begin
  if test -f ./Documentation/Metrics/allMetrics.yaml
    cp ./Documentation/Metrics/allMetrics.yaml ../Documentation
  end
end
and for i in ../Documentation/Examples/arango*.json; mv $i ../Documentation/(basename $i .json)-options.json; end
and begin
  if test -f Documentation/optimizer-rules.json
    cp -a Documentation/optimizer-rules.json ../Documentation/optimizer-rules.json
  end
end
or begin echo "FAILED!"; popd; exit 1; end
popd
