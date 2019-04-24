#!/usr/bin/env fish
pushd $INNERWORKDIR/ArangoDB
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
